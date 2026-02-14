-- ============================================================================
-- Función para ver el próximo número sin consumirlo (peek)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.peek_next_numero(p_tipo VARCHAR)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_numero INTEGER;
BEGIN
  SELECT ultimo_numero + 1 INTO v_numero
  FROM public.numeradores
  WHERE tipo = p_tipo;

  RETURN v_numero;
END;
$$;

COMMENT ON FUNCTION public.peek_next_numero IS 'Devuelve el próximo número sin incrementar el contador';

-- ============================================================================
-- Actualizar generar_recibo_cobranza para aceptar número de recibo opcional
-- Si se provee, usa ese número. Si no, auto-genera.
-- Solo avanza la secuencia si el número usado es >= al próximo auto-generado.
-- ============================================================================
DROP FUNCTION IF EXISTS public.generar_recibo_cobranza(INTEGER, JSONB, JSONB, INTEGER);
DROP FUNCTION IF EXISTS public.generar_recibo_cobranza(INTEGER, JSONB, JSONB, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION public.generar_recibo_cobranza(
  p_socio_id INTEGER,
  p_transacciones_a_pagar JSONB,
  p_formas_pago JSONB,
  p_operador_id INTEGER DEFAULT NULL,
  p_numero_recibo INTEGER DEFAULT NULL  -- Nuevo: número de recibo opcional
)
RETURNS TABLE (
  numero_recibo INTEGER,
  numero_asiento INTEGER,
  ids_valores_creados INTEGER[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_numero_recibo INTEGER;
  v_numero_asiento INTEGER;
  v_anio_mes INTEGER;
  v_total_a_pagar NUMERIC := 0;
  v_total_formas_pago NUMERIC := 0;
  v_transaccion JSONB;
  v_forma_pago JSONB;
  v_transaccion_actual RECORD;
  v_nuevo_cancelado NUMERIC;
  v_ids_valores INTEGER[] := ARRAY[]::INTEGER[];
  v_nuevo_id_valor INTEGER;
  v_total_debe NUMERIC := 0;
  v_total_haber NUMERIC := 0;
  v_item_asiento INTEGER := 1;
  v_concepto_cuenta_id INTEGER;
  v_forma_pago_cuenta_id INTEGER;
  v_detalle_transaccion RECORD;
  v_imputacion_contable VARCHAR(50);
  v_ultimo_numero INTEGER;
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

  -- Validar que los totales coincidan
  IF ABS(v_total_a_pagar - v_total_formas_pago) > 0.01 THEN
    RAISE EXCEPTION 'Los totales no coinciden: A pagar: %, Formas de pago: %',
      v_total_a_pagar, v_total_formas_pago;
  END IF;

  -- 1. Determinar número de recibo
  IF p_numero_recibo IS NOT NULL THEN
    -- Usar el número provisto por el usuario
    v_numero_recibo := p_numero_recibo;

    -- Solo avanzar la secuencia si el número usado es >= al próximo
    SELECT ultimo_numero INTO v_ultimo_numero
    FROM public.numeradores WHERE tipo = 'RECIBO';

    IF v_numero_recibo > v_ultimo_numero THEN
      UPDATE public.numeradores
      SET ultimo_numero = v_numero_recibo, updated_at = NOW()
      WHERE tipo = 'RECIBO';
    END IF;
  ELSE
    -- Auto-generar
    SELECT public.get_next_numero('RECIBO') INTO v_numero_recibo;
  END IF;

  SELECT public.get_next_numero('ASIENTO') INTO v_numero_asiento;

  -- Calcular período (YYYYMM)
  v_anio_mes := EXTRACT(YEAR FROM NOW())::INTEGER * 100 + EXTRACT(MONTH FROM NOW())::INTEGER;

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
    SELECT cancelado INTO v_transaccion_actual
    FROM public.cuentas_corrientes
    WHERE idtransaccion = (v_transaccion->>'id_transaccion')::BIGINT;

    v_nuevo_cancelado := COALESCE(v_transaccion_actual.cancelado, 0) + (v_transaccion->>'monto')::NUMERIC;

    UPDATE public.cuentas_corrientes
    SET cancelado = v_nuevo_cancelado
    WHERE idtransaccion = (v_transaccion->>'id_transaccion')::BIGINT;
  END LOOP;

  -- 4. Crear registro COB en cuentas_corrientes
  INSERT INTO public.cuentas_corrientes (
    id_socio,
    tipo_comprobante,
    documento_numero,
    fecha,
    vencimiento,
    importe,
    cancelado,
    anio_mes,
    tipo_movimiento,
    id_operador,
    numero_recibo
  ) VALUES (
    p_socio_id,
    'COB',
    v_numero_recibo::VARCHAR,
    NOW(),
    NOW(),
    -v_total_a_pagar,
    -v_total_a_pagar,
    v_anio_mes,
    2,
    p_operador_id,
    v_numero_recibo
  );

  -- Retornar resultado
  RETURN QUERY SELECT v_numero_recibo, v_numero_asiento, v_ids_valores;
END;
$$;
