-- PRUEBA DIRECTA: Verificar que podemos leer conceptos
-- Ejecutar esto en Supabase SQL Editor

-- 1. Ver si la tabla existe y tiene datos
SELECT COUNT(*) as total_conceptos FROM conceptos;

-- 2. Ver los primeros registros
SELECT * FROM conceptos ORDER BY concepto LIMIT 10;

-- 3. Verificar RLS
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'conceptos';

-- 4. Ver políticas RLS si existen
SELECT * FROM pg_policies WHERE tablename = 'conceptos';

-- 5. Verificar estructura de columnas
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'conceptos' 
ORDER BY ordinal_position;
