-- Corrección de fecha contable de cobranzas de sponsors con TABLA INTERMEDIA (staging).
-- Reemplaza a corregir_fecha_asientos_cobranzas_sponsor.sql (que grababa directo).
--
-- FLUJO (PostgreSQL / Supabase SQL Editor, ejecutar cada PASO por separado)
--   PASO 1: crear tablas intermedias, tabla de registro y vista de controles. (No toca contabilidad)
--   PASO 2: cargar la tabla intermedia con las reversiones y los asientos nuevos. (No toca contabilidad)
--   PASO 3: revisar controles y contenido:  SELECT * FROM public.v_stg_correccion_controles;
--           Todo debe dar 'OK'. Se puede repetir el PASO 2 las veces que haga falta mientras nada se importe.
--   PASO 4: importar a asientos_header / asientos_items. Con dry_run := true es un ensayo (deshace todo).
--           Se niega a importar si algun control da ERROR. Hacer backup antes de dry_run := false.
--
-- Reversion: asiento de DIARIO (tipo 0), fecha = fecha del asiento original, DEBE/HABER invertidos.
--            Detalle: 'REVERSION Corrige Fecha - <detalle original>'
-- Nuevo    : asiento de DIARIO (tipo 0), fecha = fecha del recibo (la del usuario), mismos importes.
--            Detalle: 'Corrige Fecha - <detalle original>'
-- No se modifica ni se borra ningun asiento existente; no se toca operaciones_contables.
-- Alcance: ejercicio 02/08/2025 - 01/08/2026. Lo que cae fuera se omite y se informa en el PASO 2.

