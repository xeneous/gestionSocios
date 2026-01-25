-- =============================================================================
-- Reset de secuencias CLIPRO después de migración
-- Ejecutar en Supabase SQL Editor
-- =============================================================================

SELECT setval(pg_get_serial_sequence('categorias_iva', 'id_civa'), COALESCE((SELECT MAX(id_civa) FROM categorias_iva), 1));
SELECT setval(pg_get_serial_sequence('clientes', 'codigo'), COALESCE((SELECT MAX(codigo) FROM clientes), 1));
SELECT setval(pg_get_serial_sequence('contactos_clientes', 'id_contacto'), COALESCE((SELECT MAX(id_contacto) FROM contactos_clientes), 1));
SELECT setval(pg_get_serial_sequence('proveedores', 'codigo'), COALESCE((SELECT MAX(codigo) FROM proveedores), 1));
SELECT setval(pg_get_serial_sequence('contactos_proveedores', 'id_contacto'), COALESCE((SELECT MAX(id_contacto) FROM contactos_proveedores), 1));
SELECT setval(pg_get_serial_sequence('tip_vent_mod_header', 'codigo'), COALESCE((SELECT MAX(codigo) FROM tip_vent_mod_header), 1));
SELECT setval(pg_get_serial_sequence('tip_vent_mod_items', 'id'), COALESCE((SELECT MAX(id) FROM tip_vent_mod_items), 1));
SELECT setval(pg_get_serial_sequence('tip_comp_mod_header', 'codigo'), COALESCE((SELECT MAX(codigo) FROM tip_comp_mod_header), 1));
SELECT setval(pg_get_serial_sequence('tip_comp_mod_items', 'id'), COALESCE((SELECT MAX(id) FROM tip_comp_mod_items), 1));
SELECT setval(pg_get_serial_sequence('ven_cli_header', 'id_transaccion'), COALESCE((SELECT MAX(id_transaccion) FROM ven_cli_header), 1));
SELECT setval(pg_get_serial_sequence('ven_cli_items', 'id_campo'), COALESCE((SELECT MAX(id_campo) FROM ven_cli_items), 1));
SELECT setval(pg_get_serial_sequence('comp_prov_header', 'id_transaccion'), COALESCE((SELECT MAX(id_transaccion) FROM comp_prov_header), 1));
SELECT setval(pg_get_serial_sequence('comp_prov_items', 'id_campo'), COALESCE((SELECT MAX(id_campo) FROM comp_prov_items), 1));

-- Verificar conteos
SELECT 'categorias_iva' as tabla, COUNT(*) as registros FROM categorias_iva
UNION ALL SELECT 'clientes', COUNT(*) FROM clientes
UNION ALL SELECT 'contactos_clientes', COUNT(*) FROM contactos_clientes
UNION ALL SELECT 'proveedores', COUNT(*) FROM proveedores
UNION ALL SELECT 'contactos_proveedores', COUNT(*) FROM contactos_proveedores
UNION ALL SELECT 'tip_vent_mod_header', COUNT(*) FROM tip_vent_mod_header
UNION ALL SELECT 'tip_vent_mod_items', COUNT(*) FROM tip_vent_mod_items
UNION ALL SELECT 'tip_comp_mod_header', COUNT(*) FROM tip_comp_mod_header
UNION ALL SELECT 'tip_comp_mod_items', COUNT(*) FROM tip_comp_mod_items
UNION ALL SELECT 'ven_cli_header', COUNT(*) FROM ven_cli_header
UNION ALL SELECT 'ven_cli_items', COUNT(*) FROM ven_cli_items
UNION ALL SELECT 'comp_prov_header', COUNT(*) FROM comp_prov_header
UNION ALL SELECT 'comp_prov_items', COUNT(*) FROM comp_prov_items
ORDER BY tabla;
