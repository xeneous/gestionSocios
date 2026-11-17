-- Asientos de compra (tipo 3) cuyo crédito (haber) NO es la cuenta de proveedores (2111000).
-- Solo lectura. Cambiar el período si hace falta.

-- 1) Detalle: una fila por línea de haber que no es 2111000
SELECT a.anio_mes, a.asiento, a.fecha, a.detalle,
       i.item, i.cuenta_id AS cuenta_credito, i.haber
FROM asientos_header a
JOIN asientos_items i
  ON i.asiento = a.asiento AND i.anio_mes = a.anio_mes AND i.tipo_asiento = a.tipo_asiento
WHERE a.tipo_asiento = 3
  AND i.haber > 0
  AND i.cuenta_id <> 2111000
  AND a.fecha BETWEEN DATE '2025-08-02' AND DATE '2026-08-01'
ORDER BY a.fecha, a.anio_mes, a.asiento, i.item;

-- 2) Resumen por cuenta de crédito usada
SELECT i.cuenta_id AS cuenta_credito,
       COUNT(DISTINCT (a.anio_mes, a.asiento)) AS asientos,
       SUM(i.haber) AS haber_total
FROM asientos_header a
JOIN asientos_items i
  ON i.asiento = a.asiento AND i.anio_mes = a.anio_mes AND i.tipo_asiento = a.tipo_asiento
WHERE a.tipo_asiento = 3
  AND i.haber > 0
  AND i.cuenta_id <> 2111000
  AND a.fecha BETWEEN DATE '2025-08-02' AND DATE '2026-08-01'
GROUP BY i.cuenta_id
ORDER BY asientos DESC;
