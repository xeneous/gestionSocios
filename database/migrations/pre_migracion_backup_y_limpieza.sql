-- ============================================================================
-- PRE-MIGRACION: Backup socios + Limpieza tablas de trazabilidad
-- ============================================================================
-- EJECUTAR EN SUPABASE SQL EDITOR **ANTES** de correr MigracionCompleta.bat
-- ============================================================================

-- 1. Backup de socios (reemplaza si ya existe de una corrida anterior)
DROP TABLE IF EXISTS socios_backup_migracion;
CREATE TABLE socios_backup_migracion AS SELECT * FROM socios;

SELECT 'Backup creado: ' || count(*)::text || ' socios' as resultado
FROM socios_backup_migracion;

-- 2. Limpiar tablas de trazabilidad (datos de pruebas)
-- Orden: hijos antes que padres por FKs

-- Detalle trazabilidad CC (referencia a cuentas_corrientes Y operaciones_contables)
DELETE FROM operaciones_detalle_cuentas_corrientes WHERE id > 0;

-- Otras tablas de trazabilidad
DELETE FROM detalle_presentaciones_tarjetas WHERE id > 0;

-- rechazos_tarjetas puede referenciar operaciones_contables, va antes
DELETE FROM rechazos_tarjetas WHERE id > 0;

-- Tabla madre (va última entre las de trazabilidad)
DELETE FROM operaciones_contables WHERE id > 0;

SELECT 'Limpieza de trazabilidad completada' as resultado;
