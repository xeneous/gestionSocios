-- ============================================================================
-- FIX: generar_recibo_cobranza
--   1. Corrige columna id_socio → socio_id
--   2. Agrega soporte de profesionales (p_profesional_id + entidad_id = 1)
--   3. Mantiene soporte de p_numero_recibo opcional
--   4. Restaura inserción en operaciones_contables (necesaria para PDF)
-- ============================================================================

DROP FUNCTION IF EXISTS public.generar_recibo_cobranza(INTEGER, JSONB, JSONB, INTEGER);
DROP FUNCTION IF EXISTS public.generar_recibo_cobranza(INTEGER, JSONB, JSONB, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION public.generar_recibo_cobranza(
  p_socio_id              INTEGER DEFAULT NULL,
  p_transacciones_a_pagar JSONB   DEFAULT '[]',
  p_formas_pago           JSONB   DEFAULT '[]',
  p_operador_id           INTEGER DEFAULT NULL,
  p_numero_recibo         INTEGER DEFAULT NULL,
  p_profesional_id        INTEGER DEFAULT NULL
)
RETURNS TABLE (
  numero_recibo       INTEGER,
  numero_asiento      INTEGER,
  ids_valores_creados INTEGER[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_numero_recibo    INTEGER;
  v_numero_asiento   INTEGER := 0;
  v_ultimo_numero    INTEGER;
  v_total_a_pagar    NUMERIC := 0;
  v_total_fp         NUMERIC := 0;
  v_transaccion      JSONB;
  v_forma_pago       JSONB;
  v_cancelado_actual NUMERIC;
  v_nuevo_cancelado  NUMERIC;
  v_ids_valores      INTEGER[] := ARRAY[]::INTEGER[];
  v_nuevo_id_valor   INTEGER;
  v_entidad_id       INTEGER;
  v_operacion_id     BIGINT;
BEGIN
  -- Determinar entidad_id (0 = socio, 1 = profesional)
  IF p_profesional_id IS NOT NULL THEN
    v_entidad_id := 1;
  ELSE
    v_entidad_id := 0;
    IF p_socio_id IS NULL THEN
      RAISE EXCEPTION 'Debe proveer p_socio_id o p_profesional_id';
    END IF;
  END IF;

  -- Validaciones básicas
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
    v_total_fp := v_total_fp + (v_forma_pago->>'monto')::NUMERIC;
  END LOOP;

  IF ABS(v_total_a_pagar - v_total_fp) > 0.01 THEN
    RAISE EXCEPTION 'Los totales no coinciden: A pagar: %, Formas de pago: %',
      v_total_a_pagar, v_total_fp;
  END IF;

  -- 1. Determinar número de recibo
  IF p_numero_recibo IS NOT NULL THEN
    v_numero_recibo := p_numero_recibo;
    SELECT ultimo_numero INTO v_ultimo_numero
    FROM public.numeradores WHERE tipo = 'RECIBO';
    IF v_numero_recibo > v_ultimo_numero THEN
      UPDATE public.numeradores
      SET ultimo_numero = v_numero_recibo, updated_at = NOW()
      WHERE tipo = 'RECIBO';
    END IF;
  ELSE
    SELECT public.get_next_numero('RECIBO') INTO v_numero_recibo;
  END IF;

  -- 2. Crear registros en valores_tesoreria
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
      1,
      (v_forma_pago->>'id_concepto')::INTEGER,
      NOW(),
      v_numero_recibo,
      (v_forma_pago->>'monto')::NUMERIC,
      (v_forma_pago->>'monto')::NUMERIC,
      p_operador_id,
      false,
      'Recibo Nro. ' || v_numero_recibo
    )
    RETURNING id INTO v_nuevo_id_valor;

    v_ids_valores := array_append(v_ids_valores, v_nuevo_id_valor);
  END LOOP;

  -- 3. Actualizar campo cancelado en cuentas_corrientes
  FOR v_transaccion IN SELECT * FROM jsonb_array_elements(p_transacciones_a_pagar)
  LOOP
    SELECT cancelado INTO v_cancelado_actual
    FROM public.cuentas_corrientes
    WHERE idtransaccion = (v_transaccion->>'id_transaccion')::BIGINT;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Transacción % no encontrada', (v_transaccion->>'id_transaccion');
    END IF;

    v_nuevo_cancelado := COALESCE(v_cancelado_actual, 0) + (v_transaccion->>'monto')::NUMERIC;

    UPDATE public.cuentas_corrientes
    SET cancelado = v_nuevo_cancelado,
        updated_at = NOW()
    WHERE idtransaccion = (v_transaccion->>'id_transaccion')::BIGINT;
  END LOOP;

  -- 4. Crear registro COB en cuentas_corrientes (columnas correctas)
  INSERT INTO public.cuentas_corrientes (
    socio_id,
    profesional_id,
    entidad_id,
    tipo_comprobante,
    documento_numero,
    fecha,
    vencimiento,
    importe,
    cancelado
  ) VALUES (
    p_socio_id,
    p_profesional_id,
    v_entidad_id,
    'COB',
    v_numero_recibo::VARCHAR,
    NOW()::DATE,
    NOW()::DATE,
    v_total_fp,
    v_total_fp
  );

  -- 5. Crear registro en operaciones_contables (necesario para PDF del recibo)
  INSERT INTO public.operaciones_contables (
    tipo_operacion,
    numero_comprobante,
    fecha,
    entidad_tipo,
    entidad_id,
    total,
    operador_id
  ) VALUES (
    CASE WHEN p_profesional_id IS NOT NULL THEN 'COBRANZA_PROFESIONAL' ELSE 'COBRANZA_SOCIO' END,
    v_numero_recibo,
    NOW()::DATE,
    CASE WHEN p_profesional_id IS NOT NULL THEN 'PROFESIONAL' ELSE 'SOCIO' END,
    COALESCE(p_profesional_id, p_socio_id),
    v_total_fp,
    p_operador_id
  )
  RETURNING id INTO v_operacion_id;

  -- 6. Detalle de transacciones canceladas
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

  -- 7. Detalle de valores de tesorería
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

  RETURN QUERY SELECT v_numero_recibo, v_numero_asiento, v_ids_valores;
END;
$$;

COMMENT ON FUNCTION public.generar_recibo_cobranza IS
'Genera recibo de cobranza para socios (p_socio_id) o profesionales (p_profesional_id). Crea valores_tesoreria, actualiza cancelado, registra COB y trazabilidad completa. Soporta número de recibo manual (p_numero_recibo).';
