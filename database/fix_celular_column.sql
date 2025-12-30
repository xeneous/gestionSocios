-- Script simple para agregar la columna celular y otras columnas de contacto faltantes
-- Ejecutar en Supabase SQL Editor

-- Agregar columna celular
ALTER TABLE socios ADD COLUMN IF NOT EXISTS celular VARCHAR(50);

-- Verificar que se agregó correctamente
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'socios' AND column_name = 'celular';
