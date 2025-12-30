-- ============================================================================
-- DIAGNÓSTICO COMPLETO DE TABLA CONCEPTOS
-- ============================================================================

-- 1. Verificar si la tabla existe y en qué schema está
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_name = 'conceptos';

-- 2. Verificar RLS status
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'conceptos';

-- 3. Ver políticas RLS activas
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'conceptos';

-- 4. Contar registros (como superuser/postgres role)
SELECT COUNT(*) as total_conceptos FROM conceptos;

-- 5. Ver los primeros 5 registros
SELECT id, concepto, descripcion, entidad, activo 
FROM conceptos 
ORDER BY concepto 
LIMIT 5;

-- 6. Verificar estructura de columnas
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'conceptos'
ORDER BY ordinal_position;

-- 7. Si hay filtro de activo, verificar cuántos están activos
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN activo = true THEN 1 END) as activos,
    COUNT(CASE WHEN activo = false THEN 1 END) as inactivos
FROM conceptos;

-- ============================================================================
-- EJECUTA TODOS ESTOS QUERIES Y COMPARTE LOS RESULTADOS
-- ============================================================================
