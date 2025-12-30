-- Script para limpiar y preparar Supabase para re-migración
-- Ejecutar en Supabase SQL Editor

-- ============================================================================
-- PASO 1: Limpiar datos existentes
-- ============================================================================

-- Eliminar socios (esto también limpiará conceptos_socios por CASCADE)
DELETE FROM socios;

-- Eliminar tarjetas (excepto la tarjeta ID 0 si existe)
DELETE FROM tarjetas WHERE id != 0;

-- ============================================================================
-- PASO 2: Resetear secuencias
-- ============================================================================

-- Resetear secuencia de socios (volverá a usar los IDs que insertemos)
SELECT setval(pg_get_serial_sequence('socios', 'id'), 1, false);

-- Resetear secuencia de tarjetas (volverá a usar los IDs que insertemos)
SELECT setval(pg_get_serial_sequence('tarjetas', 'id'), 1, false);

-- ============================================================================
-- PASO 3: Verificar estado
-- ============================================================================

-- Verificar que las tablas estén vacías
SELECT 'socios' as tabla, COUNT(*) as registros FROM socios
UNION ALL
SELECT 'tarjetas', COUNT(*) FROM tarjetas WHERE id != 0;

-- ============================================================================
-- LISTO PARA RE-MIGRACIÓN
-- ============================================================================
-- Ahora puedes ejecutar:
-- 1. node migrate.js referencias  (para re-migrar tarjetas con IDs correctos)
-- 2. node migrate.js socios       (para migrar socios con tarjeta_id correctos)
-- ============================================================================
