-- AUDITORIA: recibos de sponsors (fecha de la cuenta corriente = la que cargo el usuario)
-- contra la contabilidad. SOLO LECTURA (SELECT). PostgreSQL / Supabase SQL Editor.
--
-- Recibo       : ven_cli_header (tipo_comprobante = 0). Fecha e importe del recibo.
-- Contabilidad : efecto NETO de los asientos del recibo, en importes (suma del DEBE de cada asiento):
--     ORIGINAL  (+)  asiento tipo Ingreso con detalle 'Recibo Cli Nro. N - ...'
--     REVERSION (-)  asiento de reversion de la correccion de fechas (tabla correccion_fecha_asientos)
--     NUEVO     (+)  asiento nuevo de la correccion de fechas
--   Un recibo bien contabilizado tiene neto = importe del recibo, TODO en el periodo (anio_mes) del recibo.
--
-- Ejecutar cada consulta POR SEPARADO (el editor muestra solo el resultado de la ultima ejecutada).
-- Para ver mas de 100 filas: cambiar "Limit 100 rows" por "No limit" o usar Download CSV.
--
-- Las consultas A, B y C repiten el mismo bloque WITH a proposito (no se crea ninguna vista).

-- ======================= 0) CONTROL DE FUENTES =======================
-- recibos_cuenta_corriente deberia coincidir con operaciones_sponsor. Si no coinciden, avisar:
-- el tipo 0 de ven_cli_header podria no ser exclusivamente recibos.
SELECT
  (SELECT COUNT(*) FROM public.ven_cli_header WHERE tipo_comprobante = 0)                          AS recibos_cuenta_corriente,
  (SELECT COUNT(*) FROM public.operaciones_contables WHERE tipo_operacion = 'COBRANZA_SPONSOR')    AS operaciones_sponsor,
  (SELECT COUNT(*) FROM public.asientos_header
    WHERE tipo_asiento = 1 AND detalle LIKE 'Recibo Cli Nro. %')                                   AS asientos_ingreso_sponsor,
  (SELECT COUNT(*) FROM public.correccion_fecha_asientos)                                          AS recibos_corregidos;


