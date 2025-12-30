-- Script para preparar la tabla socios para re-migración
-- Ejecutar en Supabase SQL Editor ANTES de volver a migrar

-- 0. INSERTAR TARJETA CON ID 0 (para casos NULL)
INSERT INTO tarjetas (id, codigo, descripcion) 
VALUES (0, '0', 'Sin tarjeta / No informada')
ON CONFLICT (id) DO NOTHING;

-- 1. ELIMINAR TODOS LOS SOCIOS EXISTENTES
DELETE FROM socios;

-- 2. RESETEAR LA SECUENCIA DE IDs
SELECT setval(pg_get_serial_sequence('socios', 'id'), 1, false);

-- 3. VERIFICAR QUE LA TABLA ESTÉ VACÍA
SELECT COUNT(*) as total_socios FROM socios;
-- Debería retornar 0

-- Después de ejecutar este script:
-- 1. Ejecutar desde scripts/migration: node migrate.js socios
-- 2. Los números de socio deberían coincidir con SQL Server
-- 3. IMPORTANTE: Después de la migración, ejecutar este comando también:
--    SELECT setval(pg_get_serial_sequence('socios', 'id'), COALESCE(MAX(id), 1)) FROM socios;
