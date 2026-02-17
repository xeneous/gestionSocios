-- Agregar soporte de profesionales en cuentas_corrientes
-- Ejecutar en Supabase SQL Editor SOLO si la columna no existe

-- 1. Agregar columna profesional_id (si no existe)
ALTER TABLE cuentas_corrientes
  ADD COLUMN IF NOT EXISTS profesional_id INTEGER REFERENCES profesionales(id);

-- 2. Índice para búsquedas por profesional
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_profesional
  ON cuentas_corrientes(profesional_id);

-- Verificar resultado:
-- SELECT column_name FROM information_schema.columns
-- WHERE table_name = 'cuentas_corrientes' AND column_name = 'profesional_id';
