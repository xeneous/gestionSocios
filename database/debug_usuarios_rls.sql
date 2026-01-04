-- ============================================================================
-- DEBUG: Verificar políticas RLS en tabla usuarios
-- ============================================================================

-- Ver si RLS está habilitado
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'usuarios';

-- Ver las políticas actuales
SELECT
  polname as policy_name,
  polcmd as command,
  qual as using_expression,
  with_check as check_expression
FROM pg_policy
WHERE polrelid = 'public.usuarios'::regclass;

-- Intentar leer como usuario autenticado
-- (Esto debería funcionar si las políticas están bien configuradas)
SELECT id, email, rol, activo
FROM public.usuarios
WHERE id = auth.uid();

-- Ver todos los usuarios (requiere permisos)
SELECT id, email, rol, activo
FROM public.usuarios;
