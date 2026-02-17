-- Agregar campos de débito automático a la tabla profesionales
-- Ejecutar en Supabase SQL Editor

ALTER TABLE profesionales
  ADD COLUMN IF NOT EXISTS tarjeta_id INTEGER,
  ADD COLUMN IF NOT EXISTS numero_tarjeta VARCHAR(16),
  ADD COLUMN IF NOT EXISTS adherido_debito BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS vencimiento_tarjeta DATE,
  ADD COLUMN IF NOT EXISTS debitar_desde DATE;

-- Actualizar registros existentes para que adherido_debito sea false por defecto
UPDATE profesionales SET adherido_debito = false WHERE adherido_debito IS NULL;
