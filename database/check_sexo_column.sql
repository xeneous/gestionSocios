-- Verificar el tipo de dato actual de la columna sexo
SELECT 
    column_name,
    data_type,
    udt_name,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'socios' 
  AND column_name = 'sexo';

-- Ver algunos valores actuales
SELECT id, apellido, nombre, sexo, pg_typeof(sexo) as tipo_sexo
FROM socios
LIMIT 10;
