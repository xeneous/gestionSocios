-- AUDITORIA: aplicaciones de recibos de sponsors y recibos anulados/eliminados.
-- SOLO LECTURA (SELECT). PostgreSQL / Supabase SQL Editor.
--
-- Como funciona hoy (generarRecibo, cobranzas_clientes_service.dart):
--   * El recibo es una fila de ven_cli_header con tipo_comprobante = 0 y cancelado = 0 SIEMPRE.
--   * Cada factura que paga el recibo suma el monto en su campo ven_cli_header.cancelado
--     y se registra una fila en notas_imputacion (tipo_operacion = 2):
--       id_operacion   = id_transaccion del RECIBO
--       id_transaccion = id_transaccion de la FACTURA pagada
--       importe        = monto aplicado
--   * Por eso la ficha (suma total_importe - cancelado de todo) cuenta cada recibo como
--     deuda adicional: el recibo nunca figura "aplicado" en su propio cancelado.
--   * Recibos viejos (migrados) pueden no tener filas en notas_imputacion.
--
-- Ejecutar cada consulta POR SEPARADO. Para ver mas de 100 filas elegir "No limit".
-- Para un solo sponsor: reemplazar  NULL::INT  por el codigo de cliente en la CTE params.

-- ======================= 1) RESUMEN POR SPONSOR =======================
-- saldo_ficha_hoy      = lo que muestra hoy el total de arriba de la ficha (sin filtro de saldo)
-- saldo_contable       = facturas/ND (+) menos recibos/NC (-), por importe total
-- recibos_sin_aplicar  = parte de los recibos que NO figura aplicada en notas_imputacion
WITH params AS (SELECT NULL::INT AS cliente),
imp AS (
  SELECT i.id_operacion AS id_recibo, SUM(i.importe) AS aplicado
  FROM public.notas_imputacion i
  WHERE i.tipo_operacion = 2
  GROUP BY i.id_operacion
)
SELECT
  h.cliente,
  (SELECT c.razon_social FROM public.clientes c WHERE c.codigo = h.cliente LIMIT 1) AS sponsor,
  COUNT(*) FILTER (WHERE h.tipo_comprobante = 0)                                    AS cant_recibos,
  SUM(h.total_importe) FILTER (WHERE COALESCE(t.multiplicador, 1) =  1)             AS facturado,
  SUM(h.total_importe) FILTER (WHERE COALESCE(t.multiplicador, 1) = -1)             AS recibos_y_nc,
  SUM(h.total_importe * COALESCE(t.multiplicador, 1))                               AS saldo_contable,
  SUM(h.total_importe - COALESCE(h.cancelado, 0))                                   AS saldo_ficha_hoy,
  SUM(h.total_importe - COALESCE(h.cancelado, 0))
    - SUM(h.total_importe * COALESCE(t.multiplicador, 1))                           AS error_ficha,
  COALESCE(SUM(h.total_importe - COALESCE(imp.aplicado, 0)) FILTER (WHERE h.tipo_comprobante = 0), 0)
                                                                                    AS recibos_sin_aplicar
FROM public.ven_cli_header h
LEFT JOIN public.tip_vent_mod_header t ON t.codigo = h.tipo_comprobante
LEFT JOIN imp ON imp.id_recibo = h.id_transaccion AND h.tipo_comprobante = 0
CROSS JOIN params p
WHERE p.cliente IS NULL OR h.cliente = p.cliente
GROUP BY h.cliente
HAVING ABS(SUM(h.total_importe - COALESCE(h.cancelado, 0))
         - SUM(h.total_importe * COALESCE(t.multiplicador, 1))) > 0.01
    OR ABS(COALESCE(SUM(h.total_importe - COALESCE(imp.aplicado, 0)) FILTER (WHERE h.tipo_comprobante = 0), 0)) > 0.01
ORDER BY ABS(SUM(h.total_importe - COALESCE(h.cancelado, 0))
           - SUM(h.total_importe * COALESCE(t.multiplicador, 1))) DESC;


-- ======================= 2) LISTADO DE APLICACIONES DE RECIBOS =======================
-- Una fila por (recibo -> factura) registrada en notas_imputacion.
WITH params AS (SELECT NULL::INT AS cliente)
SELECT
  r.cliente,
  (SELECT c.razon_social FROM public.clientes c WHERE c.codigo = r.cliente LIMIT 1) AS sponsor,
  r.comprobante     AS nro_recibo,
  r.fecha           AS fecha_recibo,
  r.total_importe   AS importe_recibo,
  f.nro_comprobante AS factura,
  f.tipo_comprobante AS tipo_factura,
  f.fecha           AS fecha_factura,
  f.total_importe   AS importe_factura,
  i.importe         AS importe_aplicado,
  f.cancelado       AS cancelado_factura,
  i.observacion
FROM public.notas_imputacion i
JOIN public.ven_cli_header r ON r.id_transaccion = i.id_operacion AND r.tipo_comprobante = 0
LEFT JOIN public.ven_cli_header f ON f.id_transaccion = i.id_transaccion
CROSS JOIN params p
WHERE i.tipo_operacion = 2
  AND (p.cliente IS NULL OR r.cliente = p.cliente)
ORDER BY r.cliente, r.fecha, r.comprobante, f.fecha;


