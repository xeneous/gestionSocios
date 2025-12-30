-- Script para ejecutar DESPUÉS de migrar los socios
-- Ejecutar en Supabase SQL Editor

-- Resetear la secuencia de IDs para que los próximos inserts usen el número correcto
-- Esto establece la secuencia al MAX(id) actual + 1
SELECT setval(
    pg_get_serial_sequence('socios', 'id'), 
    COALESCE((SELECT MAX(id) FROM socios), 1)
);

-- Verificar el resultado
SELECT 
    currval(pg_get_serial_sequence('socios', 'id')) as secuencia_actual,
    (SELECT MAX(id) FROM socios) as max_id_tabla,
    (SELECT COUNT(*) FROM socios) as total_socios;
