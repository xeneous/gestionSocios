-- Reponer el COB 3711 de FIGUEREDO, NATALIA (socio 5153), $28.500, 11/12/2025.
--
-- La baja de prueba del 03/11/2026 (recibos_anulados, numero_recibo 3711) borro por numero TODOS los COB
-- 'documento_numero = 3711', incluido este, que era de otra persona. La fila completa quedo guardada en
-- recibos_anulados.datos_cob_json: se repone identica (mismo idtransaccion, mismas fechas).
-- No modifica nada mas. Si el COB ya existe, no hace nada.
--
-- USO: dry_run := true (ensayo, muestra resumen y deshace). Con backup, dry_run := false.

DO $$
DECLARE
  dry_run BOOLEAN := true;     -- <<< true = ensayo. false = grabar.
  v_json  JSONB;
  v_n     INTEGER;
BEGIN
  SELECT datos_cob_json INTO v_json
  FROM public.recibos_anulados
  WHERE numero_recibo = 3711
  ORDER BY fecha_anulacion DESC
  LIMIT 1;

  IF v_json IS NULL THEN
    RAISE EXCEPTION 'No hay datos_cob_json para el recibo 3711 en recibos_anulados.';
  END IF;

  IF (v_json->>'socio_id')::INT <> 5153 OR (v_json->>'importe')::NUMERIC <> 28500 THEN
    RAISE EXCEPTION 'El COB guardado no es el esperado (socio 5153, importe 28500): %', v_json;
  END IF;

  INSERT INTO public.cuentas_corrientes
  SELECT (jsonb_populate_record(NULL::public.cuentas_corrientes, v_json)).*
  WHERE NOT EXISTS (
    SELECT 1 FROM public.cuentas_corrientes
    WHERE idtransaccion = (v_json->>'idtransaccion')::BIGINT);
  GET DIAGNOSTICS v_n = ROW_COUNT;

  IF dry_run THEN
    RAISE EXCEPTION 'ENSAYO OK (nada grabado): se repondria % fila(s) COB 3711 de FIGUEREDO ($28500).', v_n;
  END IF;
END $$;

-- Verificacion posterior:
--   SELECT idtransaccion, socio_id, documento_numero, fecha, importe, cancelado
--   FROM public.cuentas_corrientes
--   WHERE tipo_comprobante = 'COB' AND documento_numero = '3711';
