-- =============================================================================
-- DIAGNÓSTICO (solo lectura): asientos de facturas y de pagos de UN proveedor.
-- Cambiar el código de proveedor y el período en la CTE "params".
--
-- Los asientos no guardan el proveedor: se vinculan por el texto del detalle
--   Compras (tipo_asiento 3): "<tipo> <nro> - <razon_social> - <razon_social>"
--   Pagos   (tipo_asiento 2): "OP <nro> - <razon_social>"
-- =============================================================================

-- A) Comprobantes cargados al proveedor (facturas, NC y órdenes de pago)
WITH params AS (
  SELECT 9553 AS prov, DATE '2025-08-02' AS desde, DATE '2026-08-01' AS hasta
)
SELECT h.id_transaccion, h.comprobante, h.fecha, h.anio_mes,
       btrim(t.descripcion) AS tipo, t.signo,
       btrim(h.nro_comprobante) AS nro, h.total_importe, h.cancelado
FROM comp_prov_header h
JOIN tip_comp_mod_header t ON t.codigo = h.tipo_comprobante
CROSS JOIN params p
WHERE h.proveedor = p.prov
  AND h.fecha::date BETWEEN p.desde AND p.hasta
ORDER BY h.fecha, h.id_transaccion;


-- B) Asientos de COMPRAS (tipo 3) y de PAGOS (tipo 2) de ese proveedor,
--    con sus items. cuenta_id = CUENTA_PROVEEDORES marcada con *.
WITH params AS (
  SELECT 9553 AS prov, DATE '2025-08-02' AS desde, DATE '2026-08-01' AS hasta
),
prov AS (
  SELECT btrim(pr.razon_social) AS nombre
  FROM proveedores pr, params p WHERE pr.codigo = p.prov
),
cta AS (
  SELECT valor::int AS cuenta_id FROM parametros_contables WHERE clave = 'CUENTA_PROVEEDORES'
)
SELECT a.fecha, a.anio_mes, a.tipo_asiento,
       CASE a.tipo_asiento WHEN 3 THEN 'COMPRA' WHEN 2 THEN 'PAGO' ELSE a.tipo_asiento::text END AS origen,
       a.asiento, a.detalle,
       i.item, i.cuenta_id,
       CASE WHEN i.cuenta_id = (SELECT cuenta_id FROM cta) THEN '*' ELSE '' END AS es_prov,
       i.debe, i.haber
FROM asientos_header a
JOIN asientos_items i
  ON i.asiento = a.asiento AND i.anio_mes = a.anio_mes AND i.tipo_asiento = a.tipo_asiento
CROSS JOIN params p
CROSS JOIN prov pv
WHERE a.tipo_asiento IN (2, 3)
  AND a.fecha::date BETWEEN p.desde AND p.hasta
  AND a.detalle ILIKE '%' || pv.nombre || '%'
ORDER BY a.fecha, a.tipo_asiento, a.asiento, i.item;


-- C) Resumen: cuánto asentó cada tipo contra la cuenta de proveedores
WITH params AS (
  SELECT 9553 AS prov, DATE '2025-08-02' AS desde, DATE '2026-08-01' AS hasta
),
prov AS (
  SELECT btrim(pr.razon_social) AS nombre
  FROM proveedores pr, params p WHERE pr.codigo = p.prov
),
cta AS (
  SELECT valor::int AS cuenta_id FROM parametros_contables WHERE clave = 'CUENTA_PROVEEDORES'
)
SELECT CASE a.tipo_asiento WHEN 3 THEN 'COMPRAS' WHEN 2 THEN 'PAGOS' END AS origen,
       COUNT(DISTINCT a.asiento) AS asientos,
       SUM(i.debe) AS debe_prov, SUM(i.haber) AS haber_prov
FROM asientos_header a
JOIN asientos_items i
  ON i.asiento = a.asiento AND i.anio_mes = a.anio_mes AND i.tipo_asiento = a.tipo_asiento
CROSS JOIN params p
CROSS JOIN prov pv
WHERE a.tipo_asiento IN (2, 3)
  AND a.fecha::date BETWEEN p.desde AND p.hasta
  AND a.detalle ILIKE '%' || pv.nombre || '%'
  AND i.cuenta_id = (SELECT cuenta_id FROM cta)
GROUP BY a.tipo_asiento;
