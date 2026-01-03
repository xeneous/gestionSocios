-- ============================================================================
-- ACTUALIZACIÓN: Agregar trazabilidad a generar_recibo_cobranza
-- ============================================================================
-- Esta actualización EXTIENDE la función existente para que ADEMÁS de todo
-- lo que ya hace, también inserte en las tablas de trazabilidad.
-- NO rompe nada existente, solo AGREGA funcionalidad.
-- ============================================================================

-- Eliminar función anterior
DROP FUNCTION IF EXISTS public.generar_recibo_cobranza(INTEGER, JSONB, JSONB, INTEGER);

CREATE OR REPLACE FUNCTION public.generar_recibo_cobranza(
  p_socio_id INTEGER,
  p_transacciones_a_pagar JSONB, -- [{"id_transaccion": 123, "monto": 100.50}, ...]
  p_formas_pago JSONB,            -- [{"id_concepto": 1, "monto": 100.50}, ...]
  p_operador_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
  numero_recibo INTEGER,
  ids_valores_creados INTEGER[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_numero_recibo INTEGER;
  v_total_a_pagar NUMERIC := 0;
  v_total_formas_pago NUMERIC := 0;
  v_transaccion JSONB;
  v_forma_pago JSONB;
  v_transaccion_actual RECORD;
  v_nuevo_cancelado NUMERIC;
  v_ids_valores INTEGER[] := ARRAY[]::INTEGER[];
  v_nuevo_id_valor INTEGER;

  -- NUEVAS VARIABLES PARA TRAZABILIDAD
  v_operacion_id BIGINT;
BEGIN
  -- Validar que haya transacciones y formas de pago
  IF jsonb_array_length(p_transacciones_a_pagar) = 0 THEN
    RAISE EXCEPTION 'No hay transacciones para pagar';
  END IF;

  IF jsonb_array_length(p_formas_pago) = 0 THEN
    RAISE EXCEPTION 'No hay formas de pago seleccionadas';
  END IF;

  -- Calcular totales
  FOR v_transaccion IN SELECT * FROM jsonb_array_elements(p_transacciones_a_pagar)
  LOOP
    v_total_a_pagar := v_total_a_pagar + (v_transaccion->>'monto')::NUMERIC;
  END LOOP;

  FOR v_forma_pago IN SELECT * FROM jsonb_array_elements(p_formas_pago)
  LOOP
    v_total_formas_pago := v_total_formas_pago + (v_forma_pago->>'monto')::NUMERIC;
  END LOOP;

  -- Validar que los totales coincidan (con tolerancia de 0.01)
  IF ABS(v_total_a_pagar - v_total_formas_pago) > 0.01 THEN
    RAISE EXCEPTION 'Los totales no coinciden: A pagar: %, Formas de pago: %',
      v_total_a_pagar, v_total_formas_pago;
  END IF;

  -- 1. Obtener siguiente número de recibo
  SELECT public.get_next_numero('RECIBO') INTO v_numero_recibo;

  -- 2. Crear registros en valores_tesoreria para cada forma de pago
  FOR v_forma_pago IN SELECT * FROM jsonb_array_elements(p_formas_pago)
  LOOP
    INSERT INTO public.valores_tesoreria (
      tipo_movimiento,
      idconcepto_tesoreria,
      fecha_emision,
      numero_interno,
      importe,
      cancelado,
      idoperador,
      locked,
      observaciones
    ) VALUES (
      1, -- 1 = Ingreso/Cobro
      (v_forma_pago->>'id_concepto')::INTEGER,
      NOW(),
      v_numero_recibo,
      (v_forma_pago->>'monto')::NUMERIC,
      (v_forma_pago->>'monto')::NUMERIC, -- Se considera cancelado al crearlo
      p_operador_id,
      false,
      'Recibo Nro. ' || v_numero_recibo
    )
    RETURNING id INTO v_nuevo_id_valor;

    -- Agregar el ID a la lista de IDs creados
    v_ids_valores := array_append(v_ids_valores, v_nuevo_id_valor);
  END LOOP;

  -- 3. Actualizar campo cancelado en cuentas_corrientes
  FOR v_transaccion IN SELECT * FROM jsonb_array_elements(p_transacciones_a_pagar)
  LOOP
    -- Obtener el registro actual
    SELECT cancelado INTO v_transaccion_actual
    FROM public.cuentas_corrientes
    WHERE idtransaccion = (v_transaccion->>'id_transaccion')::BIGINT;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Transacción % no encontrada', (v_transaccion->>'id_transaccion')::INTEGER;
    END IF;

    -- Calcular nuevo cancelado
    v_nuevo_cancelado := COALESCE(v_transaccion_actual.cancelado, 0) + (v_transaccion->>'monto')::NUMERIC;

    -- Actualizar
    UPDATE public.cuentas_corrientes
    SET cancelado = v_nuevo_cancelado,
        updated_at = NOW()
    WHERE idtransaccion = (v_transaccion->>'id_transaccion')::BIGINT;
  END LOOP;

  -- 4. Crear registro COB en cuentas_corrientes
  INSERT INTO public.cuentas_corrientes (
    socio_id,
    entidad_id,
    fecha,
    tipo_comprobante,
    documento_numero,
    importe,
    cancelado,
    vencimiento
  ) VALUES (
    p_socio_id,
    0, -- 0 = Socios
    NOW()::DATE,
    'COB',
    v_numero_recibo::VARCHAR,
    v_total_formas_pago,
    v_total_formas_pago, -- El COB se considera cancelado al crearlo
    NOW()::DATE
  );

  -- ========================================================================
  -- NUEVO: TRAZABILIDAD - Insertar en tablas de trazabilidad
  -- ========================================================================

  -- 5. Crear registro maestro en operaciones_contables
  INSERT INTO public.operaciones_contables (
    tipo_operacion,
    numero_comprobante,
    fecha,
    entidad_tipo,
    entidad_id,
    total,
    asiento_numero,      -- NULL por ahora, se actualiza desde Dart
    asiento_anio_mes,    -- NULL por ahora, se actualiza desde Dart
    asiento_tipo,        -- NULL por ahora, se actualiza desde Dart
    operador_id
  ) VALUES (
    'COBRANZA_SOCIO',
    v_numero_recibo,
    NOW()::DATE,
    'SOCIO',
    p_socio_id,
    v_total_formas_pago,
    NULL,  -- Se actualiza después desde Dart cuando se crea el asiento
    NULL,
    NULL,
    p_operador_id
  )
  RETURNING id INTO v_operacion_id;

  -- 6. Insertar detalle de transacciones canceladas
  FOR v_transaccion IN SELECT * FROM jsonb_array_elements(p_transacciones_a_pagar)
  LOOP
    INSERT INTO public.operaciones_detalle_cuentas_corrientes (
      operacion_id,
      idtransaccion,
      monto
    ) VALUES (
      v_operacion_id,
      (v_transaccion->>'id_transaccion')::BIGINT,
      (v_transaccion->>'monto')::NUMERIC
    );
  END LOOP;

  -- 7. Insertar detalle de valores de tesorería
  FOREACH v_nuevo_id_valor IN ARRAY v_ids_valores
  LOOP
    INSERT INTO public.operaciones_detalle_valores_tesoreria (
      operacion_id,
      valor_tesoreria_id
    ) VALUES (
      v_operacion_id,
      v_nuevo_id_valor
    );
  END LOOP;

  -- Retornar el número de recibo y los IDs de valores creados
  RETURN QUERY SELECT v_numero_recibo, v_ids_valores;
END;
$$;

-- Comentario actualizado
COMMENT ON FUNCTION public.generar_recibo_cobranza IS
'Genera un recibo de cobranza de forma transaccional. Crea valores de tesorería, actualiza cancelado, crea registro COB y registra trazabilidad completa. El asiento contable se genera desde la aplicación. Todo o nada (commit/rollback automático).';
