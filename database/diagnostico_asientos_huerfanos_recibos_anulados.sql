-- Asientos de ingreso de recibos de socios/profesionales que fueron DADOS DE BAJA pero cuyo asiento
-- sigue en la contabilidad. Solo lectura (SELECT). PostgreSQL / Supabase.
--
-- Causa: la baja anterior borraba el asiento con WHERE detalle = 'Recibo Nro. N', pero el asiento real
-- se graba como 'Recibo Nro. N - Apellido, Nombre', por lo que nunca coincidia.
--
-- Para cada recibo anulado (tabla recibos_anulados) lista los asientos tipo 1 que siguen existiendo.
-- OJO: si el numero de recibo se reutilizo en un recibo vigente, el asiento puede ser de ese otro recibo
-- (columna recibo_vigente = true). Revisar a mano antes de reversar nada.

SELECT
  ra.numero_recibo,
  ra.fecha_anulacion,
  ra.fecha_recibo,
  ra.importe,
  ra.motivo,
  h.asiento, h.anio_mes, h.tipo_asiento, h.fecha AS fecha_asiento, h.detalle,
  (SELECT COALESCE(SUM(i.debe),0) FROM public.asientos_items i
    WHERE i.asiento = h.asiento AND i.anio_mes = h.anio_mes AND i.tipo_asiento = h.tipo_asiento) AS total_asiento,
  EXISTS (SELECT 1 FROM public.operaciones_contables oc
          WHERE oc.tipo_operacion IN ('COBRANZA_SOCIO','COBRANZA_PROFESIONAL')
            AND oc.numero_comprobante = ra.numero_recibo) AS recibo_vigente
FROM public.recibos_anulados ra
JOIN public.asientos_header h
  ON h.tipo_asiento = 1
 AND (h.detalle = 'Recibo Nro. ' || ra.numero_recibo
      OR h.detalle LIKE 'Recibo Nro. ' || ra.numero_recibo || ' - %')
ORDER BY ra.fecha_anulacion, ra.numero_recibo;
