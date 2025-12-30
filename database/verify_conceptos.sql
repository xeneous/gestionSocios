-- Verificar la tabla conceptos en Supabase
SELECT * FROM conceptos ORDER BY concepto;

-- Ver cuántos conceptos hay
SELECT COUNT(*) as total_conceptos FROM conceptos;

-- Ver la estructura de la tabla
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'conceptos'
ORDER BY ordinal_position;
