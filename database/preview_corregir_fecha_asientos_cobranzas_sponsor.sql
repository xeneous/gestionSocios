-- VISTA PREVIA (solo lectura, no graba nada) de lo que generaria
-- corregir_fecha_asientos_cobranzas_sponsor.sql.
--
-- Una fila por linea de cada asiento que se crearia (reversion y nuevo), con el numero de asiento
-- que tomaria. La numeracion replica la del script: por periodo, tipo 0 (Diario), y por cada recibo
-- primero la reversion y despues el nuevo, en orden fecha_recibo / nro_recibo.
-- Exportar el resultado a CSV desde el SQL Editor de Supabase.

WITH base AS (
  SELECT
    oc.numero_comprobante AS nro_recibo,
    c.razon_social        AS cliente,
    oc.fecha              AS fecha_recibo,
    a.asiento, a.anio_mes, a.tipo_asiento,
    a.fecha               AS fecha_asiento,
    a.detalle,
    ROW_NUMBER() OVER (ORDER BY oc.fecha, oc.numero_comprobante) AS orden
  FROM public.operaciones_contables oc
  LEFT JOIN public.clientes c ON c.codigo = oc.entidad_id
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
    -- Solo dentro del ejercicio 02/08/2025 - 01/08/2026 (igual que el script)
    AND a.fecha  BETWEEN DATE '2025-08-02' AND DATE '2026-08-01'
    AND oc.fecha BETWEEN DATE '2025-08-02' AND DATE '2026-08-01'
    AND NOT EXISTS (
      SELECT 1 FROM public.correccion_fecha_asientos x
      WHERE x.orig_asiento = a.asiento AND x.orig_anio_mes = a.anio_mes AND x.orig_tipo = a.tipo_asiento)
),
eventos AS (
  SELECT b.*, 1 AS evento, 'REVERSION'::text AS clase,
         b.fecha_asiento AS fecha_nueva,
         EXTRACT(YEAR FROM b.fecha_asiento)::INT * 100 + EXTRACT(MONTH FROM b.fecha_asiento)::INT AS periodo_nuevo
  FROM base b
  UNION ALL
  SELECT b.*, 2, 'NUEVO',
         b.fecha_recibo,
         EXTRACT(YEAR FROM b.fecha_recibo)::INT * 100 + EXTRACT(MONTH FROM b.fecha_recibo)::INT
  FROM base b
),
numerados AS (
  SELECT e.*,
         COALESCE((SELECT MAX(h.asiento) FROM public.asientos_header h
                   WHERE h.anio_mes = e.periodo_nuevo AND h.tipo_asiento = 0), 0)
         + ROW_NUMBER() OVER (PARTITION BY e.periodo_nuevo ORDER BY e.orden, e.evento) AS asiento_nuevo
  FROM eventos e
)
SELECT
  n.nro_recibo,
  n.cliente,
  n.clase                                     AS que_se_genera,
  0                                           AS tipo_asiento_nuevo,
  n.periodo_nuevo                             AS periodo,
  n.asiento_nuevo                             AS nro_asiento_nuevo,
  n.fecha_nueva                               AS fecha_nueva,
  i.item,
  i.cuenta_id                                 AS cuenta,
  cu.descripcion                              AS nombre_cuenta,
  CASE WHEN n.clase = 'REVERSION' THEN i.haber ELSE i.debe  END AS debe,
  CASE WHEN n.clase = 'REVERSION' THEN i.debe  ELSE i.haber END AS haber,
  i.observacion,
  LEFT(CASE WHEN n.clase = 'REVERSION'
            THEN 'REVERSION Corrige Fecha - '
            ELSE 'Corrige Fecha - ' END || COALESCE(n.detalle, ''), 255) AS detalle_nuevo,
  n.asiento                                   AS asiento_original,
  n.fecha_asiento                             AS fecha_original,
  n.fecha_recibo                              AS fecha_recibo_usuario
FROM numerados n
JOIN public.asientos_items i
  ON i.asiento      = n.asiento
 AND i.anio_mes     = n.anio_mes
 AND i.tipo_asiento = n.tipo_asiento
LEFT JOIN public.cuentas cu ON cu.cuenta = i.cuenta_id
ORDER BY n.orden, n.evento, i.item;
