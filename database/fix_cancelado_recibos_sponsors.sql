-- CORRECCION: recibos de sponsors generados por el sistema nuevo quedaron con cancelado = 0.
-- Los recibos historicos tienen cancelado = total_importe (recibo aplicado). Con 0 el recibo
-- figura "sin aplicar" y la ficha / listados de saldos lo cuentan como deuda.
--
-- Criterio: solo se toca un recibo (tipo_comprobante = 0) cuyo cancelado es MENOR a lo aplicado y que SI tiene
-- aplicaciones en notas_imputacion (tipo_operacion = 2); se iguala cancelado a lo aplicado (nunca lo baja).
-- Los recibos sin aplicaciones registradas NO se tocan (hay que revisarlos a mano: consulta 3
-- de auditoria_aplicaciones_recibos_sponsors.sql).
--
-- Ejecutar el PASO 1 (solo lectura), revisar, y recien despues el PASO 2.

-- ======================= PASO 1) VISTA PREVIA =======================
SELECT r.cliente, r.comprobante AS nro_recibo, r.fecha, r.total_importe,
       r.cancelado AS cancelado_actual, a.aplicado AS cancelado_nuevo,
       r.total_importe - a.aplicado AS diferencia_con_total
FROM public.ven_cli_header r
JOIN (SELECT id_operacion, SUM(importe) AS aplicado
        FROM public.notas_imputacion
       WHERE tipo_operacion = 2
       GROUP BY id_operacion) a ON a.id_operacion = r.id_transaccion
WHERE r.tipo_comprobante = 0
  AND COALESCE(r.cancelado, 0) < a.aplicado - 0.005
ORDER BY r.cliente, r.fecha, r.comprobante;

-- ======================= PASO 2) CORRECCION =======================
-- Ejecutar en una sola pasada. Si el resultado no es el esperado, hacer ROLLBACK en lugar de COMMIT.
BEGIN;

UPDATE public.ven_cli_header r
SET cancelado = a.aplicado
FROM (SELECT id_operacion, SUM(importe) AS aplicado
        FROM public.notas_imputacion
       WHERE tipo_operacion = 2
       GROUP BY id_operacion) a
WHERE a.id_operacion = r.id_transaccion
  AND r.tipo_comprobante = 0
  AND COALESCE(r.cancelado, 0) < a.aplicado - 0.005;

-- Control: el sponsor 62 deberia dar error_ficha = 0 (ficha = contable = 55.915.000).
SELECT SUM(h.total_importe - COALESCE(h.cancelado, 0)) FILTER (WHERE h.tipo_comprobante <> 0) AS facturas_pendientes,
       SUM(h.total_importe - COALESCE(h.cancelado, 0)) FILTER (WHERE h.tipo_comprobante = 0)  AS recibos_pendientes
FROM public.ven_cli_header h
WHERE h.cliente = 62;

COMMIT;  -- o ROLLBACK;
