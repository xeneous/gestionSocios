-- ============================================================================
-- REGISTRO ATÓMICO DE RECHAZOS DE DÉBITO AUTOMÁTICO (Visa / Mastercard)
-- ============================================================================
-- Requiere que existan:
--   database/create_operaciones_trazabilidad.sql (operaciones_contables,
--     operaciones_detalle_cuentas_corrientes)
--   database/create_registrar_debito_automatico.sql (genera los DA originales)
--   database/create_presentaciones_rechazos_tarjetas.sql (rechazos_tarjetas)
--
-- Contexto: cuando un socio tiene 2+ cuotas (CS) pendientes en el mismo
-- período, se combinan en un solo comprobante 'DA'. Cuando ese DA rebota,
-- la tarjeta (Visa/Mastercard) informa el rechazo desglosado por cada CS
-- original, no por el DA combinado. El módulo de rechazos (Flutter) matchea
-- cada línea del archivo contra su CS original vía
-- operaciones_detalle_cuentas_corrientes y llama a esta función UNA vez con
-- todas las líneas aprobadas, para que se registren todas juntas o ninguna.
--
-- Por cada línea del array:
--   1. Revierte el 'cancelado' de la CS original (vuelve a quedar pendiente
--      de cobro, puede volver a debitarse o cobrarse por otra vía).
--   2. Inserta el comprobante 'RDA' en cuentas_corrientes (la deuda real).
--   3. Copia el detalle de la CS original al nuevo RDA (o un detalle
--      genérico 'CS' si la CS no tenía detalle propio).
--   4. Inserta la auditoría en rechazos_tarjetas, con referencia a la CS
--      revertida y al RDA creado.
-- Todo dentro de la transacción implícita de la función: si cualquier línea
-- falla, no se comitea nada.
-- ============================================================================

-- Columnas de trazabilidad nuevas en rechazos_tarjetas (no existían)
ALTER TABLE public.rechazos_tarjetas
  ADD COLUMN IF NOT EXISTS idtransaccion_cs  BIGINT,
  ADD COLUMN IF NOT EXISTS idtransaccion_rda BIGINT;

COMMENT ON COLUMN public.rechazos_tarjetas.idtransaccion_cs IS
  'idtransaccion de la CS/CRP/CRB original que fue revertida por este rechazo';
COMMENT ON COLUMN public.rechazos_tarjetas.idtransaccion_rda IS
  'idtransaccion del comprobante RDA creado por este rechazo';

DROP FUNCTION IF EXISTS public.registrar_rechazo_debito_automatico;

