-- TRAZABILIDAD 2: baja de recibo con CONTRAASIENTO, resuelta por NUMERO (no por detalle).
--
-- Reemplaza anular_recibo_cobranza (create_anular_recibo_cobranza.sql). Misma firma, la app no cambia.
-- Cambios respecto de la version anterior:
--   * El asiento se identifica por el vinculo operaciones_contables.asiento_numero / anio_mes / tipo
--     (antes se borraba con WHERE detalle = 'Recibo Nro. N', que nunca coincidia con el detalle real
--     'Recibo Nro. N - Apellido, Nombre', dejando el asiento huerfano).
--   * El asiento NO se borra: se genera un asiento de reversion (tipo Diario 0, fecha = fecha de la baja,
--     mismas cuentas con DEBE/HABER invertidos). El original queda intacto.
--   * Los numeros del asiento original y del de reversion quedan en recibos_anulados.
--   * Si el recibo no tiene asiento vinculado, la baja se rechaza ANTES de modificar nada
--     (ejecutar antes trazabilidad_01_vinculos_recibo_asiento.sql).
--
-- Todo en una unica transaccion. Solo crea/reemplaza funcion y agrega columnas; no modifica datos.
-- Probar primero en el entorno local (docs/BACKUPS_Y_ENTORNO_LOCAL.md).

ALTER TABLE public.recibos_anulados
  ADD COLUMN IF NOT EXISTS asiento_anio_mes INTEGER,
  ADD COLUMN IF NOT EXISTS asiento_tipo     INTEGER,
  ADD COLUMN IF NOT EXISTS rev_asiento      INTEGER,
  ADD COLUMN IF NOT EXISTS rev_anio_mes     INTEGER,
  ADD COLUMN IF NOT EXISTS rev_tipo         INTEGER,
  ADD COLUMN IF NOT EXISTS rev_fecha        DATE;

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
  v_asiento     RECORD;
  v_valor_ids   INTEGER[];
  v_rev_fecha   DATE := CURRENT_DATE;
  v_rev_am      INTEGER;
  v_rev_num     INTEGER;
  v_cnt         INTEGER;
