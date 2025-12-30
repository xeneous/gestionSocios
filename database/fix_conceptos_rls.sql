-- ============================================================================
-- SOLUCIÓN DEFINITIVA: Conceptos retorna lista vacía
-- ============================================================================
-- PROBLEMA: Supabase retorna [] a pesar de tener 19 conceptos
-- CAUSA: Row Level Security (RLS) bloqueando el acceso
-- ============================================================================

-- PASO 1: Verificar si RLS está habilitado
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'conceptos';
-- Si rowsecurity = true, RLS está activo

-- PASO 2: Ver las políticas existentes (si hay)
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'conceptos';

-- PASO 3: SOLUCIÓN RECOMENDADA
-- Para tablas de referencia como conceptos, lo mejor es desactivar RLS
-- O crear una política que permita lectura a todos los usuarios autenticados

-- OPCIÓN A: Desactivar RLS completamente (RECOMENDADO para tablas de referencia)
ALTER TABLE public.conceptos DISABLE ROW LEVEL SECURITY;

-- OPCIÓN B: Si quieres mantener RLS, crear política de lectura
-- Primero, eliminar políticas existentes si las hay
DROP POLICY IF EXISTS "Enable read access for all users" ON public.conceptos;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.conceptos;

-- Crear política para usuarios autenticados
CREATE POLICY "Allow authenticated users to read conceptos"
ON public.conceptos
FOR SELECT
TO authenticated
USING (true);

-- PASO 4: Verificar que funciona
SELECT COUNT(*) FROM conceptos;
SELECT * FROM conceptos LIMIT 3;

-- ============================================================================
-- NOTAS IMPORTANTES:
-- ============================================================================
-- 1. Asegúrate de ejecutar esto en el SQL Editor de Supabase
-- 2. La tabla debe estar en el schema 'public'
-- 3. Después de aplicar, refresca la app Flutter (hot reload)
-- 4. Si sigues teniendo problemas, verifica que estés autenticado en la app
-- ============================================================================