CREATE OR REPLACE FUNCTION public.registrar_rechazo_debito_automatico(
  p_rechazos      JSONB,
  p_operador_id   INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rechazo           JSONB;
  v_tarjeta_id         INTEGER;
  v_periodo            INTEGER;
  v_socio_id           INTEGER;
  v_entidad_id         INTEGER;
  v_importe            NUMERIC;
  v_numero_tarjeta     VARCHAR;
  v_motivo             TEXT;
  v_fecha_rechazo      DATE;
  v_idtransaccion_cs   BIGINT;
  v_idtransaccion_rda  BIGINT;
  v_cs                 RECORD;
  v_insertados         INTEGER := 0;
BEGIN
  IF p_rechazos IS NULL OR jsonb_array_length(p_rechazos) = 0 THEN
    RAISE EXCEPTION 'No hay rechazos para registrar';
  END IF;

  FOR v_rechazo IN SELECT * FROM jsonb_array_elements(p_rechazos)
  LOOP
    v_tarjeta_id     := (v_rechazo->>'tarjeta_id')::INTEGER;
    v_periodo        := (v_rechazo->>'periodo')::INTEGER;
    v_socio_id       := (v_rechazo->>'socio_id')::INTEGER;
    v_entidad_id     := (v_rechazo->>'entidad_id')::INTEGER;
    v_importe        := (v_rechazo->>'importe')::NUMERIC;
    v_numero_tarjeta := v_rechazo->>'numero_tarjeta';
    v_motivo         := v_rechazo->>'motivo';
    v_fecha_rechazo  := (v_rechazo->>'fecha_rechazo')::DATE;
    v_idtransaccion_cs := (v_rechazo->>'idtransaccion_cs')::BIGINT;

    -- 1. Verificar y revertir la CS original
    SELECT idtransaccion, cancelado INTO v_cs
    FROM public.cuentas_corrientes
    WHERE idtransaccion = v_idtransaccion_cs;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Transacción original % no encontrada', v_idtransaccion_cs;
    END IF;

    UPDATE public.cuentas_corrientes
    SET cancelado  = GREATEST(0, COALESCE(v_cs.cancelado, 0) - v_importe),
        updated_at = NOW()
    WHERE idtransaccion = v_idtransaccion_cs;

    -- 2. Insertar el comprobante RDA
    INSERT INTO public.cuentas_corrientes (
      socio_id,
      profesional_id,
      entidad_id,
      fecha,
      tipo_comprobante,
      documento_numero,
      importe,
      cancelado,
      vencimiento
    ) VALUES (
      CASE WHEN v_entidad_id = 0 THEN v_socio_id ELSE NULL END,
      CASE WHEN v_entidad_id = 0 THEN NULL ELSE v_socio_id END,
      v_entidad_id,
      v_fecha_rechazo,
      'RDA',
      v_periodo::VARCHAR,
      v_importe,
      0.0,
      v_fecha_rechazo
    )
    RETURNING idtransaccion INTO v_idtransaccion_rda;

    -- 3. Copiar detalle de la CS original (o fallback genérico)
    IF EXISTS (
      SELECT 1 FROM public.detalle_cuentas_corrientes
      WHERE idtransaccion = v_idtransaccion_cs
    ) THEN
      INSERT INTO public.detalle_cuentas_corrientes (
        idtransaccion, item, concepto, cantidad, importe
      )
      SELECT v_idtransaccion_rda, item, concepto, cantidad, importe
      FROM public.detalle_cuentas_corrientes
      WHERE idtransaccion = v_idtransaccion_cs;
    ELSE
      INSERT INTO public.detalle_cuentas_corrientes (
        idtransaccion, item, concepto, cantidad, importe
      ) VALUES (
        v_idtransaccion_rda, 1, 'CS', 1, v_importe
      );
    END IF;

    -- 4. Auditoría
    INSERT INTO public.rechazos_tarjetas (
      tarjeta_id, periodo, socio_id, entidad_id, importe,
      numero_tarjeta, motivo, fecha_rechazo,
      idtransaccion_cs, idtransaccion_rda
    ) VALUES (
      v_tarjeta_id, v_periodo, v_socio_id, v_entidad_id, v_importe,
      v_numero_tarjeta, v_motivo, v_fecha_rechazo,
      v_idtransaccion_cs, v_idtransaccion_rda
    );

    v_insertados := v_insertados + 1;
  END LOOP;

  RETURN jsonb_build_object('insertados', v_insertados);
END;
$$;

COMMENT ON FUNCTION public.registrar_rechazo_debito_automatico IS
'Registra de forma 100% atómica uno o más rechazos de débito automático: revierte el cancelado de la CS original, crea el comprobante RDA, copia el detalle y registra la auditoría en rechazos_tarjetas. Todo o nada.';

-- ============================================================================
-- EJEMPLO DE USO:
-- ============================================================================
-- SELECT public.registrar_rechazo_debito_automatico(
--   '[
--     {
--       "tarjeta_id": 1,
--       "periodo": 202606,
--       "socio_id": 123,
--       "entidad_id": 0,
--       "importe": 18000,
--       "numero_tarjeta": "1234567890123456",
--       "motivo": "051 FONDOS INSUFICIENTES",
--       "fecha_rechazo": "2026-06-30",
--       "idtransaccion_cs": 456
--     },
--     {
--       "tarjeta_id": 1,
--       "periodo": 202606,
--       "socio_id": 123,
--       "entidad_id": 0,
--       "importe": 17000,
--       "numero_tarjeta": "1234567890123456",
--       "motivo": "051 FONDOS INSUFICIENTES",
--       "fecha_rechazo": "2026-06-30",
--       "idtransaccion_cs": 457
--     }
--   ]'::jsonb
-- );
