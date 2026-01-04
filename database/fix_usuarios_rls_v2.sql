-- ============================================================================
-- FIX: Eliminar recursión en políticas RLS de usuarios (V2 - FORZADO)
-- ============================================================================

-- ============================================================================
-- PASO 1: Deshabilitar RLS temporalmente
-- ============================================================================
ALTER TABLE public.usuarios DISABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PASO 2: Eliminar TODAS las políticas (sin IF EXISTS para ver errores)
-- ============================================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT polname
        FROM pg_policy
        WHERE polrelid = 'public.usuarios'::regclass
    ) LOOP
        EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.polname) || ' ON public.usuarios CASCADE';
    END LOOP;
END $$;

-- ============================================================================
-- PASO 3: Re-habilitar RLS
-- ============================================================================
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PASO 4: Crear políticas simples SIN recursión
-- ============================================================================

-- Permitir SELECT a todos los usuarios autenticados
-- (Simple y sin recursión - la app valida los permisos)
CREATE POLICY "usuarios_select_policy"
  ON public.usuarios
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Permitir UPDATE a usuarios autenticados
-- (La app valida si puede modificar o no según el rol)
CREATE POLICY "usuarios_update_policy"
  ON public.usuarios
  FOR UPDATE
  USING (auth.uid() IS NOT NULL);

-- Permitir INSERT a usuarios autenticados
-- (La app valida si es admin antes de intentar crear)
CREATE POLICY "usuarios_insert_policy"
  ON public.usuarios
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Permitir DELETE a usuarios autenticados
-- (La app valida si es admin antes de intentar eliminar)
CREATE POLICY "usuarios_delete_policy"
  ON public.usuarios
  FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

-- Ver RLS habilitado
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'usuarios';

-- Ver las nuevas políticas
SELECT
  polname as policy_name,
  polcmd as command
FROM pg_policy
WHERE polrelid = 'public.usuarios'::regclass;

-- Probar lectura del usuario actual
SELECT id, email, rol, activo
FROM public.usuarios
WHERE id = auth.uid();