-- ======================= 3) RECIBOS SIN APLICAR O APLICADOS A MEDIAS =======================
-- Son los que la ficha no puede mostrar como aplicados. Cada fila es un recibo.
WITH params AS (SELECT NULL::INT AS cliente),
imp AS (
  SELECT i.id_operacion AS id_recibo, SUM(i.importe) AS aplicado, COUNT(*) AS cant_facturas
  FROM public.notas_imputacion i
  WHERE i.tipo_operacion = 2
  GROUP BY i.id_operacion
)
SELECT
  r.cliente,
  (SELECT c.razon_social FROM public.clientes c WHERE c.codigo = r.cliente LIMIT 1) AS sponsor,
  r.comprobante   AS nro_recibo,
  r.fecha,
  r.total_importe AS importe_recibo,
  COALESCE(imp.aplicado, 0)                  AS importe_aplicado,
  r.total_importe - COALESCE(imp.aplicado, 0) AS sin_aplicar,
  COALESCE(imp.cant_facturas, 0)             AS cant_facturas,
  CASE WHEN imp.id_recibo IS NULL THEN 'SIN NINGUNA APLICACION'
       WHEN imp.aplicado > r.total_importe + 0.01 THEN 'APLICADO DE MAS'
       ELSE 'APLICADO PARCIAL' END           AS situacion
FROM public.ven_cli_header r
LEFT JOIN imp ON imp.id_recibo = r.id_transaccion
CROSS JOIN params p
WHERE r.tipo_comprobante = 0
  AND (p.cliente IS NULL OR r.cliente = p.cliente)
  AND ABS(r.total_importe - COALESCE(imp.aplicado, 0)) > 0.01
ORDER BY r.cliente, r.fecha, r.comprobante;


-- ======================= 4) FACTURAS: cancelado vs APLICACIONES =======================
-- ven_cli_header.cancelado deberia ser igual a la suma de notas_imputacion de esa factura.
-- Distinto = el cancelado quedo desfasado (aplicacion borrada, recibo eliminado a mano, etc.).
WITH params AS (SELECT NULL::INT AS cliente),
imp AS (
  SELECT i.id_transaccion AS id_factura, SUM(i.importe) AS aplicado
  FROM public.notas_imputacion i
  WHERE i.tipo_operacion = 2
  GROUP BY i.id_transaccion
)
SELECT
  f.cliente,
  (SELECT c.razon_social FROM public.clientes c WHERE c.codigo = f.cliente LIMIT 1) AS sponsor,
  f.nro_comprobante AS factura,
  f.fecha,
  f.total_importe,
  COALESCE(f.cancelado, 0)   AS cancelado,
  COALESCE(imp.aplicado, 0)  AS suma_aplicaciones,
  COALESCE(f.cancelado, 0) - COALESCE(imp.aplicado, 0) AS diferencia
FROM public.ven_cli_header f
LEFT JOIN public.tip_vent_mod_header t ON t.codigo = f.tipo_comprobante
LEFT JOIN imp ON imp.id_factura = f.id_transaccion
CROSS JOIN params p
WHERE f.tipo_comprobante <> 0
  AND COALESCE(t.multiplicador, 1) = 1
  AND (p.cliente IS NULL OR f.cliente = p.cliente)
  AND ABS(COALESCE(f.cancelado, 0) - COALESCE(imp.aplicado, 0)) > 0.01
ORDER BY f.cliente, f.fecha;


-- ======================= 5) APLICACIONES HUERFANAS =======================
-- Filas de notas_imputacion (tipo 2) cuyo recibo o factura ya no existe.
-- Tipico de un recibo eliminado a mano sin revertir sus aplicaciones. Deben ser 0 filas.
SELECT i.*,
       (r.id_transaccion IS NULL) AS falta_recibo,
       (f.id_transaccion IS NULL) AS falta_factura
FROM public.notas_imputacion i
LEFT JOIN public.ven_cli_header r ON r.id_transaccion = i.id_operacion AND r.tipo_comprobante = 0
LEFT JOIN public.ven_cli_header f ON f.id_transaccion = i.id_transaccion
WHERE i.tipo_operacion = 2
  AND (r.id_transaccion IS NULL OR f.id_transaccion IS NULL)
ORDER BY i.id_operacion;


-- ======================= 6) RECIBOS ANULADOS / COMPROBANTES ELIMINADOS =======================
-- 6a) recibos_anulados: la baja guiada (anular_recibo_cobranza) hoy solo contempla socios y
--     profesionales; si aparecen sponsors aca es de otra via.
SELECT * FROM public.recibos_anulados ORDER BY fecha_anulacion DESC;

-- 6b) comprobantes_eliminados de sponsors (facturas dadas de baja; guarda snapshot completo).
SELECT id, id_transaccion_orig, nro_comprobante, entidad_id AS cliente, fecha_comprobante,
       total_importe, motivo, fecha_eliminacion
FROM public.comprobantes_eliminados
WHERE modulo = 'SPONSOR'
ORDER BY fecha_eliminacion DESC;

-- 6c) Numeros de recibo faltantes en la secuencia (posibles recibos borrados sin auditoria).
SELECT g.n AS nro_recibo_faltante
FROM generate_series(
       (SELECT MIN(comprobante) FROM public.ven_cli_header WHERE tipo_comprobante = 0),
       (SELECT MAX(comprobante) FROM public.ven_cli_header WHERE tipo_comprobante = 0)) AS g(n)
WHERE NOT EXISTS (SELECT 1 FROM public.ven_cli_header h
                  WHERE h.tipo_comprobante = 0 AND h.comprobante = g.n)
ORDER BY 1;

-- 6d) Cobranzas de sponsor registradas en operaciones_contables sin recibo en ven_cli_header
--     (el recibo se borro pero quedo la operacion contable). Deben ser 0 filas.
SELECT o.id, o.numero_comprobante AS nro_recibo, o.fecha, o.entidad_id AS cliente, o.total
FROM public.operaciones_contables o
WHERE o.tipo_operacion = 'COBRANZA_SPONSOR'
  AND NOT EXISTS (SELECT 1 FROM public.ven_cli_header h
                  WHERE h.tipo_comprobante = 0 AND h.comprobante = o.numero_comprobante)
ORDER BY o.fecha;