-- ======================= A) DETALLE POR RECIBO =======================
-- Una fila por recibo del rango de fechas. Ordenado: primero lo que esta mal.
-- Cambiar el rango para auditar otro periodo (por defecto: ejercicio 02/08/2025 - 01/08/2026).
WITH params AS (
  SELECT DATE '2025-08-02' AS desde, DATE '2026-08-01' AS hasta
),
tot AS (
  SELECT asiento, anio_mes, tipo_asiento, COALESCE(SUM(debe), 0) AS total
  FROM public.asientos_items
  GROUP BY asiento, anio_mes, tipo_asiento
),
movs AS (
  SELECT substring(h.detalle FROM 'Recibo Cli Nro\. ([0-9]+)')::INT AS nro,
         'ORIGINAL'::TEXT AS clase, h.asiento, h.anio_mes, h.tipo_asiento, h.fecha, 1 AS signo,
         COALESCE(t.total, 0) AS total
  FROM public.asientos_header h
  LEFT JOIN tot t ON t.asiento = h.asiento AND t.anio_mes = h.anio_mes AND t.tipo_asiento = h.tipo_asiento
  WHERE h.tipo_asiento = 1 AND h.detalle LIKE 'Recibo Cli Nro. %'
  UNION ALL
  SELECT c.nro_recibo, 'REVERSION', h.asiento, h.anio_mes, h.tipo_asiento, h.fecha, -1, COALESCE(t.total, 0)
  FROM public.correccion_fecha_asientos c
  JOIN public.asientos_header h
    ON h.asiento = c.rev_asiento AND h.anio_mes = c.rev_anio_mes AND h.tipo_asiento = c.rev_tipo
  LEFT JOIN tot t ON t.asiento = h.asiento AND t.anio_mes = h.anio_mes AND t.tipo_asiento = h.tipo_asiento
  UNION ALL
  SELECT c.nro_recibo, 'NUEVO', h.asiento, h.anio_mes, h.tipo_asiento, h.fecha, 1, COALESCE(t.total, 0)
  FROM public.correccion_fecha_asientos c
  JOIN public.asientos_header h
    ON h.asiento = c.nuevo_asiento AND h.anio_mes = c.nuevo_anio_mes AND h.tipo_asiento = c.nuevo_tipo
  LEFT JOIN tot t ON t.asiento = h.asiento AND t.anio_mes = h.anio_mes AND t.tipo_asiento = h.tipo_asiento
),
rec AS (
  SELECT h.comprobante AS nro, h.fecha, h.cliente, h.total_importe AS importe,
         EXTRACT(YEAR FROM h.fecha)::INT * 100 + EXTRACT(MONTH FROM h.fecha)::INT AS periodo,
         COUNT(*) OVER (PARTITION BY h.comprobante) AS veces
  FROM public.ven_cli_header h, params p
  WHERE h.tipo_comprobante = 0 AND h.fecha BETWEEN p.desde AND p.hasta
)
SELECT
  r.nro                                                                   AS nro_recibo,
  (SELECT c.razon_social FROM public.clientes c WHERE c.codigo = r.cliente LIMIT 1) AS sponsor,
  r.fecha                                                                 AS fecha_recibo_cc,
  (SELECT MIN(o.fecha) FROM public.operaciones_contables o
    WHERE o.tipo_operacion = 'COBRANZA_SPONSOR' AND o.numero_comprobante = r.nro) AS fecha_operacion,
  r.importe                                                               AS importe_recibo,
  r.periodo                                                               AS periodo_recibo,
  COALESCE(SUM(m.signo * m.total) FILTER (WHERE m.anio_mes =  r.periodo), 0) AS contab_en_periodo_recibo,
  COALESCE(SUM(m.signo * m.total) FILTER (WHERE m.anio_mes <> r.periodo), 0) AS contab_en_otros_periodos,
  COALESCE(SUM(m.signo * m.total), 0)                                     AS contab_neto_total,
  COALESCE(SUM(m.signo * m.total), 0) - r.importe                         AS diferencia,
  COUNT(m.nro) FILTER (WHERE m.clase = 'ORIGINAL')                        AS cant_asientos_ingreso,
  COALESCE(MAX(m.fecha) FILTER (WHERE m.clase = 'NUEVO'),
           MAX(m.fecha) FILTER (WHERE m.clase = 'ORIGINAL'))              AS fecha_asiento_vigente,
  string_agg(m.clase || ' ' || m.asiento || '/' || m.anio_mes || ' (' || m.fecha || ')',
             ' ; ' ORDER BY m.fecha, m.asiento)                           AS asientos,
  CASE
    WHEN r.veces > 1                                    THEN '0 NUMERO DE RECIBO REPETIDO'
    WHEN COUNT(m.nro) = 0                               THEN '1 SIN ASIENTO'
    WHEN ABS(COALESCE(SUM(m.signo * m.total), 0) - r.importe) > 0.01
                                                        THEN '2 IMPORTE CONTABILIZADO DISTINTO AL RECIBO'
    WHEN ABS(COALESCE(SUM(m.signo * m.total) FILTER (WHERE m.anio_mes <> r.periodo), 0)) > 0.01
                                                        THEN '3 PERIODO DISTINTO'
    WHEN COALESCE(MAX(m.fecha) FILTER (WHERE m.clase = 'NUEVO'),
                  MAX(m.fecha) FILTER (WHERE m.clase = 'ORIGINAL')) <> r.fecha
                                                        THEN '4 MISMO PERIODO, DISTINTO DIA'
    ELSE '5 OK'
  END                                                                     AS situacion
FROM rec r
LEFT JOIN movs m ON m.nro = r.nro
GROUP BY r.nro, r.fecha, r.cliente, r.importe, r.periodo, r.veces
ORDER BY situacion, r.fecha, r.nro;


