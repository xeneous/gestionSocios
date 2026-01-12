-- ============================================================================
-- FUNCIÓN PARA REGISTRAR DÉBITO AUTOMÁTICO PRESENTADO
-- ============================================================================
-- Esta función registra contablemente la presentación de débitos automáticos
-- a las tarjetas (Visa/Mastercard/etc).
--
-- Por cada socio en la presentación:
-- 1. Crea un comprobante 'DA' (Débito Automático) en cuentas_corrientes
-- 2. Actualiza el campo 'cancelado' en los CS (Cuota Servicio) que originaron el débito
-- 3. Registra la trazabilidad en operaciones_contables y sus detalles
--
-- Parámetros:
-- - p_presentacion_data: Array con los datos de cada socio
--   Formato: [
--     {
--       "socio_id": 1,
--       "entidad_id": 0,
--       "importe_total": 32500,
--       "transacciones": [
--         {"idtransaccion": 123, "monto": 20000},
--         {"idtransaccion": 124, "monto": 12500}
--       ]
--     },
--     ...
--   ]
-- - p_anio_mes: Período de presentación (ej: 202512 para diciembre 2025)
-- - p_fecha_presentacion: Fecha de la presentación
-- - p_nombre_tarjeta: Nombre de la tarjeta (ej: 'Visa', 'Mastercard')
-- - p_operador_id: ID del operador (opcional)
--
-- Retorna: JSON con {operacion_id, numero_asiento}
-- ============================================================================

