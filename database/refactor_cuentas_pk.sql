-- ============================================================================
-- REFACTOR: Cambiar Primary Key de tabla CUENTAS
-- De: id (serial) a cuenta (integer)
-- ============================================================================
-- IMPORTANTE: Ejecutar este script EN ORDEN en Supabase SQL Editor
-- Hacer backup antes de ejecutar
-- ============================================================================

-- PASO 1: Eliminar todas las Foreign Keys que apuntan a cuentas(id)
-- ============================================================================

ALTER TABLE asientos_items 
  DROP CONSTRAINT IF EXISTS asientos_items_cuenta_id_fkey;

ALTER TABLE clientes 
  DROP CONSTRAINT IF EXISTS clientes_cuenta_contable_id_fkey;

ALTER TABLE proveedores 
  DROP CONSTRAINT IF EXISTS proveedores_cuenta_contable_id_fkey;

ALTER TABLE conceptos 
  DROP CONSTRAINT IF EXISTS conceptos_cuenta_contable_id_fkey;

ALTER TABLE compras_items 
  DROP CONSTRAINT IF EXISTS compras_items_cuenta_id_fkey;

ALTER TABLE ventas_items 
  DROP CONSTRAINT IF EXISTS ventas_items_cuenta_id_fkey;

ALTER TABLE conceptos_tesoreria 
  DROP CONSTRAINT IF EXISTS conceptos_tesoreria_cuenta_contable_id_fkey;

-- PASO 2: Eliminar Primary Key actual y crear nueva con 'cuenta'
-- ============================================================================

ALTER TABLE cuentas DROP CONSTRAINT IF EXISTS cuentas_pkey;
ALTER TABLE cuentas ADD PRIMARY KEY (cuenta);

-- PASO 3: Eliminar columna 'id' (ya no necesaria)
-- ============================================================================

ALTER TABLE cuentas DROP COLUMN IF EXISTS id;

-- PASO 4: Recrear Foreign Keys apuntando a cuentas(cuenta)
-- ============================================================================
-- Nota: Las columnas FK mantienen su tipo INTEGER ya que 'cuenta' es INTEGER

ALTER TABLE asientos_items 
  ADD CONSTRAINT asientos_items_cuenta_fkey 
  FOREIGN KEY (cuenta_id) REFERENCES cuentas(cuenta);

ALTER TABLE clientes 
  ADD CONSTRAINT clientes_cuenta_contable_fkey 
  FOREIGN KEY (cuenta_contable_id) REFERENCES cuentas(cuenta);

ALTER TABLE proveedores 
  ADD CONSTRAINT proveedores_cuenta_contable_fkey 
  FOREIGN KEY (cuenta_contable_id) REFERENCES cuentas(cuenta);

ALTER TABLE conceptos 
  ADD CONSTRAINT conceptos_cuenta_contable_fkey 
  FOREIGN KEY (cuenta_contable_id) REFERENCES cuentas(cuenta);

ALTER TABLE compras_items 
  ADD CONSTRAINT compras_items_cuenta_fkey 
  FOREIGN KEY (cuenta_id) REFERENCES cuentas(cuenta);

ALTER TABLE ventas_items 
  ADD CONSTRAINT ventas_items_cuenta_fkey 
  FOREIGN KEY (cuenta_id) REFERENCES cuentas(cuenta);

ALTER TABLE conceptos_tesoreria 
  ADD CONSTRAINT conceptos_tesoreria_cuenta_contable_fkey 
  FOREIGN KEY (cuenta_contable_id) REFERENCES cuentas(cuenta);

-- ============================================================================
-- VERIFICACIONES POST-REFACTOR
-- ============================================================================

-- Verificar estructura de cuentas
SELECT 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'cuentas'
ORDER BY ordinal_position;

-- Verificar FKs recreadas correctamente
SELECT
  tc.table_name, 
  kcu.column_name,
  ccu.table_name AS foreign_table_name,
  ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND ccu.table_name = 'cuentas';

-- Verificar que no hay cuentas con NULL
SELECT COUNT(*) as cuentas_invalidas 
FROM cuentas 
WHERE cuenta IS NULL;
-- Debe retornar 0

-- ============================================================================
-- RESULTADO ESPERADO:
-- - Tabla cuentas SIN columna 'id'
-- - Columna 'cuenta' es PRIMARY KEY
-- - 7 tablas con FKs apuntando a cuentas(cuenta)
-- ============================================================================