-- ============================== PASO 1 ==============================
CREATE TABLE IF NOT EXISTS public.stg_correccion_header (
  id            SERIAL PRIMARY KEY,
  nro_recibo    INTEGER NOT NULL,
  clase         TEXT NOT NULL CHECK (clase IN ('REVERSION','NUEVO')),
  asiento       INTEGER NOT NULL,
  anio_mes      INTEGER NOT NULL,
  tipo_asiento  INTEGER NOT NULL DEFAULT 0,
  fecha         DATE NOT NULL,
  detalle       VARCHAR(255),
  centro_costo  INTEGER,
  orig_asiento  INTEGER NOT NULL,
  orig_anio_mes INTEGER NOT NULL,
  orig_tipo     INTEGER NOT NULL,
  orig_fecha    DATE NOT NULL,
  fecha_recibo  DATE NOT NULL,
  importado     BOOLEAN NOT NULL DEFAULT false,
  importado_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.stg_correccion_items (
  id            SERIAL PRIMARY KEY,
  stg_header_id INTEGER NOT NULL REFERENCES public.stg_correccion_header(id) ON DELETE CASCADE,
  item          INTEGER NOT NULL,
  cuenta_id     INTEGER,
  debe          NUMERIC(18,2) DEFAULT 0,
  haber         NUMERIC(18,2) DEFAULT 0,
  observacion   VARCHAR(255),
  centro_costo  INTEGER
);

-- Registro permanente de lo corregido (numeros de asiento original / reversion / nuevo).
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

-- Controles sobre lo que hay en la tabla intermedia (pendiente de importar).
CREATE OR REPLACE VIEW public.v_stg_correccion_controles AS
WITH h AS (
  SELECT * FROM public.stg_correccion_header WHERE NOT importado
),
li AS (
  SELECT h.id AS hid, h.nro_recibo, h.clase, i.cuenta_id, i.debe, i.haber
  FROM h JOIN public.stg_correccion_items i ON i.stg_header_id = h.id
),
orig AS (
  SELECT DISTINCT nro_recibo, orig_asiento, orig_anio_mes, orig_tipo FROM h
),
orig_li AS (
  SELECT o.nro_recibo, i.cuenta_id, SUM(i.debe) AS debe, SUM(i.haber) AS haber
  FROM orig o
  JOIN public.asientos_items i
    ON i.asiento = o.orig_asiento AND i.anio_mes = o.orig_anio_mes AND i.tipo_asiento = o.orig_tipo
  GROUP BY o.nro_recibo, i.cuenta_id
),
rev_li AS (
  SELECT nro_recibo, cuenta_id, SUM(debe) AS debe, SUM(haber) AS haber
  FROM li WHERE clase = 'REVERSION' GROUP BY nro_recibo, cuenta_id
),
new_li AS (
  SELECT nro_recibo, cuenta_id, SUM(debe) AS debe, SUM(haber) AS haber
  FROM li WHERE clase = 'NUEVO' GROUP BY nro_recibo, cuenta_id
),
controles AS (
  SELECT '01 Hay asientos cargados en la tabla intermedia'::text AS control,
         (CASE WHEN (SELECT COUNT(*) FROM h) > 0 THEN 0 ELSE 1 END)::bigint AS errores
  UNION ALL
  SELECT '02 Cada recibo tiene exactamente 1 reversion y 1 nuevo',
         (SELECT COUNT(*) FROM (
            SELECT nro_recibo FROM h GROUP BY nro_recibo
            HAVING COUNT(*) FILTER (WHERE clase = 'REVERSION') <> 1
                OR COUNT(*) FILTER (WHERE clase = 'NUEVO') <> 1) x)
  UNION ALL
  SELECT '03 Todos los asientos son tipo Diario (0)',
         (SELECT COUNT(*) FROM h WHERE tipo_asiento <> 0)
  UNION ALL
  SELECT '04 Cada asiento tiene lineas',
         (SELECT COUNT(*) FROM h WHERE NOT EXISTS (SELECT 1 FROM li WHERE li.hid = h.id))
  UNION ALL
  SELECT '05 Cada asiento esta balanceado (debe = haber)',
         (SELECT COUNT(*) FROM (
            SELECT hid FROM li GROUP BY hid
            HAVING ABS(SUM(debe) - SUM(haber)) > 0.005) x)
  UNION ALL
  SELECT '06 Original + reversion = CERO en cada recibo y cuenta',
         (SELECT COUNT(*) FROM orig_li o
            FULL JOIN rev_li r ON r.nro_recibo = o.nro_recibo AND r.cuenta_id = o.cuenta_id
          WHERE ABS(COALESCE(o.debe,0) - COALESCE(r.haber,0)) > 0.005
             OR ABS(COALESCE(o.haber,0) - COALESCE(r.debe,0)) > 0.005)
  UNION ALL
  SELECT '07 Nuevo = original en cada recibo y cuenta (mismos importes)',
         (SELECT COUNT(*) FROM orig_li o
            FULL JOIN new_li n ON n.nro_recibo = o.nro_recibo AND n.cuenta_id = o.cuenta_id
          WHERE ABS(COALESCE(o.debe,0) - COALESCE(n.debe,0)) > 0.005
             OR ABS(COALESCE(o.haber,0) - COALESCE(n.haber,0)) > 0.005)
  UNION ALL
  SELECT '08 Total general de la tabla intermedia balanceado (debe = haber)',
         (CASE WHEN ABS((SELECT COALESCE(SUM(debe),0) - COALESCE(SUM(haber),0) FROM li)) > 0.005 THEN 1 ELSE 0 END)::bigint
  UNION ALL
  SELECT '09 Los numeros de asiento no existen todavia en la contabilidad',
         (SELECT COUNT(*) FROM h
          WHERE EXISTS (SELECT 1 FROM public.asientos_header a
                        WHERE a.asiento = h.asiento AND a.anio_mes = h.anio_mes AND a.tipo_asiento = h.tipo_asiento))
  UNION ALL
  SELECT '10 No hay numeros repetidos dentro de la tabla intermedia',
         (SELECT COUNT(*) FROM (
            SELECT 1 FROM h GROUP BY asiento, anio_mes, tipo_asiento HAVING COUNT(*) > 1) x)
  UNION ALL
  SELECT '11 El periodo de cada asiento coincide con su fecha',
         (SELECT COUNT(*) FROM h
          WHERE anio_mes <> EXTRACT(YEAR FROM fecha)::INT * 100 + EXTRACT(MONTH FROM fecha)::INT)
  UNION ALL
  SELECT '12 Todas las fechas dentro del ejercicio 02/08/2025 - 01/08/2026',
         (SELECT COUNT(*) FROM h WHERE fecha NOT BETWEEN DATE '2025-08-02' AND DATE '2026-08-01')
  UNION ALL
  SELECT '13 Los originales no fueron corregidos antes',
         (SELECT COUNT(*) FROM h
          WHERE EXISTS (SELECT 1 FROM public.correccion_fecha_asientos c
                        WHERE c.orig_asiento = h.orig_asiento AND c.orig_anio_mes = h.orig_anio_mes
                          AND c.orig_tipo = h.orig_tipo))
)
SELECT control, errores, CASE WHEN errores = 0 THEN 'OK' ELSE 'ERROR' END AS resultado
FROM controles
ORDER BY control;

-- ============================== PASO 2 ==============================
-- Carga la tabla intermedia (se puede repetir: borra primero lo que todavia no se importo).
DO $$
DECLARE
  ej_ini       DATE := DATE '2025-08-02';
  ej_fin       DATE := DATE '2026-08-01';
  r            RECORD;
  v_rev_am     INTEGER;
  v_nuevo_am   INTEGER;
  v_rev_num    INTEGER;
  v_nuevo_num  INTEGER;
  v_rev_id     INTEGER;
  v_nuevo_id   INTEGER;
  v_cnt        INTEGER;
  n_cargados   INTEGER := 0;
  n_excluidos  INTEGER := 0;
  v_excluidos  TEXT := '';
BEGIN
  LOCK TABLE public.asientos_header IN SHARE ROW EXCLUSIVE MODE;

  DELETE FROM public.stg_correccion_header WHERE NOT importado;

  -- Recibos con mas de un asiento posible por detalle: no se adivina, se detiene.
  SELECT COUNT(*) INTO v_cnt
  FROM public.operaciones_contables oc
  WHERE oc.tipo_operacion = 'COBRANZA_SPONSOR'
    AND oc.asiento_numero IS NULL
    AND (SELECT COUNT(*) FROM public.asientos_header h
         WHERE h.tipo_asiento = 1
           AND h.detalle LIKE 'Recibo Cli Nro. ' || oc.numero_comprobante || ' -%') > 1;
  IF v_cnt > 0 THEN
    RAISE EXCEPTION 'Hay % recibo(s) con mas de un asiento posible por detalle. Revisar a mano.', v_cnt;
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
    IF r.fecha_asiento NOT BETWEEN ej_ini AND ej_fin OR r.fecha_recibo NOT BETWEEN ej_ini AND ej_fin THEN
      n_excluidos := n_excluidos + 1;
      v_excluidos := v_excluidos || ' [recibo ' || r.nro_recibo || ': asiento ' || r.fecha_asiento
                     || ' / recibo ' || r.fecha_recibo || ']';
      CONTINUE;
    END IF;

    v_rev_am   := EXTRACT(YEAR FROM r.fecha_asiento)::INT * 100 + EXTRACT(MONTH FROM r.fecha_asiento)::INT;
    v_nuevo_am := EXTRACT(YEAR FROM r.fecha_recibo)::INT  * 100 + EXTRACT(MONTH FROM r.fecha_recibo)::INT;

    -- Reversion
    SELECT GREATEST(
             (SELECT COALESCE(MAX(asiento),0) FROM public.asientos_header
               WHERE anio_mes = v_rev_am AND tipo_asiento = 0),
             (SELECT COALESCE(MAX(asiento),0) FROM public.stg_correccion_header
               WHERE anio_mes = v_rev_am AND tipo_asiento = 0 AND NOT importado)) + 1
      INTO v_rev_num;

    INSERT INTO public.stg_correccion_header
      (nro_recibo, clase, asiento, anio_mes, tipo_asiento, fecha, detalle, centro_costo,
       orig_asiento, orig_anio_mes, orig_tipo, orig_fecha, fecha_recibo)
    VALUES
      (r.nro_recibo, 'REVERSION', v_rev_num, v_rev_am, 0, r.fecha_asiento,
       LEFT('REVERSION Corrige Fecha - ' || COALESCE(r.detalle,''), 255), r.centro_costo,
       r.asiento, r.anio_mes, r.tipo_asiento, r.fecha_asiento, r.fecha_recibo)
    RETURNING id INTO v_rev_id;

    INSERT INTO public.stg_correccion_items (stg_header_id, item, cuenta_id, debe, haber, observacion, centro_costo)
    SELECT v_rev_id, i.item, i.cuenta_id, i.haber, i.debe, i.observacion, i.centro_costo
    FROM public.asientos_items i
    WHERE i.asiento = r.asiento AND i.anio_mes = r.anio_mes AND i.tipo_asiento = r.tipo_asiento;

    -- Nuevo
    SELECT GREATEST(
             (SELECT COALESCE(MAX(asiento),0) FROM public.asientos_header
               WHERE anio_mes = v_nuevo_am AND tipo_asiento = 0),
             (SELECT COALESCE(MAX(asiento),0) FROM public.stg_correccion_header
               WHERE anio_mes = v_nuevo_am AND tipo_asiento = 0 AND NOT importado)) + 1
      INTO v_nuevo_num;

    INSERT INTO public.stg_correccion_header
      (nro_recibo, clase, asiento, anio_mes, tipo_asiento, fecha, detalle, centro_costo,
       orig_asiento, orig_anio_mes, orig_tipo, orig_fecha, fecha_recibo)
    VALUES
      (r.nro_recibo, 'NUEVO', v_nuevo_num, v_nuevo_am, 0, r.fecha_recibo,
       LEFT('Corrige Fecha - ' || COALESCE(r.detalle,''), 255), r.centro_costo,
       r.asiento, r.anio_mes, r.tipo_asiento, r.fecha_asiento, r.fecha_recibo)
    RETURNING id INTO v_nuevo_id;

    INSERT INTO public.stg_correccion_items (stg_header_id, item, cuenta_id, debe, haber, observacion, centro_costo)
    SELECT v_nuevo_id, i.item, i.cuenta_id, i.debe, i.haber, i.observacion, i.centro_costo
    FROM public.asientos_items i
    WHERE i.asiento = r.asiento AND i.anio_mes = r.anio_mes AND i.tipo_asiento = r.tipo_asiento;

    n_cargados := n_cargados + 1;
  END LOOP;

  RAISE NOTICE 'Tabla intermedia cargada: % recibos (% reversiones + % nuevos). Excluidos fuera de ejercicio: %.%',
    n_cargados, n_cargados, n_cargados, n_excluidos, v_excluidos;
END $$;

-- ============================== PASO 3 (solo lectura) ==============================
-- Controles (todo debe decir OK):
--   SELECT * FROM public.v_stg_correccion_controles;
--
-- Contenido, una fila por linea (para exportar y revisar):
--   SELECT h.nro_recibo, h.clase, h.asiento, h.anio_mes, h.fecha, h.detalle,
--          i.item, i.cuenta_id AS cuenta, cu.descripcion AS nombre_cuenta, i.debe, i.haber, i.observacion,
--          h.orig_asiento, h.orig_fecha, h.fecha_recibo
--   FROM public.stg_correccion_header h
--   JOIN public.stg_correccion_items i ON i.stg_header_id = h.id
--   LEFT JOIN public.cuentas cu ON cu.cuenta = i.cuenta_id
--   WHERE NOT h.importado
--   ORDER BY h.fecha_recibo, h.nro_recibo, h.clase DESC, i.item;
--
-- Efecto neto por periodo y cuenta (cuanto se mueve entre meses):
--   SELECT h.anio_mes AS periodo, i.cuenta_id AS cuenta, cu.descripcion,
--          SUM(i.debe) AS debe, SUM(i.haber) AS haber, SUM(i.debe) - SUM(i.haber) AS neto
--   FROM public.stg_correccion_header h
--   JOIN public.stg_correccion_items i ON i.stg_header_id = h.id
--   LEFT JOIN public.cuentas cu ON cu.cuenta = i.cuenta_id
--   WHERE NOT h.importado
--   GROUP BY h.anio_mes, i.cuenta_id, cu.descripcion
--   ORDER BY h.anio_mes, i.cuenta_id;

-- ============================== PASO 4 ==============================
-- Importa lo pendiente de la tabla intermedia a la contabilidad. Hacerlo UNA vez, con backup.
DO $$
DECLARE
  dry_run     BOOLEAN := true;     -- <<< true = ensayo (deshace todo). false = grabar.
  v_errores   INTEGER;
  v_detalle   TEXT;
  n_headers   INTEGER;
  n_items     INTEGER;
  n_recibos   INTEGER;
BEGIN
  LOCK TABLE public.asientos_header IN SHARE ROW EXCLUSIVE MODE;

  SELECT COUNT(*), string_agg(control, '; ')
    INTO v_errores, v_detalle
  FROM public.v_stg_correccion_controles WHERE resultado = 'ERROR';
  IF v_errores > 0 THEN
    RAISE EXCEPTION 'No se importa: controles con ERROR -> %', v_detalle;
  END IF;

  INSERT INTO public.asientos_header (asiento, anio_mes, tipo_asiento, fecha, detalle, centro_costo)
  SELECT asiento, anio_mes, tipo_asiento, fecha, detalle, centro_costo
  FROM public.stg_correccion_header WHERE NOT importado;
  GET DIAGNOSTICS n_headers = ROW_COUNT;

  INSERT INTO public.asientos_items (asiento, anio_mes, tipo_asiento, item, cuenta_id, debe, haber, observacion, centro_costo)
  SELECT h.asiento, h.anio_mes, h.tipo_asiento, i.item, i.cuenta_id, i.debe, i.haber, i.observacion, i.centro_costo
  FROM public.stg_correccion_header h
  JOIN public.stg_correccion_items i ON i.stg_header_id = h.id
  WHERE NOT h.importado;
  GET DIAGNOSTICS n_items = ROW_COUNT;

  INSERT INTO public.correccion_fecha_asientos (
    nro_recibo, fecha_recibo,
    orig_asiento, orig_anio_mes, orig_tipo, orig_fecha,
    rev_asiento, rev_anio_mes, rev_tipo, rev_fecha,
    nuevo_asiento, nuevo_anio_mes, nuevo_tipo, nuevo_fecha)
  SELECT rv.nro_recibo, rv.fecha_recibo,
         rv.orig_asiento, rv.orig_anio_mes, rv.orig_tipo, rv.orig_fecha,
         rv.asiento, rv.anio_mes, rv.tipo_asiento, rv.fecha,
         nw.asiento, nw.anio_mes, nw.tipo_asiento, nw.fecha
  FROM public.stg_correccion_header rv
  JOIN public.stg_correccion_header nw
    ON nw.nro_recibo = rv.nro_recibo AND nw.clase = 'NUEVO' AND NOT nw.importado
  WHERE rv.clase = 'REVERSION' AND NOT rv.importado;
  GET DIAGNOSTICS n_recibos = ROW_COUNT;

  UPDATE public.stg_correccion_header SET importado = true, importado_at = NOW() WHERE NOT importado;

  IF dry_run THEN
    RAISE EXCEPTION 'ENSAYO DE IMPORTACION OK (nada grabado): % asientos, % lineas, % recibos corregidos.',
      n_headers, n_items, n_recibos;
  END IF;

  RAISE NOTICE 'IMPORTADO: % asientos, % lineas, % recibos corregidos.', n_headers, n_items, n_recibos;
END $$;

-- Control posterior (solo lectura): lo corregido
--   SELECT * FROM public.correccion_fecha_asientos ORDER BY nro_recibo;
