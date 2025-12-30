-- Verificar estructura de tabla conceptos (maestro)
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'conceptos'
ORDER BY ORDINAL_POSITION;

-- Ver algunos registros de conceptos
SELECT TOP 10 * FROM conceptos;

-- Contar registros
SELECT COUNT(*) as total_conceptos FROM conceptos;
