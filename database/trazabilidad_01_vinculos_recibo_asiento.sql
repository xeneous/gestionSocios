-- TRAZABILIDAD 1: completar el vinculo recibo -> asiento (por numero) en operaciones_contables.
--
-- operaciones_contables.asiento_numero / asiento_anio_mes / asiento_tipo identifican el asiento de
-- cada recibo. Hay recibos historicos sin ese vinculo (socios y profesionales nunca lo guardaron;
-- en sponsors faltan varios). Este script lo completa buscando UNA SOLA VEZ el asiento por su detalle
-- y de ahi en adelante todo se resuelve por numero.
--
--   COBRANZA_SOCIO / COBRANZA_PROFESIONAL : asiento tipo 1, detalle 'Recibo Nro. N' o 'Recibo Nro. N - ...'
--   COBRANZA_SPONSOR                      : asiento tipo 1, detalle 'Recibo Cli Nro. N - ...'
--   Recibos corregidos de fecha (tabla correccion_fecha_asientos): el vinculo pasa al asiento NUEVO.
--
-- Solo se vincula cuando hay EXACTAMENTE un asiento candidato. Si hay 0 o mas de 1 se informa y no se toca.
-- No modifica asientos; solo completa tres columnas de operaciones_contables.
--
-- USO (PostgreSQL / Supabase SQL Editor): PASO 1 (solo lectura) -> revisar. PASO 2 con dry_run := true
-- (ensayo, muestra resumen y deshace) -> con backup, dry_run := false.

-- ============================== PASO 1 (solo lectura) ==============================
-- Estado de cada recibo y que se haria con el:
WITH recibos AS (
  SELECT oc.id, oc.tipo_operacion, oc.numero_comprobante AS nro_recibo, oc.fecha AS fecha_recibo,
         oc.total, oc.asiento_numero, oc.asiento_anio_mes, oc.asiento_tipo,
         -- cuantas operaciones comparten este numero dentro de su misma serie (sponsors aparte)
         (SELECT COUNT(*) FROM public.operaciones_contables o2
           WHERE o2.numero_comprobante = oc.numero_comprobante
             AND (o2.tipo_operacion = 'COBRANZA_SPONSOR') = (oc.tipo_operacion = 'COBRANZA_SPONSOR')
             AND o2.tipo_operacion IN ('COBRANZA_SOCIO','COBRANZA_PROFESIONAL','COBRANZA_SPONSOR')) AS repetidos
  FROM public.operaciones_contables oc
  WHERE oc.tipo_operacion IN ('COBRANZA_SOCIO','COBRANZA_PROFESIONAL','COBRANZA_SPONSOR')
),
cand AS (
  SELECT r.id,
         COUNT(h.asiento)                           AS candidatos,
         MIN(h.asiento)                       AS asiento,
         MIN(h.anio_mes)                      AS anio_mes,
         MIN(h.fecha)                         AS fecha_asiento
  FROM recibos r
  LEFT JOIN public.asientos_header h
         ON h.tipo_asiento = 1
        AND ( (r.tipo_operacion <> 'COBRANZA_SPONSOR'
               AND (h.detalle = 'Recibo Nro. ' || r.nro_recibo
                    OR h.detalle LIKE 'Recibo Nro. ' || r.nro_recibo || ' - %'))
           OR (r.tipo_operacion = 'COBRANZA_SPONSOR'
               AND h.detalle LIKE 'Recibo Cli Nro. ' || r.nro_recibo || ' - %') )
  GROUP BY r.id
)
SELECT r.tipo_operacion, r.nro_recibo, r.fecha_recibo, r.total,
       r.asiento_numero AS vinculo_actual,
       c.candidatos, c.asiento AS asiento_candidato, c.anio_mes AS periodo_candidato,
       c.fecha_asiento,
       r.repetidos,
       CASE
         WHEN r.repetidos > 1 THEN 'NUMERO REPETIDO (' || r.repetidos || ' recibos, revisar a mano)'
         WHEN EXISTS (SELECT 1 FROM public.correccion_fecha_asientos x
                      WHERE x.nro_recibo = r.nro_recibo AND r.tipo_operacion = 'COBRANZA_SPONSOR')
              THEN 'CORREGIDO: vincular al asiento NUEVO'
         WHEN r.asiento_numero IS NOT NULL
              THEN 'YA VINCULADO'
         WHEN c.candidatos = 1 THEN 'VINCULAR'
         WHEN c.candidatos = 0 THEN 'SIN ASIENTO (no se toca)'
         ELSE 'AMBIGUO (' || c.candidatos || ' asientos, no se toca)'
       END AS accion