-- ======================= B) CONCILIACION POR PERIODO =======================
-- Total de recibos (cuenta corriente) vs total contabilizado neto, por mes (anio_mes).
-- Incluye TODOS los asientos de sponsors (aun los de recibos fuera del rango o inexistentes).
-- La columna diferencia = recibos - contabilidad. Distinta de cero = ahi esta el problema.
WITH tot AS (
  SELECT asiento, anio_mes, tipo_asiento, COALESCE(SUM(debe), 0) AS total
  FROM public.asientos_items
  GROUP BY asiento, anio_mes, tipo_asiento
),
movs AS (
  SELECT substring(h.detalle FROM 'Recibo Cli Nro\. ([0-9]+)')::INT AS nro, 1 AS signo,
         h.anio_mes, COALESCE(t.total, 0) AS total
  FROM public.asientos_header h
  LEFT JOIN tot t ON t.asiento = h.asiento AND t.anio_mes = h.anio_mes AND t.tipo_asiento = h.tipo_asiento
  WHERE h.tipo_asiento = 1 AND h.detalle LIKE 'Recibo Cli Nro. %'
  UNION ALL
  SELECT c.nro_recibo, -1, h.anio_mes, COALESCE(t.total, 0)
  FROM public.correccion_fecha_asientos c
  JOIN public.asientos_header h
    ON h.asiento = c.rev_asiento AND h.anio_mes = c.rev_anio_mes AND h.tipo_asiento = c.rev_tipo
  LEFT JOIN tot t ON t.asiento = h.asiento AND t.anio_mes = h.anio_mes AND t.tipo_asiento = h.tipo_asiento
  UNION ALL
  SELECT c.nro_recibo, 1, h.anio_mes, COALESCE(t.total, 0)
  FROM public.correccion_fecha_asientos c
  JOIN public.asientos_header h
    ON h.asiento = c.nuevo_asiento AND h.anio_mes = c.nuevo_anio_mes AND h.tipo_asiento = c.nuevo_tipo
  LEFT JOIN tot t ON t.asiento = h.asiento AND t.anio_mes = h.anio_mes AND t.tipo_asiento = h.tipo_asiento
),
a AS (
  SELECT EXTRACT(YEAR FROM h.fecha)::INT * 100 + EXTRACT(MONTH FROM h.fecha)::INT AS periodo,
         COUNT(*) AS cant_recibos, SUM(h.total_importe) AS importe_recibos
  FROM public.ven_cli_header h
  WHERE h.tipo_comprobante = 0
  GROUP BY 1
),
b AS (
  SELECT anio_mes AS periodo, SUM(signo * total) AS contab_neta
  FROM movs
  GROUP BY anio_mes
)
SELECT COALESCE(a.periodo, b.periodo)                                   AS periodo,
       COALESCE(a.cant_recibos, 0)                                      AS cant_recibos,
       COALESCE(a.importe_recibos, 0)                                   AS importe_recibos_cc,
       COALESCE(b.contab_neta, 0)                                       AS contabilidad_neta,
       COALESCE(a.importe_recibos, 0) - COALESCE(b.contab_neta, 0)      AS diferencia
FROM a
FULL JOIN b ON b.periodo = a.periodo
ORDER BY 1;


-- ======================= C) ASIENTOS DE SPONSORS SIN RECIBO =======================
-- Asientos 'Recibo Cli Nro. N' cuyo recibo N no existe en la cuenta corriente (ven_cli_header tipo 0).
-- Son ingresos contabilizados sin respaldo (o recibos borrados): deben ser 0 filas.
SELECT h.asiento, h.anio_mes, h.fecha, h.detalle,
       (SELECT COALESCE(SUM(i.debe), 0) FROM public.asientos_items i
         WHERE i.asiento = h.asiento AND i.anio_mes = h.anio_mes AND i.tipo_asiento = h.tipo_asiento) AS total
FROM public.asientos_header h
WHERE h.tipo_asiento = 1
  AND h.detalle LIKE 'Recibo Cli Nro. %'
  AND NOT EXISTS (
    SELECT 1 FROM public.ven_cli_header v
    WHERE v.tipo_comprobante = 0
      AND v.comprobante = substring(h.detalle FROM 'Recibo Cli Nro\. ([0-9]+)')::INT)
ORDER BY h.fecha, h.asiento;