CREATE OR REPLACE FUNCTION public.registrar_debito_automatico(
  p_presentacion_data JSONB,
  p_anio_mes INTEGER,
  p_fecha_presentacion DATE,
  p_nombre_tarjeta VARCHAR,
  p_operador_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
  operacion_id BIGINT,
  numero_asiento INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_socio_data JSONB;
  v_transaccion JSONB;
  v_socio_id INTEGER;
  v_entidad_id INTEGER;
  v_importe_total NUMERIC;
  v_transacciones JSONB;
  v_idtransaccion BIGINT;
  v_monto NUMERIC;
  v_transaccion_actual RECORD;
  v_nuevo_cancelado NUMERIC;
  v_operacion_id BIGINT;
  v_idtransaccion_da BIGINT;
  v_total_presentacion NUMERIC := 0;
  v_numero_asiento INTEGER;
  v_anio_mes_asiento INTEGER;
  v_cuenta_banco_id INTEGER;
  v_cuenta_deudores_id INTEGER;
BEGIN
  -- Validar que haya datos
  IF jsonb_array_length(p_presentacion_data) = 0 THEN
    RAISE EXCEPTION 'No hay datos de presentación';
  END IF;

  -- Validar año/mes
  IF p_anio_mes < 202401 OR p_anio_mes > 209912 THEN
    RAISE EXCEPTION 'Año/mes inválido: %', p_anio_mes;
  END IF;

  -- Calcular total de la presentación
  FOR v_socio_data IN SELECT * FROM jsonb_array_elements(p_presentacion_data)
  LOOP
    v_total_presentacion := v_total_presentacion + (v_socio_data->>'importe_total')::NUMERIC;
  END LOOP;

  -- Crear registro maestro en operaciones_contables (UNO para toda la presentación)
  INSERT INTO public.operaciones_contables (
    tipo_operacion,
    numero_comprobante,
    fecha,
    entidad_tipo,
    entidad_id,
    total,
    observaciones,
    operador_id
  ) VALUES (
    'DEBITO_AUTOMATICO',
    p_anio_mes,  -- Usamos el año/mes como número de comprobante
    p_fecha_presentacion,
    'MULTIPLE',  -- Múltiples socios
    NULL,        -- No es un solo socio
    v_total_presentacion,
    'Presentación DA período ' || p_anio_mes::TEXT,
    p_operador_id
  )
  RETURNING id INTO v_operacion_id;

  -- Procesar cada socio de la presentación
  FOR v_socio_data IN SELECT * FROM jsonb_array_elements(p_presentacion_data)
  LOOP
    v_socio_id := (v_socio_data->>'socio_id')::INTEGER;
    v_entidad_id := (v_socio_data->>'entidad_id')::INTEGER;
    v_importe_total := (v_socio_data->>'importe_total')::NUMERIC;
    v_transacciones := v_socio_data->'transacciones';

    -- 1. Crear comprobante 'DA' en cuentas_corrientes
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
      v_socio_id,
      v_entidad_id,
      p_fecha_presentacion,
      'DA',
      p_anio_mes::VARCHAR,
      v_importe_total,
      v_importe_total,  -- Se considera cancelado (el DA cancela los CS)
      p_fecha_presentacion
    )
    RETURNING idtransaccion INTO v_idtransaccion_da;

    -- 2. Actualizar campo cancelado en los CS que dieron origen al débito
    FOR v_transaccion IN SELECT * FROM jsonb_array_elements(v_transacciones)
    LOOP
      v_idtransaccion := (v_transaccion->>'idtransaccion')::BIGINT;
      v_monto := (v_transaccion->>'monto')::NUMERIC;

      -- Obtener el registro actual
      SELECT cancelado INTO v_transaccion_actual
      FROM public.cuentas_corrientes
      WHERE idtransaccion = v_idtransaccion;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Transacción % no encontrada', v_idtransaccion;
      END IF;

      -- Calcular nuevo cancelado
      v_nuevo_cancelado := COALESCE(v_transaccion_actual.cancelado, 0) + v_monto;

      -- Actualizar
      UPDATE public.cuentas_corrientes
      SET cancelado = v_nuevo_cancelado,
          updated_at = NOW()
      WHERE idtransaccion = v_idtransaccion;

      -- 3. Insertar detalle en operaciones_detalle_cuentas_corrientes
      --    Vinculando qué CS fueron cancelados por este DA
      INSERT INTO public.operaciones_detalle_cuentas_corrientes (
        operacion_id,
        idtransaccion,
        monto
      ) VALUES (
        v_operacion_id,
        v_idtransaccion,
        v_monto
      );
    END LOOP;

  END LOOP;

  -- ========================================================================
  -- 4. GENERAR ASIENTO CONTABLE TIPO 6 (Resumen Débito Automático)
  -- ========================================================================

  -- Obtener siguiente número de asiento
  SELECT public.get_next_numero('ASIENTO') INTO v_numero_asiento;

  -- Calcular período para el asiento (YYYYMM)
  v_anio_mes_asiento := EXTRACT(YEAR FROM p_fecha_presentacion)::INTEGER * 100 +
                        EXTRACT(MONTH FROM p_fecha_presentacion)::INTEGER;

  -- Obtener IDs de las cuentas contables
  -- Cuenta Banco Galicia Cta Cte (DEBE)
  SELECT id INTO v_cuenta_banco_id
  FROM public.cuentas
  WHERE cuenta = 1103020101;

  IF v_cuenta_banco_id IS NULL THEN
    RAISE EXCEPTION 'No se encontró la cuenta 1103020101 (Banco Galicia)';
  END IF;

  -- Cuenta Deudores por Venta (HABER)
  SELECT id INTO v_cuenta_deudores_id
  FROM public.cuentas
  WHERE cuenta = 1101010101;

  IF v_cuenta_deudores_id IS NULL THEN
    RAISE EXCEPTION 'No se encontró la cuenta 1101010101 (Deudores por Venta)';
  END IF;

  -- Crear header del asiento
  INSERT INTO public.asientos_header (
    asiento,
    anio_mes,
    tipo_asiento,
    fecha,
    detalle
  ) VALUES (
    v_numero_asiento,
    v_anio_mes_asiento,
    6, -- Tipo 6: Asientos Resumen Débito Automático
    p_fecha_presentacion,
    'Presentación débito automático ' || p_nombre_tarjeta || ' - período ' || p_anio_mes::TEXT
  );

  -- Crear item 1: DEBE - Banco Galicia
  INSERT INTO public.asientos_items (
    asiento,
    anio_mes,
    tipo_asiento,
    item,
    cuenta_id,
    debe,
    haber,
    observacion
  ) VALUES (
    v_numero_asiento,
    v_anio_mes_asiento,
    6,
    1,
    v_cuenta_banco_id,
    v_total_presentacion,
    0,
    'Débito automático ' || p_nombre_tarjeta || ' - ' || p_anio_mes::TEXT
  );

  -- Crear item 2: HABER - Deudores por Venta
  INSERT INTO public.asientos_items (
    asiento,
    anio_mes,
    tipo_asiento,
    item,
    cuenta_id,
    debe,
    haber,
    observacion
  ) VALUES (
    v_numero_asiento,
    v_anio_mes_asiento,
    6,
    2,
    v_cuenta_deudores_id,
    0,
    v_total_presentacion,
    'Débito automático ' || p_nombre_tarjeta || ' - ' || p_anio_mes::TEXT
  );

  -- Actualizar la operación con el número de asiento generado
  UPDATE public.operaciones_contables
  SET asiento_numero = v_numero_asiento,
      asiento_anio_mes = v_anio_mes_asiento,
      asiento_tipo = 6
  WHERE id = v_operacion_id;

  -- Retornar el ID de la operación y el número de asiento
  RETURN QUERY SELECT v_operacion_id, v_numero_asiento;
END;
$$;

-- Comentario
COMMENT ON FUNCTION public.registrar_debito_automatico IS
'Registra contablemente una presentación de débitos automáticos. Crea comprobantes DA, actualiza cancelado en CS, y registra trazabilidad completa. Todo en una transacción (commit/rollback automático).';

-- ============================================================================
-- EJEMPLO DE USO:
-- ============================================================================
-- SELECT public.registrar_debito_automatico(
--   '[
--     {
--       "socio_id": 1,
--       "entidad_id": 0,
--       "importe_total": 32500,
--       "transacciones": [
--         {"idtransaccion": 123, "monto": 20000},
--         {"idtransaccion": 124, "monto": 12500}
--       ]
--     },
--     {
--       "socio_id": 2,
--       "entidad_id": 0,
--       "importe_total": 15000,
--       "transacciones": [
--         {"idtransaccion": 125, "monto": 15000}
--       ]
--     }
--   ]'::jsonb,
--   202512,           -- Año/mes
--   '2025-12-01',     -- Fecha presentación
--   1                 -- Operador ID
-- );
