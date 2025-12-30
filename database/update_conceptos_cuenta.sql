-- ============================================================================
-- ACTUALIZAR TABLA CONCEPTOS: cambiar cuenta_contable_id por cuenta_contable
-- ============================================================================
-- Este script debe ejecutarse DESPUÉS del refactor_cuentas_pk.sql
-- ============================================================================

-- PASO 1: Eliminar FK existente si existe
ALTER TABLE conceptos 
  DROP CONSTRAINT IF EXISTS conceptos_cuenta_contable_id_fkey;

ALTER TABLE conceptos 
  DROP CONSTRAINT IF EXISTS conceptos_cuenta_contable_fkey;

-- PASO 2: Eliminar columna cuenta_contable_id si existe
ALTER TABLE conceptos 
  DROP COLUMN IF EXISTS cuenta_contable_id;

-- PASO 3: Agregar columna cuenta_contable si no existe
ALTER TABLE conceptos 
  ADD COLUMN IF NOT EXISTS cuenta_contable INTEGER;

-- PASO 4: Crear FK apuntando a cuentas(cuenta)
ALTER TABLE conceptos 
  ADD CONSTRAINT conceptos_cuenta_contable_fkey 
  FOREIGN KEY (cuenta_contable) REFERENCES cuentas(cuenta);

-- PASO 5: Verificar estructura
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'conceptos' 
ORDER BY ordinal_position;

-- Debe mostrar:
-- cuenta_contable | integer | YES
-- NO debe mostrar: cuenta_contable_id