BEGIN
  -- 0. Los numeros de recibo NO son unicos en la base (hay repetidos). Si el numero esta repetido
  --    se rechaza: dar de baja por numero podria afectar a otro recibo.
  SELECT COUNT(*) INTO v_cnt
  FROM public.operaciones_contables
  WHERE tipo_operacion IN ('COBRANZA_SOCIO', 'COBRANZA_PROFESIONAL')
    AND numero_comprobante = p_numero_recibo;
  IF v_cnt > 1 THEN
    RAISE EXCEPTION
      'El Recibo Nro. % esta repetido (% recibos con ese numero). No se puede dar de baja por numero; '
      'resolver primero la duplicacion.', p_numero_recibo, v_cnt;
  END IF;

  -- 1. Trazabilidad del recibo
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

  -- 2. Registro COB: del numero Y de la misma persona de la operacion
  SELECT COUNT(*) INTO v_cnt
  FROM public.cuentas_corrientes
  WHERE tipo_comprobante = 'COB'
    AND documento_numero = p_numero_recibo::VARCHAR
    AND ((v_operacion.tipo_operacion = 'COBRANZA_SOCIO'       AND socio_id       = v_operacion.entidad_id)
      OR (v_operacion.tipo_operacion = 'COBRANZA_PROFESIONAL' AND profesional_id = v_operacion.entidad_id));
  IF v_cnt > 1 THEN
    RAISE EXCEPTION 'El Recibo Nro. % tiene % registros COB para la misma persona. Resolver a mano.',
      p_numero_recibo, v_cnt;
  END IF;

  SELECT * INTO v_cob
  FROM public.cuentas_corrientes
  WHERE tipo_comprobante = 'COB'
    AND documento_numero = p_numero_recibo::VARCHAR
    AND ((v_operacion.tipo_operacion = 'COBRANZA_SOCIO'       AND socio_id       = v_operacion.entidad_id)
      OR (v_operacion.tipo_operacion = 'COBRANZA_PROFESIONAL' AND profesional_id = v_operacion.entidad_id));

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'No se encontró el registro COB para el Recibo Nro. %.', p_numero_recibo;
  END IF;

  -- 3. Asiento vinculado POR NUMERO. Si no hay vinculo, se rechaza sin tocar nada.
  IF v_operacion.asiento_numero IS NULL THEN
    RAISE EXCEPTION
      'El Recibo Nro. % no tiene asiento contable vinculado. No se puede dar de baja '
      'sin reversar su asiento. Completar el vinculo con trazabilidad_01_vinculos_recibo_asiento.sql.',
      p_numero_recibo;
  END IF;

  SELECT h.* INTO v_asiento
  FROM public.asientos_header h
  WHERE h.asiento      = v_operacion.asiento_numero
    AND h.anio_mes     = v_operacion.asiento_anio_mes
    AND h.tipo_asiento = v_operacion.asiento_tipo;

  IF NOT FOUND THEN
    RAISE EXCEPTION
      'El Recibo Nro. % apunta al asiento % (periodo %, tipo %) que no existe.',
      p_numero_recibo, v_operacion.asiento_numero, v_operacion.asiento_anio_mes, v_operacion.asiento_tipo;
  END IF;

  SELECT COUNT(*) INTO v_cnt
  FROM public.asientos_items
  WHERE asiento = v_asiento.asiento AND anio_mes = v_asiento.anio_mes AND tipo_asiento = v_asiento.tipo_asiento;
  IF v_cnt = 0 THEN
    RAISE EXCEPTION 'El asiento % del Recibo Nro. % no tiene lineas.', v_asiento.asiento, p_numero_recibo;
  END IF;

  -- 4. Contraasiento (tipo Diario 0, fecha de la baja, DEBE/HABER invertidos)
  LOCK TABLE public.asientos_header IN SHARE ROW EXCLUSIVE MODE;

  v_rev_am := EXTRACT(YEAR FROM v_rev_fecha)::INT * 100 + EXTRACT(MONTH FROM v_rev_fecha)::INT;

  SELECT COALESCE(MAX(asiento), 0) + 1 INTO v_rev_num
  FROM public.asientos_header
  WHERE anio_mes = v_rev_am AND tipo_asiento = 0;

  INSERT INTO public.asientos_header (asiento, anio_mes, tipo_asiento, fecha, detalle, centro_costo)
  VALUES (v_rev_num, v_rev_am, 0, v_rev_fecha,
          LEFT('REVERSION Baja Recibo Nro. ' || p_numero_recibo || ' - ' || COALESCE(v_asiento.detalle, ''), 255),
          v_asiento.centro_costo);

  INSERT INTO public.asientos_items (asiento, anio_mes, tipo_asiento, item, cuenta_id, debe, haber, observacion, centro_costo)
  SELECT v_rev_num, v_rev_am, 0, i.item, i.cuenta_id, i.haber, i.debe, i.observacion, i.centro_costo
  FROM public.asientos_items i
  WHERE i.asiento = v_asiento.asiento AND i.anio_mes = v_asiento.anio_mes AND i.tipo_asiento = v_asiento.tipo_asiento;

  -- 5. Auditoría (con los numeros de asiento original y de reversion)
  INSERT INTO public.recibos_anulados (
    numero_recibo, entidad_tipo, entidad_id, fecha_recibo, importe, motivo, operador_anula,
    asiento_numero, asiento_anio_mes, asiento_tipo,
    rev_asiento, rev_anio_mes, rev_tipo, rev_fecha,
    datos_cob_json
  ) VALUES (
    p_numero_recibo, v_operacion.entidad_tipo, v_operacion.entidad_id, v_cob.fecha, v_cob.importe,
    p_motivo, p_operador_id,
    v_asiento.asiento, v_asiento.anio_mes, v_asiento.tipo_asiento,
    v_rev_num, v_rev_am, 0, v_rev_fecha,
    row_to_json(v_cob)::JSONB
  );

  -- 6. Revertir cancelado en cada transacción pagada
  FOR v_pago IN
    SELECT idtransaccion, monto
    FROM public.operaciones_detalle_cuentas_corrientes
    WHERE operacion_id = v_operacion.id
  LOOP
    UPDATE public.cuentas_corrientes
    SET cancelado  = GREATEST(0, COALESCE(cancelado, 0) - v_pago.monto),
        updated_at = NOW()
    WHERE idtransaccion = v_pago.idtransaccion;
  END LOOP;

  -- 7. Capturar valores_tesoreria antes de borrar la operación
  SELECT ARRAY(
    SELECT valor_tesoreria_id
    FROM public.operaciones_detalle_valores_tesoreria
    WHERE operacion_id = v_operacion.id
  ) INTO v_valor_ids;

  -- 8. Borrar operaciones_contables (CASCADE borra los detalles)
  DELETE FROM public.operaciones_contables WHERE id = v_operacion.id;

  -- 9. Borrar valores_tesoreria
  IF v_valor_ids IS NOT NULL AND array_length(v_valor_ids, 1) > 0 THEN
    DELETE FROM public.valores_tesoreria WHERE id = ANY(v_valor_ids);
  END IF;

  -- 10. Borrar COB de cuentas_corrientes
  DELETE FROM public.cuentas_corrientes
  WHERE idtransaccion = v_cob.idtransaccion;

  -- El asiento original NO se borra: queda reversado por el contraasiento (paso 4).
END;
$$;

COMMENT ON FUNCTION public.anular_recibo_cobranza IS
  'Anula un recibo de cobranza de forma atómica. Identifica su asiento por el vínculo numérico de '
  'operaciones_contables (no por detalle) y lo reversa con un contraasiento de Diario fechado el día de la baja; '
  'no borra el asiento original. Revierte cancelado, borra COB y valores_tesoreria, y guarda auditoría '
  '(con números de asiento original y de reversión) en recibos_anulados.';

-- Verificacion: contraasientos generados por bajas (solo lectura)
--   SELECT numero_recibo, fecha_anulacion, asiento_numero AS asiento_original, asiento_anio_mes,
--          rev_asiento, rev_anio_mes, rev_fecha, motivo
--   FROM public.recibos_anulados WHERE rev_asiento IS NOT NULL ORDER BY fecha_anulacion DESC;
