-- ============================================================
-- BACKUP PREVIO AL RELOAD DE COMPRAS Y ASIENTOS
-- Fecha: 2026-03-08
-- Ejecutar en Supabase SQL Editor ANTES de correr
-- reload_compras_asientos.js
-- ============================================================

-- Verificar que no existan backups previos del mismo día
DROP TABLE IF EXISTS comp_prov_header_bak_0308;
DROP TABLE IF EXISTS comp_prov_items_bak_0308;
DROP TABLE IF EXISTS valores_tesoreria_bak_0308;
DROP TABLE IF EXISTS asientos_header_bak_0308;
DROP TABLE IF EXISTS asientos_items_bak_0308;
DROP TABLE IF EXISTS notas_imputacion_bak_0308;
DROP TABLE IF EXISTS operaciones_contables_bak_0308;
DROP TABLE IF EXISTS operaciones_detalle_bak_0308;
DROP TABLE IF EXISTS proveedores_bak_0308;

-- Proveedores
CREATE TABLE proveedores_bak_0308 AS SELECT * FROM proveedores;

-- Comp prov (completos)
CREATE TABLE comp_prov_header_bak_0308 AS SELECT * FROM comp_prov_header;
CREATE TABLE comp_prov_items_bak_0308  AS SELECT * FROM comp_prov_items;

-- Valores tesorería (solo los de comp_prov)
CREATE TABLE valores_tesoreria_bak_0308 AS
  SELECT * FROM valores_tesoreria
  WHERE idtransaccion_origen IN (SELECT id_transaccion FROM comp_prov_header);

-- Asientos tipo 2 (Egreso) y 3 (Compras)
CREATE TABLE asientos_header_bak_0308 AS
  SELECT * FROM asientos_header WHERE tipo_asiento IN (2, 3);
CREATE TABLE asientos_items_bak_0308 AS
  SELECT * FROM asientos_items WHERE tipo_asiento IN (2, 3);

-- Trazabilidad
CREATE TABLE notas_imputacion_bak_0308 AS
  SELECT * FROM notas_imputacion WHERE tipo_operacion = 1;
CREATE TABLE operaciones_contables_bak_0308 AS
  SELECT * FROM operaciones_contables WHERE entidad_tipo = 'PROVEEDOR';
CREATE TABLE operaciones_detalle_bak_0308 AS
  SELECT * FROM operaciones_detalle_valores_tesoreria
  WHERE operacion_id IN (
    SELECT id FROM operaciones_contables WHERE entidad_tipo = 'PROVEEDOR'
  );

-- Verificación: mostrar conteos
SELECT 'proveedores_bak_0308'            AS tabla, COUNT(*) FROM proveedores_bak_0308
UNION ALL
SELECT 'comp_prov_header_bak_0308'      AS tabla, COUNT(*) FROM comp_prov_header_bak_0308
UNION ALL
SELECT 'comp_prov_items_bak_0308'       AS tabla, COUNT(*) FROM comp_prov_items_bak_0308
UNION ALL
SELECT 'valores_tesoreria_bak_0308'     AS tabla, COUNT(*) FROM valores_tesoreria_bak_0308
UNION ALL
SELECT 'asientos_header_bak_0308'       AS tabla, COUNT(*) FROM asientos_header_bak_0308
UNION ALL
SELECT 'asientos_items_bak_0308'        AS tabla, COUNT(*) FROM asientos_items_bak_0308
UNION ALL
SELECT 'notas_imputacion_bak_0308'      AS tabla, COUNT(*) FROM notas_imputacion_bak_0308
UNION ALL
SELECT 'operaciones_contables_bak_0308' AS tabla, COUNT(*) FROM operaciones_contables_bak_0308
UNION ALL
SELECT 'operaciones_detalle_bak_0308'   AS tabla, COUNT(*) FROM operaciones_detalle_bak_0308;
