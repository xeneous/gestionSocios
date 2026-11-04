-- Corrección de fecha contable de cobranzas de sponsors: reversión + nuevo asiento.
--
-- Por cada asiento (tipo Ingreso) cuya fecha difiere de la fecha del recibo:
--   1) Reversión : asiento de DIARIO (tipo 0), fecha = fecha del asiento original,
--                  mismas cuentas con DEBE/HABER invertidos.
--                  Detalle: 'REVERSION Corrige Fecha - <detalle original>'
--   2) Nuevo     : asiento de DIARIO (tipo 0), fecha = fecha del recibo (la del usuario),
--                  mismas cuentas y mismos importes que el original.
--                  Detalle: 'Corrige Fecha - <detalle original>'
-- No se modifica ni se borra ningún asiento existente. Los asientos no se referencian entre sí.
-- Tampoco se toca operaciones_contables (el vínculo recibo -> asiento queda para una etapa posterior).
--
-- USO (PostgreSQL / Supabase SQL Editor)
--   PASO 1: ejecutar el bloque CREATE TABLE (queda como registro de lo corregido).
--   PASO 2: ejecutar el bloque DO con dry_run := true (ENSAYO). Termina SIEMPRE con un error
--           'ENSAYO...' que muestra el resumen y deshace todo. Revisar el resumen.
--   PASO 3: con backup hecho, cambiar dry_run a false y ejecutar. Hacerlo UNA sola vez.
--
-- Ejercicio: 02/08/2025 al 01/08/2026. Si algún asiento a corregir tiene fecha original o
-- correcta fuera del ejercicio, el script se detiene (hay que revisarlo a mano).

-- ============================== PASO 1 ==============================
CREATE TABLE IF NOT EXISTS public.correccion_fecha_asientos (
  id             SERIAL PRIMARY KEY,
  nro_recibo     INTEGER NOT NULL,
  fecha_recibo   DATE NOT NULL,
  orig_asiento   INTEGER NOT NULL,
  orig_anio_mes  INTEGER NOT NULL,
  orig_tipo      INTEGER NOT NULL,
  orig_fecha     DATE NOT NULL,
  rev_asiento    INTEGER NOT NULL,
  rev_anio_mes   INTEGER NOT NULL,
  rev_tipo       INTEGER NOT NULL,
  rev_fecha      DATE NOT NULL,
  nuevo_asiento  INTEGER NOT NULL,
  nuevo_anio_mes INTEGER NOT NULL,
  nuevo_tipo     INTEGER NOT NULL,
  nuevo_fecha    DATE NOT NULL,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (orig_asiento, orig_anio_mes, orig_tipo)
);

-- ============================== PASO 2 / 3 ==============================
DO $$
DECLARE
  dry_run        BOOLEAN := true;            -- <<< true = ensayo (deshace todo). false = grabar.
  ej_ini         DATE := DATE '2025-08-02';
  ej_fin         DATE := DATE '2026-08-01';
  r              RECORD;
  v_rev_num      INTEGER;
  v_nuevo_num    INTEGER;
  v_rev_am       INTEGER;
  v_nuevo_am     INTEGER;
  n_corregidos   INTEGER := 0;
  n_items        INTEGER := 0;
  v_cnt          INTEGER;
  v_debe_orig    NUMERIC;
  v_haber_orig   NUMERIC;
  v_debe_total   NUMERIC := 0;
  v_neto         NUMERIC;
  n_excluidos    INTEGER := 0;
  v_excluidos    TEXT := '';
