-- ============================================================================
-- BAJA DE RECIBO DE COBRANZA - ROLLBACK ATÓMICO
-- ============================================================================
-- Requiere que las tablas de trazabilidad existan:
--   create_operaciones_trazabilidad.sql
-- Requiere que la función de generación con trazabilidad esté aplicada:
--   update_generar_recibo_con_trazabilidad.sql
-- ============================================================================

-- ============================================================================
-- TABLA DE AUDITORÍA: recibos_anulados
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.recibos_anulados (
  id              SERIAL PRIMARY KEY,
  numero_recibo   INTEGER       NOT NULL,
  entidad_tipo    VARCHAR(20),
  entidad_id      INTEGER,
  fecha_recibo    DATE,
  importe         NUMERIC(18,2),
  motivo          TEXT          NOT NULL,
  operador_anula  INTEGER,
  asiento_numero  INTEGER,
  fecha_anulacion TIMESTAMPTZ   DEFAULT NOW(),
  datos_cob_json  JSONB
);

CREATE INDEX IF NOT EXISTS idx_recibos_anulados_numero
  ON public.recibos_anulados(numero_recibo);

COMMENT ON TABLE public.recibos_anulados IS
  'Registro de auditoría de recibos dados de baja. Contiene snapshot del COB original y motivo.';

-- ============================================================================
-- FUNCIÓN: anular_recibo_cobranza
-- ============================================================================
-- Realiza el rollback completo y atómico de un recibo:
--   1. Verifica que existe trazabilidad (creada por update_generar_recibo_con_trazabilidad)
--   2. Verifica que el registro COB existe en cuentas_corrientes
--   3. Guarda snapshot en recibos_anulados (auditoría)
--   4. Revierte cancelado en cada transacción pagada
--   5. Borra el COB de cuentas_corrientes
--   6. Borra operaciones_contables (CASCADE borra los detalles → libera FK sobre valores_tesoreria)
--   7. Borra valores_tesoreria del recibo
--   8. Borra el asiento contable (CASCADE borra los items)
-- Todo en una única transacción (commit o rollback automático).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.anular_recibo_cobranza(
  p_numero_recibo INTEGER,
  p_motivo        TEXT,
  p_operador_id   INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_operacion   RECORD;
  v_cob         RECORD;
  v_pago        RECORD;
  v_valor_ids   INTEGER[];
BEGIN
  -- 1. Verificar que existe registro de trazabilidad para este recibo
  SELECT * INTO v_operacion
  FROM public.operaciones_contables
  WHERE tipo_operacion IN ('COBRANZA_SOCIO', 'COBRANZA_PROFESIONAL')
    AND numero_comprobante = p_numero_recibo
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'No se encontró trazabilidad para el Recibo Nro. %. '
      'Solo pueden darse de baja recibos generados con el sistema actual.',
      p_numero_recibo;
  END IF;

  -- 2. Verificar que el registro COB existe
  SELECT * INTO v_cob
  FROM public.cuentas_corrientes
  WHERE tipo_comprobante = 'COB'
    AND documento_numero  = p_numero_recibo::VARCHAR
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'No se encontró el registro COB para el Recibo Nro. %.', p_numero_recibo;
  END IF;

  -- 3. Guardar snapshot en auditoría
  INSERT INTO public.recibos_anulados (
    numero_recibo,
    entidad_tipo,
    entidad_id,
    fecha_recibo,
    importe,
    motivo,
    operador_anula,
    asiento_numero,
    datos_cob_json
  ) VALUES (
    p_numero_recibo,
    v_operacion.entidad_tipo,
    v_operacion.entidad_id,
    v_cob.fecha,
    v_cob.importe,
    p_motivo,
    p_operador_id,
    v_operacion.asiento_numero,
    row_to_json(v_cob)::JSONB
  );

  -- 4. Revertir cancelado en cuentas_corrientes para cada transacción pagada
  FOR v_pago IN
    SELECT idtransaccion, monto
    FROM public.operaciones_detalle_cuentas_corrientes
    WHERE operacion_id = v_operacion.id
  LOOP
    UPDATE public.cuentas_corrientes
    SET
      cancelado  = GREATEST(0, COALESCE(cancelado, 0) - v_pago.monto),
      updated_at = NOW()
    WHERE idtransaccion = v_pago.idtransaccion;
  END LOOP;

  -- 5. Capturar IDs de valores_tesoreria antes de borrar la operación
  SELECT ARRAY(
    SELECT valor_tesoreria_id
    FROM public.operaciones_detalle_valores_tesoreria
    WHERE operacion_id = v_operacion.id
  ) INTO v_valor_ids;

  -- 6. Borrar operaciones_contables
  --    ON DELETE CASCADE borra operaciones_detalle_cuentas_corrientes
  --    y operaciones_detalle_valores_tesoreria (libera la FK sobre valores_tesoreria)
  DELETE FROM public.operaciones_contables
  WHERE id = v_operacion.id;

  -- 7. Borrar valores_tesoreria (la FK desde el detalle ya no existe)
  IF v_valor_ids IS NOT NULL AND array_length(v_valor_ids, 1) > 0 THEN
    DELETE FROM public.valores_tesoreria
    WHERE id = ANY(v_valor_ids);
  END IF;

  -- 8. Borrar COB de cuentas_corrientes
  DELETE FROM public.cuentas_corrientes
  WHERE tipo_comprobante = 'COB'
    AND documento_numero  = p_numero_recibo::VARCHAR;

  -- 9. Borrar asiento contable (CASCADE borra asientos_items)
  DELETE FROM public.asientos_header
  WHERE detalle = 'Recibo Nro. ' || p_numero_recibo;

END;
$$;

COMMENT ON FUNCTION public.anular_recibo_cobranza IS
  'Anula un recibo de cobranza de forma 100% atómica. '
  'Revierte cancelado, borra COB, valores_tesoreria, asiento y trazabilidad. '
  'Guarda snapshot en recibos_anulados. '
  'Solo funciona para recibos creados con trazabilidad (update_generar_recibo_con_trazabilidad).';
