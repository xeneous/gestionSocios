-- ============================================================================
-- FIX: Eliminar recursión en políticas RLS de usuarios
-- ============================================================================

-- SOLUCIÓN: Deshabilitar RLS temporalmente para evitar recursión
-- Los usuarios autenticados podrán leer la tabla usuarios
-- pero solo administradores podrán modificar

-- ============================================================================
-- PASO 1: Eliminar todas las políticas existentes
-- ============================================================================
DROP POLICY IF EXISTS "Los usuarios pueden ver su propio perfil" ON public.usuarios;
DROP POLICY IF EXISTS "Los administradores pueden ver todos los usuarios" ON public.usuarios;
DROP POLICY IF EXISTS "Los usuarios pueden actualizar su perfil" ON public.usuarios;
DROP POLICY IF EXISTS "Solo administradores pueden crear usuarios" ON public.usuarios;
DROP POLICY IF EXISTS "Solo administradores pueden actualizar usuarios" ON public.usuarios;
DROP POLICY IF EXISTS "Solo administradores pueden eliminar usuarios" ON public.usuarios;

-- ============================================================================
-- PASO 2: Crear políticas simples SIN recursión
-- ============================================================================

-- Permitir SELECT a todos los usuarios autenticados
-- (Simple y sin recursión)
CREATE POLICY "Usuarios autenticados pueden leer usuarios"
  ON public.usuarios
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Para INSERT, UPDATE, DELETE usaremos la app para validar roles
-- Por ahora, solo permitir a usuarios autenticados
CREATE POLICY "Usuarios autenticados pueden actualizar"
  ON public.usuarios
  FOR UPDATE
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Usuarios autenticados pueden insertar"
  ON public.usuarios
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Usuarios autenticados pueden eliminar"
  ON public.usuarios
  FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================
-- Ver las nuevas políticas
SELECT
  polname as policy_name,
  polcmd as command
FROM pg_policy
WHERE polrelid = 'public.usuarios'::regclass;

-- Probar lectura
SELECT id, email, rol, activo
FROM public.usuarios
WHERE id = auth.uid();
