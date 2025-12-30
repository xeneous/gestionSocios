-- Script para actualizar tarjeta_id de socios existentes
-- Este script corrige el problema donde todos los socios fueron migrados con tarjeta_id = 0
-- 
-- IMPORTANTE: Ejecutar este script después de migrar las tablas de referencia
-- pero antes de que los usuarios comiencen a usar el sistema

-- Paso 1: Verificar estado actual
SELECT 
    'Antes de actualizar' as momento,
    tarjeta_id,
    COUNT(*) as cantidad_socios
FROM socios
GROUP BY tarjeta_id
ORDER BY tarjeta_id;

-- Paso 2: BACKUP - Crear tabla temporal con los datos actuales (por si acaso)
CREATE TABLE IF NOT EXISTS socios_backup_tarjetas AS
SELECT id, tarjeta_id, numero_tarjeta, adherido_debito, vencimiento_tarjeta, debitar_desde
FROM socios;

-- Paso 3: Actualizar desde SQL Server
-- NOTA: Este UPDATE debe ejecutarse conectado a SQL Server o mediante un script de migración
-- Por ahora, mostramos ejemplos de cómo actualizar manualmente

-- Ejemplo para el socio 3321 que debería tener VISA (ID 1):
UPDATE socios 
SET tarjeta_id = 1
WHERE id = 3321;

-- Para actualizar todos los socios, deberás:
-- 1. Exportar los datos de SQL Server: SELECT socio, Tarjeta FROM socios WHERE Tarjeta IS NOT NULL
-- 2. Generar los UPDATEs correspondientes
-- 3. O mejor: volver a ejecutar la migración completa con el script corregido

-- Paso 4: Verificar resultado
SELECT 
    'Después de actualizar' as momento,
    tarjeta_id,
    COUNT(*) as cantidad_socios
FROM socios
GROUP BY tarjeta_id
ORDER BY tarjeta_id;

-- Paso 5: Verificar socios con débito automático
SELECT 
    s.id,
    s.apellido,
    s.nombre,
    s.tarjeta_id,
    t.descripcion as tarjeta,
    s.numero_tarjeta,
    s.adherido_debito
FROM socios s
LEFT JOIN tarjetas t ON s.tarjeta_id = t.id
WHERE s.adherido_debito = true
ORDER BY s.id;
