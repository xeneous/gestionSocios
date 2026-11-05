-- Prueba de vinculo para recibos historicos de sponsors: numero de asiento = numero de recibo,
-- mismo anio_mes, tipo Ingreso (1). SOLO LECTURA.
-- Una fila por linea del asiento (cuenta, debe, haber) para ver como se reparte banco / retenciones.
-- En el SQL Editor de Supabase: elegir "No limit".

SELECT
  r.comprobante AS nro_recibo,
  r.fecha AS fecha_recibo,
  r.total_importe AS importe_recibo,
  h.asiento,
  h.anio_mes AS periodo_asiento,
  h.fecha AS fecha_asiento,
  i.item,
  i.cuenta_id,
  i.debe,
  i.haber,
  h.detalle
FROM public.ven_cli_header r
JOIN public.asientos_header h
  ON h.asiento = r.comprobante
 AND h.anio_mes = r.anio_mes
 AND h.tipo_asiento = 1
JOIN public.asientos_items i
  ON i.asiento = h.asiento
 AND i.anio_mes = h.anio_mes
 AND i.tipo_asiento = h.tipo_asiento
WHERE r.tipo_comprobante = 0
  AND r.fecha BETWEEN '2025-08-02' AND '2026-08-01'
  AND h.detalle NOT LIKE 'Recibo Cli Nro. %'
ORDER BY r.fecha, r.comprobante, i.item
