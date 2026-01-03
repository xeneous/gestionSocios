-- ============================================================================
-- FUNCIÓN COMPLETA PARA GENERAR RECIBO DE COBRANZA CON CONTABILIDAD
-- ============================================================================
-- Esta función maneja todo el proceso de generación de recibo de forma atómica:
-- 1. Obtiene el siguiente número de recibo y asiento
-- 2. Crea los registros en valores_tesoreria
-- 3. Actualiza el campo cancelado en cuentas_corrientes
-- 4. Crea el registro COB en cuentas_corrientes
-- 5. Genera el asiento de diario (DEBE y HABER)
-- 6. Valida que los totales balanceen
-- Todo en una única transacción (commit o rollback)
-- ============================================================================

-- Eliminar la función anterior si existe (necesario porque cambió el tipo de retorno)
DROP FUNCTION IF EXISTS public.generar_recibo_cobranza(INTEGER, JSONB, JSONB, INTEGER);

CREATE OR REPLACE FUNCTION public.generar_recibo_cobranza(
  p_socio_id INTEGER,
  p_transacciones_a_pagar JSONB, -- [{"id_transaccion": 123, "monto": 100.50}, ...]
  p_formas_pago JSONB,            -- [{"id_concepto": 1, "monto": 100.50}, ...]
  p_operador_id INTEGER DEFAULT NULL
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

  -- 1. Obtener siguiente número de recibo y asiento
  SELECT public.get_next_numero('RECIBO') INTO v_numero_recibo;
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

  -- 5. Generar asiento de diario

  -- 5.1. Crear header del asiento
  INSERT INTO public.asientos_header (
    asiento,
    anio_mes,
    tipo_asiento,
    fecha,
    detalle
  ) VALUES (
    v_numero_asiento,
    v_anio_mes,
    1, -- tipo_asiento = 1
    NOW()::DATE,
    'Cobranza Recibo Nro. ' || v_numero_recibo
  );

  -- 5.2. Crear items del asiento - DEBE (desde formas de pago)
  FOR v_forma_pago IN SELECT * FROM jsonb_array_elements(p_formas_pago)
  LOOP
    -- Obtener la cuenta contable desde conceptos_tesoreria
    SELECT
      ct.imputacion_contable
    INTO v_imputacion_contable
    FROM public.conceptos_tesoreria ct
    WHERE ct.id = (v_forma_pago->>'id_concepto')::INTEGER;

    IF v_imputacion_contable IS NULL THEN
      RAISE EXCEPTION 'Concepto de tesorería % no tiene imputación contable configurada',
        (v_forma_pago->>'id_concepto')::INTEGER;
    END IF;

    -- Buscar la cuenta en la tabla cuentas usando el número de cuenta
    SELECT id INTO v_forma_pago_cuenta_id
    FROM public.cuentas
    WHERE cuenta::VARCHAR = v_imputacion_contable;

    IF v_forma_pago_cuenta_id IS NULL THEN
      RAISE EXCEPTION 'No se encontró cuenta contable % para concepto de tesorería %',
        v_imputacion_contable, (v_forma_pago->>'id_concepto')::INTEGER;
    END IF;

    -- Crear item DEBE
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
      v_anio_mes,
      1,
      v_item_asiento,
      v_forma_pago_cuenta_id,
      (v_forma_pago->>'monto')::NUMERIC,
      0,
      'Recibo Nro. ' || v_numero_recibo
    );

    v_total_debe := v_total_debe + (v_forma_pago->>'monto')::NUMERIC;
    v_item_asiento := v_item_asiento + 1;
  END LOOP;

  -- 5.3. Crear items del asiento - HABER (desde transacciones pagadas)
  -- Para cada transacción pagada, necesitamos obtener sus detalles y crear items proporcionales
  FOR v_transaccion IN SELECT * FROM jsonb_array_elements(p_transacciones_a_pagar)
  LOOP
    -- Obtener cada detalle de la transacción
    FOR v_detalle_transaccion IN
      SELECT
        dcc.concepto,
        dcc.importe,
        c.cuenta_contable_id
      FROM public.detalle_cuentas_corrientes dcc
      JOIN public.conceptos c ON dcc.concepto = c.concepto
      WHERE dcc.idtransaccion = (v_transaccion->>'id_transaccion')::BIGINT
    LOOP
      DECLARE
        v_importe_total_transaccion NUMERIC;
        v_monto_proporcional NUMERIC;
      BEGIN
        IF v_detalle_transaccion.cuenta_contable_id IS NULL THEN
          RAISE EXCEPTION 'Concepto % no tiene cuenta contable configurada',
            v_detalle_transaccion.concepto;
        END IF;

        -- Obtener importe total de la transacción
        SELECT importe INTO v_importe_total_transaccion
        FROM public.cuentas_corrientes
        WHERE idtransaccion = (v_transaccion->>'id_transaccion')::BIGINT;

        -- Calcular monto proporcional
        IF v_importe_total_transaccion > 0 THEN
          v_monto_proporcional := ((v_transaccion->>'monto')::NUMERIC / v_importe_total_transaccion)
                                  * v_detalle_transaccion.importe;
        ELSE
          v_monto_proporcional := 0;
        END IF;

        -- Crear item HABER
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
          v_anio_mes,
          1,
          v_item_asiento,
          v_detalle_transaccion.cuenta_contable_id,
          0,
          v_monto_proporcional,
          'Recibo Nro. ' || v_numero_recibo || ' - Trans. ' || (v_transaccion->>'id_transaccion')
        );

        v_total_haber := v_total_haber + v_monto_proporcional;
        v_item_asiento := v_item_asiento + 1;
      END;
    END LOOP;
  END LOOP;

  -- 6. Validar que el asiento esté balanceado (DEBE = HABER)
  IF ABS(v_total_debe - v_total_haber) > 0.01 THEN
    RAISE EXCEPTION 'El asiento no está balanceado: DEBE: %, HABER: %',
      v_total_debe, v_total_haber;
  END IF;

  -- Retornar el número de recibo, asiento y los IDs de valores creados
  RETURN QUERY SELECT v_numero_recibo, v_numero_asiento, v_ids_valores;
END;
$$;

-- Comentario
COMMENT ON FUNCTION public.generar_recibo_cobranza IS 'Genera un recibo de cobranza completo con contabilidad de forma transaccional. Crea valores de tesorería, actualiza cancelado en cuentas corrientes, crea registro COB y genera asiento de diario balanceado. Todo o nada (commit/rollback automático).';

-- ============================================================================
-- NOTA: Requiere que existan los numeradores RECIBO y ASIENTO
-- ============================================================================

-- Insertar numerador para ASIENTO si no existe
INSERT INTO public.numeradores (tipo, ultimo_numero)
VALUES ('ASIENTO', 0)
ON CONFLICT (tipo) DO NOTHING;

-- Ejemplo de uso:
-- SELECT * FROM public.generar_recibo_cobranza(
--   123, -- socio_id
--   '[{"id_transaccion": 1, "monto": 100.50}, {"id_transaccion": 2, "monto": 50.25}]'::jsonb,
--   '[{"id_concepto": 1, "monto": 150.75}]'::jsonb,
--   1 -- operador_id
-- );
