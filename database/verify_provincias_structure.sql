-- Verificar estructura de tabla provincias
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'provincias'
ORDER BY ordinal_position;

-- Ver contenido de provincias
SELECT * FROM provincias ORDER BY id LIMIT 10;

-- Verificar qué provincia_id están usando los socios
SELECT DISTINCT provincia_id FROM socios 
WHERE provincia_id IS NOT NULL 
ORDER BY provincia_id;
