-- =============================================================================
-- RESTAURAR asientos de compra editados el 23/10/2026 a su estado original
-- (según backup mensual del 1/7/2026): debe 5930000 / haber 2111000.
--
-- NO ejecutar hasta confirmar con quien los editó que fue un error.
-- Ejecutar los pasos de a uno. Con la auditoría activa, el cambio queda registrado.
-- =============================================================================

-- PASO 1: vista previa (solo lectura)
SELECT i.anio_mes, i.asiento, i.item, i.cuenta_id, i.debe, i.haber
FROM asientos_items i
WHERE i.tipo_asiento = 3
  AND (i.anio_mes, i.asiento) IN ((202511,36),(202601,3),(202602,16),(202602,50),(202602,52),
                                  (202602,53),(202602,54),(202604,30),(202605,5),(202606,52))
ORDER BY i.anio_mes, i.asiento, i.item;

-- PASO 2: restaurar (transacción). Revisar el resultado antes del COMMIT.
-- El 202606-52 no estaba en el backup de julio; se restaura por analogía (misma firma de edición).
BEGIN;

-- OJO: el DEBE (5930000 INGRESO CURSO ANUAL -> 4128100 EGRESOS CURSO ANUAL) parece una
-- corrección legítima del gasto, por eso NO se revierte. Solo se restaura el HABER
-- (1112040 BANCO ICBC -> 2111000 PROVEEDORES A PAGAR). Si quieren volver también el debe,
-- agregar un UPDATE con cuenta_id = 5930000 WHERE cuenta_id = 4128100 AND debe > 0.
UPDATE asientos_items
SET cuenta_id = 2111000
WHERE tipo_asiento = 3 AND cuenta_id = 1112040 AND haber > 0
  AND (anio_mes, asiento) IN ((202511,36),(202601,3),(202602,16),(202602,50),(202602,52),
                              (202602,53),(202602,54),(202604,30),(202605,5),(202606,52));

-- Control: deben salir 10 asientos con 2 líneas (4128100 al debe, 2111000 al haber)
SELECT anio_mes, asiento, item, cuenta_id, debe, haber
FROM asientos_items
WHERE tipo_asiento = 3
  AND (anio_mes, asiento) IN ((202511,36),(202601,3),(202602,16),(202602,50),(202602,52),
                              (202602,53),(202602,54),(202604,30),(202605,5),(202606,52))
ORDER BY anio_mes, asiento, item;

-- Si está bien: COMMIT;   Si no: ROLLBACK;
