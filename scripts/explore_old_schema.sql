-- Script de conexión para explorar esquema viejo
-- Ejecutar en SQL Server Management Studio o Azure Data Studio

-- Conectar a:
-- Host: 66.97.41.202,49999
-- User: vwr
-- Password: Cr0m0_maVwr_@
-- Database: basecrm

-- Ver todas las tablas
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- Ver estructura de tabla Socios (ejemplo)
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Socios'
ORDER BY ORDINAL_POSITION;

-- Ver estructura de Provincias
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Provincias'
ORDER BY ORDINAL_POSITION;

-- Ver estructura de Categorias_IVA
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('Categorias_IVA', 'CategoriasIVA', 'CategoriaIVA')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- Ver estructura de Grupos
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME LIKE '%Grupo%'
ORDER BY TABLE_NAME, ORDINAL_POSITION;
