-- Script para investigar todas las tablas relevantes en SQL Server
-- y obtener los nombres exactos de las columnas

-- 1. CONCEPTOS: estructura completa
PRINT '============================================';
PRINT '1. TABLA CONCEPTOS - Estructura';
PRINT '============================================';
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'conceptos'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '============================================';
PRINT '2. TABLA CONCEPTOS - Datos de muestra';
PRINT '============================================';
SELECT TOP 5 * FROM conceptos;

-- 2. CONCEPTOS_SOCIOS: estructura completa
PRINT '';
PRINT '============================================';
PRINT '3. TABLA CONCEPTOS_SOCIOS - Estructura';
PRINT '============================================';
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'conceptos_socios'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '============================================';
PRINT '4. TABLA CONCEPTOS_SOCIOS - Datos de muestra';
PRINT '============================================';
SELECT TOP 5 * FROM conceptos_socios;

-- 3. OBSERVACIONES_SOCIOS: estructura completa
PRINT '';
PRINT '============================================';
PRINT '5. TABLA OBSERVACIONES_SOCIOS - Estructura';
PRINT '============================================';
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE,
    ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'observaciones_socios'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT '============================================';
PRINT '6. TABLA OBSERVACIONES_SOCIOS - Datos de muestra';
PRINT '============================================';
SELECT TOP 5 * FROM observaciones_socios ORDER BY fecha DESC;

-- Conteos
PRINT '';
PRINT '============================================';
PRINT '7. CONTEOS DE REGISTROS';
PRINT '============================================';
SELECT 
    'conceptos' as tabla, 
    COUNT(*) as total_registros 
FROM conceptos
UNION ALL
SELECT 
    'conceptos_socios', 
    COUNT(*) 
FROM conceptos_socios
UNION ALL
SELECT 
    'observaciones_socios', 
    COUNT(*) 
FROM observaciones_socios;
