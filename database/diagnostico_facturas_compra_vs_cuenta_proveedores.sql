-- =============================================================================
-- DIAGNÓSTICO (solo lectura): facturas de compra cargadas en proveedores que
-- NO figuran en la cuenta contable de proveedores ("Proveedores Varios").
--
-- Cómo se contabiliza una compra (comprobantes_prov_service._generarAsientoCompra):
--   - signo = 2 (factura): DEBE items / HABER CUENTA_PROVEEDORES
--   - signo = 1 (NC):      DEBE CUENTA_PROVEEDORES / HABER items
--   - tipo_asiento = 3 (compras)
--   - asientos_header NO guarda el id del comprobante; el vínculo es por
--     fecha + detalle ("<tipo> <nro_comprobante> - <proveedor>").
--
-- Ejecutar cada bloque por separado (Supabase SQL Editor a veces da timeout).
-- No modifica nada.
-- =============================================================================

-- 0) Qué cuenta es "Proveedores Varios" (parámetro CUENTA_PROVEEDORES)
SELECT clave, valor FROM parametros_contables WHERE clave = 'CUENTA_PROVEEDORES';


-- 1) Facturas/NC SIN asiento que impacte la cuenta de proveedores
--    (match: mismo período, tipo 3, misma fecha, detalle contiene el nro de comprobante,
--     y el asiento tiene al menos un item en CUENTA_PROVEEDORES)
WITH cta AS (
  SELECT valor::int AS cuenta_id
  FROM parametros_contables WHERE clave = 'CUENTA_PROVEEDORES'
)
SELECT
  h.id_transaccion,
  h.fecha,
  h.proveedor,
  p.razon_social,
  t.descripcion AS tipo,
  t.signo,
  h.nro_comprobante,
  h.total_importe
FROM comp_prov_header h
JOIN tip_comp_mod_header t ON t.codigo = h.tipo_comprobante
LEFT JOIN proveedores p     ON p.codigo = h.proveedor
WHERE t.signo IN (1, 2)
  AND NOT EXISTS (
    SELECT 1
    FROM asientos_header a
    JOIN asientos_items i
      ON i.asiento = a.asiento AND i.anio_mes = a.anio_mes AND i.tipo_asiento = a.tipo_asiento
    WHERE a.tipo_asiento = 3
      AND a.anio_mes = h.anio_mes
      AND a.fecha::date = h.fecha::date
      AND a.detalle ILIKE '%' || btrim(h.nro_comprobante) || '%'
      AND i.cuenta_id = (SELECT cuenta_id FROM cta)
  )
ORDER BY h.fecha, h.id_transaccion;


-- 2) Control por período: total facturado vs. total en la cuenta de proveedores
--    (signo 2 suma, signo 1 resta; la diferencia debería ser 0)
WITH cta AS (
  SELECT valor::int AS cuenta_id
  FROM parametros_contables WHERE clave = 'CUENTA_PROVEEDORES'
),
fact AS (
  SELECT h.anio_mes,
         SUM(CASE WHEN t.signo = 2 THEN h.total_importe ELSE -h.total_importe END) AS facturado
  FROM comp_prov_header h
  JOIN tip_comp_mod_header t ON t.codigo = h.tipo_comprobante
  WHERE t.signo IN (1, 2)
  GROUP BY h.anio_mes
),
cont AS (
  SELECT i.anio_mes, SUM(i.haber - i.debe) AS contabilizado
  FROM asientos_items i
  WHERE i.tipo_asiento = 3
    AND i.cuenta_id = (SELECT cuenta_id FROM cta)
  GROUP BY i.anio_mes
)
SELECT COALESCE(f.anio_mes, c.anio_mes) AS anio_mes,
       COALESCE(f.facturado, 0)     AS facturado,
       COALESCE(c.contabilizado, 0) AS contabilizado,
       COALESCE(f.facturado, 0) - COALESCE(c.contabilizado, 0) AS diferencia
FROM fact f
FULL JOIN cont c ON c.anio_mes = f.anio_mes
WHERE ABS(COALESCE(f.facturado, 0) - COALESCE(c.contabilizado, 0)) > 0.01
ORDER BY 1;


-- 3) Facturas con tipo de comprobante signo 0/NULL (nunca generan asiento, esperado)
--    y facturas sin items con cuenta contable (el service lanza error y no asienta)
SELECT h.id_transaccion, h.fecha, h.proveedor, h.nro_comprobante, h.total_importe,
       t.signo,
       (SELECT COUNT(*) FROM comp_prov_items i
         WHERE i.id_transaccion = h.id_transaccion AND i.cuenta <> 0) AS items_con_cuenta
FROM comp_prov_header h
JOIN tip_comp_mod_header t ON t.codigo = h.tipo_comprobante
WHERE t.signo IS NULL OR t.signo = 0
   OR NOT EXISTS (SELECT 1 FROM comp_prov_items i
                  WHERE i.id_transaccion = h.id_transaccion AND i.cuenta <> 0)
ORDER BY h.fecha;