FROM recibos r
JOIN cand c ON c.id = r.id
ORDER BY accion, r.tipo_operacion, r.nro_recibo;

-- Resumen por accion (ejecutar aparte):
--   mismo WITH de arriba, terminando en:
--   SELECT accion, tipo_operacion, COUNT(*) FROM (<consulta de arriba>) t GROUP BY 1,2 ORDER BY 1,2;

-- ============================== PASO 2 ==============================
DO $$
DECLARE
  dry_run       BOOLEAN := true;     -- <<< true = ensayo (deshace todo). false = grabar.
  n_corregidos  INTEGER := 0;
  n_vinculados  INTEGER := 0;
  n_sin_asiento INTEGER;
  n_ambiguos    INTEGER;
BEGIN
  -- 1) Recibos de sponsors corregidos de fecha: vincular al asiento NUEVO
  UPDATE public.operaciones_contables oc
  SET asiento_numero   = x.nuevo_asiento,
      asiento_anio_mes = x.nuevo_anio_mes,
      asiento_tipo     = x.nuevo_tipo
  FROM public.correccion_fecha_asientos x
  WHERE oc.tipo_operacion = 'COBRANZA_SPONSOR'
    AND oc.numero_comprobante = x.nro_recibo
    AND (SELECT COUNT(*) FROM public.operaciones_contables o2
          WHERE o2.tipo_operacion = 'COBRANZA_SPONSOR'
            AND o2.numero_comprobante = oc.numero_comprobante) = 1
    AND (oc.asiento_numero IS DISTINCT FROM x.nuevo_asiento
         OR oc.asiento_anio_mes IS DISTINCT FROM x.nuevo_anio_mes
         OR oc.asiento_tipo IS DISTINCT FROM x.nuevo_tipo);
  GET DIAGNOSTICS n_corregidos = ROW_COUNT;

  -- 2) Resto: solo los que no tienen vinculo y tienen exactamente 1 asiento candidato
  WITH recibos AS (
    SELECT oc.id, oc.tipo_operacion, oc.numero_comprobante AS nro_recibo
    FROM public.operaciones_contables oc
    WHERE oc.tipo_operacion IN ('COBRANZA_SOCIO','COBRANZA_PROFESIONAL','COBRANZA_SPONSOR')
      AND oc.asiento_numero IS NULL
      -- numeros repetidos dentro de su serie: no se vinculan (revisar a mano)
      AND (SELECT COUNT(*) FROM public.operaciones_contables o2
            WHERE o2.numero_comprobante = oc.numero_comprobante
              AND (o2.tipo_operacion = 'COBRANZA_SPONSOR') = (oc.tipo_operacion = 'COBRANZA_SPONSOR')
              AND o2.tipo_operacion IN ('COBRANZA_SOCIO','COBRANZA_PROFESIONAL','COBRANZA_SPONSOR')) = 1
  ),
  cand AS (
    SELECT r.id, COUNT(h.asiento) AS candidatos,
           MIN(h.asiento) AS asiento, MIN(h.anio_mes) AS anio_mes
    FROM recibos r
    LEFT JOIN public.asientos_header h
           ON h.tipo_asiento = 1
          AND ( (r.tipo_operacion <> 'COBRANZA_SPONSOR'
                 AND (h.detalle = 'Recibo Nro. ' || r.nro_recibo
                      OR h.detalle LIKE 'Recibo Nro. ' || r.nro_recibo || ' - %'))
             OR (r.tipo_operacion = 'COBRANZA_SPONSOR'
                 AND h.detalle LIKE 'Recibo Cli Nro. ' || r.nro_recibo || ' - %') )
    GROUP BY r.id
  ),
  upd AS (
    UPDATE public.operaciones_contables oc
    SET asiento_numero = c.asiento, asiento_anio_mes = c.anio_mes, asiento_tipo = 1
    FROM cand c
    WHERE oc.id = c.id AND c.candidatos = 1
    RETURNING oc.id
  )
  SELECT COUNT(*) INTO n_vinculados FROM upd;

  SELECT COUNT(*) INTO n_sin_asiento
  FROM public.operaciones_contables
  WHERE tipo_operacion IN ('COBRANZA_SOCIO','COBRANZA_PROFESIONAL','COBRANZA_SPONSOR')
    AND asiento_numero IS NULL;

  -- (los ambiguos quedan sin vinculo; se cuentan aparte para informar)
  SELECT COUNT(*) INTO n_ambiguos FROM (
    SELECT oc.id
    FROM public.operaciones_contables oc
    JOIN public.asientos_header h
      ON h.tipo_asiento = 1
     AND ( (oc.tipo_operacion <> 'COBRANZA_SPONSOR'
            AND (h.detalle = 'Recibo Nro. ' || oc.numero_comprobante
                 OR h.detalle LIKE 'Recibo Nro. ' || oc.numero_comprobante || ' - %'))
        OR (oc.tipo_operacion = 'COBRANZA_SPONSOR'
            AND h.detalle LIKE 'Recibo Cli Nro. ' || oc.numero_comprobante || ' - %') )
    WHERE oc.tipo_operacion IN ('COBRANZA_SOCIO','COBRANZA_PROFESIONAL','COBRANZA_SPONSOR')
      AND oc.asiento_numero IS NULL
    GROUP BY oc.id HAVING COUNT(*) > 1) a;

  IF dry_run THEN
    RAISE EXCEPTION 'ENSAYO OK (nada grabado): % corregidos repuntados al asiento nuevo, % recibos vinculados por detalle, % quedan sin vinculo (de los cuales % ambiguos).',
      n_corregidos, n_vinculados, n_sin_asiento, n_ambiguos;
  END IF;

  RAISE NOTICE 'GRABADO: % corregidos, % vinculados, % sin vinculo (% ambiguos).',
    n_corregidos, n_vinculados, n_sin_asiento, n_ambiguos;
END $$;

-- Verificacion posterior (el SQL Editor no muestra RAISE NOTICE):
--   SELECT tipo_operacion,
--          COUNT(*) AS recibos,
--          COUNT(*) FILTER (WHERE asiento_numero IS NOT NULL) AS vinculados,
--          COUNT(*) FILTER (WHERE asiento_numero IS NULL)     AS sin_vinculo
--   FROM public.operaciones_contables
--   WHERE tipo_operacion IN ('COBRANZA_SOCIO','COBRANZA_PROFESIONAL','COBRANZA_SPONSOR')
--   GROUP BY tipo_operacion;
--
-- Integridad: vinculos que apuntan a un asiento inexistente (debe dar 0 filas):
--   SELECT oc.tipo_operacion, oc.numero_comprobante, oc.asiento_numero, oc.asiento_anio_mes
--   FROM public.operaciones_contables oc
--   LEFT JOIN public.asientos_header h
--          ON h.asiento = oc.asiento_numero AND h.anio_mes = oc.asiento_anio_mes
--         AND h.tipo_asiento = oc.asiento_tipo
--   WHERE oc.asiento_numero IS NOT NULL AND h.asiento IS NULL;