BEGIN
  LOCK TABLE public.asientos_header IN SHARE ROW EXCLUSIVE MODE;

  -- Recibos con más de un asiento posible por detalle: no se adivina, se detiene.
  SELECT COUNT(*) INTO v_cnt
  FROM public.operaciones_contables oc
  WHERE oc.tipo_operacion = 'COBRANZA_SPONSOR'
    AND oc.asiento_numero IS NULL
    AND (SELECT COUNT(*) FROM public.asientos_header h
         WHERE h.tipo_asiento = 1
           AND h.detalle LIKE 'Recibo Cli Nro. ' || oc.numero_comprobante || ' -%') > 1;
  IF v_cnt > 0 THEN
    RAISE EXCEPTION 'Hay % recibo(s) con mas de un asiento posible por detalle. Revisar a mano antes de seguir.', v_cnt;
  END IF;

  FOR r IN
    SELECT oc.numero_comprobante AS nro_recibo,
           oc.fecha              AS fecha_recibo,
           a.asiento, a.anio_mes, a.tipo_asiento,
           a.fecha               AS fecha_asiento,
           a.detalle, a.centro_costo
    FROM public.operaciones_contables oc
    JOIN LATERAL (
      SELECT h.*
      FROM public.asientos_header h
      WHERE (oc.asiento_numero IS NOT NULL
             AND h.asiento      = oc.asiento_numero
             AND h.anio_mes     = oc.asiento_anio_mes
             AND h.tipo_asiento = oc.asiento_tipo)
         OR (oc.asiento_numero IS NULL
             AND h.tipo_asiento = 1
             AND h.detalle LIKE 'Recibo Cli Nro. ' || oc.numero_comprobante || ' -%')
      ORDER BY h.fecha
      LIMIT 1
    ) a ON TRUE
    WHERE oc.tipo_operacion = 'COBRANZA_SPONSOR'
      AND a.fecha <> oc.fecha
      AND NOT EXISTS (
        SELECT 1 FROM public.correccion_fecha_asientos c
        WHERE c.orig_asiento = a.asiento AND c.orig_anio_mes = a.anio_mes AND c.orig_tipo = a.tipo_asiento)
    ORDER BY oc.fecha, oc.numero_comprobante
  LOOP
    -- Salvaguarda de ejercicio
    IF r.fecha_asiento NOT BETWEEN ej_ini AND ej_fin OR r.fecha_recibo NOT BETWEEN ej_ini AND ej_fin THEN
      n_excluidos := n_excluidos + 1;
      v_excluidos := v_excluidos || ' [recibo ' || r.nro_recibo || ': asiento ' || r.fecha_asiento
                     || ' / recibo ' || r.fecha_recibo || ']';
      CONTINUE;
    END IF;

    -- El original debe estar balanceado y tener lineas
    SELECT COUNT(*), COALESCE(SUM(debe),0), COALESCE(SUM(haber),0)
      INTO v_cnt, v_debe_orig, v_haber_orig
    FROM public.asientos_items
    WHERE asiento = r.asiento AND anio_mes = r.anio_mes AND tipo_asiento = r.tipo_asiento;
    IF v_cnt = 0 THEN
      RAISE EXCEPTION 'Recibo % / asiento % no tiene lineas.', r.nro_recibo, r.asiento;
    END IF;
    IF ABS(v_debe_orig - v_haber_orig) > 0.01 THEN
      RAISE EXCEPTION 'Recibo % / asiento % no esta balanceado (debe % haber %).',
        r.nro_recibo, r.asiento, v_debe_orig, v_haber_orig;
    END IF;

    -- Proximos numeros (tipo 0 = Diario), uno por periodo
    v_rev_am   := EXTRACT(YEAR FROM r.fecha_asiento)::INT * 100 + EXTRACT(MONTH FROM r.fecha_asiento)::INT;
    v_nuevo_am := EXTRACT(YEAR FROM r.fecha_recibo)::INT  * 100 + EXTRACT(MONTH FROM r.fecha_recibo)::INT;

    SELECT COALESCE(MAX(asiento),0) + 1 INTO v_rev_num
    FROM public.asientos_header WHERE anio_mes = v_rev_am AND tipo_asiento = 0;

    -- 1) Reversion (fecha original, debe/haber invertidos)
    INSERT INTO public.asientos_header (asiento, anio_mes, tipo_asiento, fecha, detalle, centro_costo)
    VALUES (v_rev_num, v_rev_am, 0, r.fecha_asiento,
            LEFT('REVERSION Corrige Fecha - ' || COALESCE(r.detalle,''), 255), r.centro_costo);

    INSERT INTO public.asientos_items (asiento, anio_mes, tipo_asiento, item, cuenta_id, debe, haber, observacion, centro_costo)
    SELECT v_rev_num, v_rev_am, 0, i.item, i.cuenta_id, i.haber, i.debe, i.observacion, i.centro_costo
    FROM public.asientos_items i
    WHERE i.asiento = r.asiento AND i.anio_mes = r.anio_mes AND i.tipo_asiento = r.tipo_asiento;

    -- 2) Nuevo asiento (fecha del recibo, mismos importes)
    SELECT COALESCE(MAX(asiento),0) + 1 INTO v_nuevo_num
    FROM public.asientos_header WHERE anio_mes = v_nuevo_am AND tipo_asiento = 0;

    INSERT INTO public.asientos_header (asiento, anio_mes, tipo_asiento, fecha, detalle, centro_costo)
    VALUES (v_nuevo_num, v_nuevo_am, 0, r.fecha_recibo,
            LEFT('Corrige Fecha - ' || COALESCE(r.detalle,''), 255), r.centro_costo);

    INSERT INTO public.asientos_items (asiento, anio_mes, tipo_asiento, item, cuenta_id, debe, haber, observacion, centro_costo)
    SELECT v_nuevo_num, v_nuevo_am, 0, i.item, i.cuenta_id, i.debe, i.haber, i.observacion, i.centro_costo
    FROM public.asientos_items i
    WHERE i.asiento = r.asiento AND i.anio_mes = r.anio_mes AND i.tipo_asiento = r.tipo_asiento;

    INSERT INTO public.correccion_fecha_asientos (
      nro_recibo, fecha_recibo,
      orig_asiento, orig_anio_mes, orig_tipo, orig_fecha,
      rev_asiento, rev_anio_mes, rev_tipo, rev_fecha,
      nuevo_asiento, nuevo_anio_mes, nuevo_tipo, nuevo_fecha)
    VALUES (r.nro_recibo, r.fecha_recibo,
      r.asiento, r.anio_mes, r.tipo_asiento, r.fecha_asiento,
      v_rev_num, v_rev_am, 0, r.fecha_asiento,
      v_nuevo_num, v_nuevo_am, 0, r.fecha_recibo);

    n_corregidos := n_corregidos + 1;
    n_items      := n_items + v_cnt;
    v_debe_total := v_debe_total + v_debe_orig;
  END LOOP;

  -- Verificacion global: original + reversion = 0 en cada cuenta; nuevo = original
  SELECT COALESCE(SUM(ABS(x.neto)),0) INTO v_neto
  FROM (
    SELECT i.cuenta_id,
           SUM(CASE WHEN c.id IS NOT NULL THEN i.debe - i.haber ELSE 0 END) AS neto
    FROM public.correccion_fecha_asientos c
    JOIN public.asientos_items i
      ON (i.asiento = c.orig_asiento AND i.anio_mes = c.orig_anio_mes AND i.tipo_asiento = c.orig_tipo)
      OR (i.asiento = c.rev_asiento  AND i.anio_mes = c.rev_anio_mes  AND i.tipo_asiento = c.rev_tipo)
    GROUP BY i.cuenta_id
  ) x;
  IF v_neto > 0.01 THEN
    RAISE EXCEPTION 'Verificacion fallida: original + reversion no netea a cero (diferencia %).', v_neto;
  END IF;

  IF dry_run THEN
    RAISE EXCEPTION 'ENSAYO OK (nada grabado): % asientos a corregir, % lineas originales, % pesos de debe. Se crearian % asientos de reversion + % nuevos. EXCLUIDOS por estar fuera del ejercicio (% casos, revisar a mano):%',
      n_corregidos, n_items, v_debe_total, n_corregidos, n_corregidos, n_excluidos, COALESCE(NULLIF(v_excluidos,''), ' ninguno');
  END IF;

  RAISE NOTICE 'GRABADO: % asientos corregidos (% reversiones + % nuevos). Excluidos fuera de ejercicio: %.%',
    n_corregidos, n_corregidos, n_corregidos, n_excluidos, v_excluidos;
END $$;

-- Control posterior (solo lectura): lo corregido
-- SELECT * FROM public.correccion_fecha_asientos ORDER BY nro_recibo;
