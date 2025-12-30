-- Verificar estructura de tabla conceptos_socios
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'conceptos_socios'
ORDER BY ORDINAL_POSITION;

-- Ver algunos registros de conceptos_socios
SELECT TOP 20 * FROM conceptos_socios ORDER BY socio;

-- Contar registros
SELECT COUNT(*) as total_conceptos_socios FROM conceptos_socios;

-- Ver conceptos activos vs inactivos
SELECT 
    CASE WHEN fechabaja IS NULL THEN 'Activo' ELSE 'Inactivo' END as estado,
    COUNT(*) as cantidad
FROM conceptos_socios
GROUP BY CASE WHEN fechabaja IS NULL THEN 'Activo' ELSE 'Inactivo' END;
