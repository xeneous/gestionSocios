-- Detalle (lineas) de los asientos de cobranzas de sponsors con fecha distinta a la del recibo,
-- con numero y nombre de cuenta contable. Solo lectura (SELECT). PostgreSQL / Supabase.
--
-- Una fila por linea de asiento. Exportar el resultado a CSV desde el SQL Editor.
-- Ejercicio considerado: 02/08/2025 al 01/08/2026.
--
-- NOTA: la app guarda en asientos_items.cuenta_id el NUMERO de cuenta (no el id de la tabla cuentas),
-- por eso el join es cuentas.cuenta = asientos_items.cuenta_id.

WITH recibos AS (
  SELECT
    oc.numero_comprobante AS nro_recibo,
    c.razon_social        AS cliente,
    oc.total              AS importe_recibo,
    oc.fecha              AS fecha_recibo,
    a.asiento, a.anio_mes, a.tipo_asiento,
    a.fecha               AS fecha_asiento,
    a.detalle             AS detalle_asiento,
    CASE WHEN oc.asiento_numero IS NOT NULL THEN 'POR VINCULO' ELSE 'POR DETALLE' END AS como_se_encontro
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
)
SELECT
  r.nro_recibo,
  r.cliente,
  r.importe_recibo,
  r.fecha_recibo                              AS fecha_recibo_usuario,
  r.fecha_asiento                             AS fecha_asiento_actual,
  (r.fecha_asiento - r.fecha_recibo)          AS dias_diferencia,
  r.tipo_asiento,
  r.anio_mes                                  AS periodo_asiento,
  r.asiento                                   AS nro_asiento,
  i.item,
  i.cuenta_id                                 AS cuenta,
  cu.descripcion                              AS nombre_cuenta,
  i.debe,
  i.haber,
  i.observacion,
  r.detalle_asiento,
  r.como_se_encontro
FROM recibos r
JOIN public.asientos_items i
  ON i.asiento      = r.asiento
 AND i.anio_mes     = r.anio_mes
 AND i.tipo_asiento = r.tipo_asiento
LEFT JOIN public.cuentas cu
  ON cu.cuenta = i.cuenta_id
ORDER BY r.fecha_recibo, r.nro_recibo, r.asiento, i.item;
