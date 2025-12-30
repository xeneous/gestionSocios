-- Verificar estructura de tabla observaciones_socios
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'observaciones_socios'
ORDER BY ORDINAL_POSITION;

-- Ver algunos registros de observaciones
SELECT TOP 20 * FROM observaciones_socios ORDER BY fecha DESC;

-- Contar registros
SELECT COUNT(*) as total_observaciones FROM observaciones_socios;

-- Ver distribución por socio
SELECT 
    socio,
    COUNT(*) as cantidad_observaciones
FROM observaciones_socios
GROUP BY socio
ORDER BY cantidad_observaciones DESC;
