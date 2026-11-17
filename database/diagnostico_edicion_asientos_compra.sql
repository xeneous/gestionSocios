-- Indicios de edición manual / recarga en asientos de compra (tipo 3). Solo lectura.
--
-- Cómo editar un asiento en la app (asientos_provider): BORRA todos sus items y los
-- vuelve a insertar, y hace UPDATE del header. Por eso:
--   * items.created_at (y items.id) quedan POSTERIORES al header.created_at
--   * si hay trigger, header.updated_at cambia
-- Un asiento nunca tocado tiene items.created_at ~ header.created_at.
-- Un asiento cargado por la migración (reload_compras_asientos.js) comparte el mismo
-- created_at que el resto del lote.

WITH sel(anio_mes, asiento) AS (
  VALUES (202511,36),(202601,3),(202602,50),(202602,52),(202602,53),(202602,54),
         (202602,16),(202604,30),(202605,5),(202606,52),
         (202602,51)   -- 51 = el asiento "bueno" del 24/02, para comparar
)
SELECT h.anio_mes, h.asiento, h.fecha, h.detalle,
       h.created_at AS header_creado,
       h.updated_at AS header_actualizado,
       MIN(i.created_at) AS items_creado_min,
       MAX(i.created_at) AS items_creado_max,
       MIN(i.id) AS item_id_min,
       ROUND(EXTRACT(EPOCH FROM (MIN(i.created_at) - h.created_at))) AS seg_items_despues_header,
       CASE WHEN h.updated_at > h.created_at + interval '1 minute' THEN 'updated_at cambió' ELSE '' END AS ind_header,
       CASE WHEN MIN(i.created_at) > h.created_at + interval '1 minute' THEN 'items re-insertados' ELSE '' END AS ind_items
FROM sel s
JOIN asientos_header h ON h.anio_mes = s.anio_mes AND h.asiento = s.asiento AND h.tipo_asiento = 3
JOIN asientos_items  i ON i.anio_mes = h.anio_mes AND i.asiento = h.asiento AND i.tipo_asiento = 3
GROUP BY h.anio_mes, h.asiento, h.fecha, h.detalle, h.created_at, h.updated_at
ORDER BY h.fecha, h.asiento;

-- Contexto: cuándo se cargó la factura (comp_prov_header.created_at) vs el asiento
-- (se vincula por período + nro de comprobante dentro del detalle)
SELECT h.anio_mes, h.asiento, h.created_at AS asiento_creado,
       c.id_transaccion, btrim(c.nro_comprobante) AS nro, c.created_at AS factura_cargada
FROM asientos_header h
JOIN comp_prov_header c
  ON c.anio_mes = h.anio_mes AND c.proveedor = 9553
 AND h.detalle ILIKE '%' || btrim(c.nro_comprobante) || '%'
WHERE h.tipo_asiento = 3
  AND (h.anio_mes, h.asiento) IN ((202511,36),(202601,3),(202602,50),(202602,51),(202602,52),
        (202602,53),(202602,54),(202602,16),(202604,30),(202605,5),(202606,52))
ORDER BY h.fecha, h.asiento;

-- Valor actual del parámetro, con fechas si existen
SELECT * FROM parametros_contables WHERE clave = 'CUENTA_PROVEEDORES';
