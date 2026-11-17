-- Asientos de pago (egreso, tipo 2) que NO debitan la cuenta de proveedores (2111000).
-- Solo lectura. Cambiar el período si hace falta.

-- 1) Detalle de las líneas de esos asientos
SELECT a.anio_mes, a.asiento, a.fecha, a.detalle,
       i.item, i.cuenta_id, i.debe, i.haber
FROM asientos_header a
JOIN asientos_items i
  ON i.asiento = a.asiento AND i.anio_mes = a.anio_mes AND i.tipo_asiento = a.tipo_asiento
WHERE a.tipo_asiento = 2
  AND a.fecha BETWEEN DATE '2025-08-02' AND DATE '2026-08-01'
  AND NOT EXISTS (
    SELECT 1 FROM asientos_items x
    WHERE x.asiento = a.asiento AND x.anio_mes = a.anio_mes AND x.tipo_asiento = a.tipo_asiento
      AND x.cuenta_id = 2111000 AND x.debe > 0
  )
ORDER BY a.fecha, a.anio_mes, a.asiento, i.item;

-- 2) Resumen: en qué cuenta debitan esos asientos
SELECT i.cuenta_id AS cuenta_debito,
       COUNT(DISTINCT (a.anio_mes, a.asiento)) AS asientos,
       SUM(i.debe) AS debe_total
FROM asientos_header a
JOIN asientos_items i
  ON i.asiento = a.asiento AND i.anio_mes = a.anio_mes AND i.tipo_asiento = a.tipo_asiento
WHERE a.tipo_asiento = 2
  AND i.debe > 0
  AND a.fecha BETWEEN DATE '2025-08-02' AND DATE '2026-08-01'
  AND NOT EXISTS (
    SELECT 1 FROM asientos_items x
    WHERE x.asiento = a.asiento AND x.anio_mes = a.anio_mes AND x.tipo_asiento = a.tipo_asiento
      AND x.cuenta_id = 2111000 AND x.debe > 0
  )
GROUP BY i.cuenta_id
ORDER BY asientos DESC;
