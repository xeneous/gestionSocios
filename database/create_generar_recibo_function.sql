-- ============================================================================
-- FUNCIÓN PARA GENERAR RECIBO DE COBRANZA (TRANSACCIONAL)
-- ============================================================================
-- Esta función maneja todo el proceso de generación de recibo de forma atómica:
-- 1. Obtiene el siguiente número de recibo
-- 2. Crea los registros en valores_tesoreria
-- 3. Actualiza el campo cancelado en cuentas_corrientes
-- 4. Crea el registro COB en cuentas_corrientes
-- El asiento de diario se genera desde Dart usando AsientosService
-- Todo en una única transacción (commit o rollback)
-- ============================================================================

-- Eliminar función anterior si existe
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

  -- Retornar el número de recibo y los IDs de valores creados
  RETURN QUERY SELECT v_numero_recibo, v_ids_valores;
END;
$$;

-- Comentario
COMMENT ON FUNCTION public.generar_recibo_cobranza IS 'Genera un recibo de cobranza de forma transaccional. Crea valores de tesorería, actualiza cancelado y crea registro COB en cuentas corrientes. El asiento contable se genera desde la aplicación. Todo o nada (commit/rollback automático).';

-- Ejemplo de uso:
-- SELECT * FROM public.generar_recibo_cobranza(
--   123, -- socio_id
--   '[{"id_transaccion": 1, "monto": 100.50}, {"id_transaccion": 2, "monto": 50.25}]'::jsonb,
--   '[{"id_concepto": 1, "monto": 150.75}]'::jsonb,
--   1 -- operador_id
-- );
