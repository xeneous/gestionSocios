-- ============================================================================
-- SISTEMA DE ROLES Y USUARIOS
-- ============================================================================
-- IMPORTANTE: Este script debe ejecutarse EN ORDEN
-- Copia y pega sección por sección en el SQL Editor de Supabase

-- ============================================================================
-- PASO 1: Crear tabla usuarios
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.usuarios (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  nombre TEXT,
  apellido TEXT,
  rol TEXT NOT NULL DEFAULT 'usuario' CHECK (rol IN ('usuario', 'contable', 'administrador')),
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON public.usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_rol ON public.usuarios(rol);
CREATE INDEX IF NOT EXISTS idx_usuarios_activo ON public.usuarios(activo);

-- ============================================================================
-- PASO 2: Trigger para auto-crear usuario cuando se registra en auth
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.usuarios (id, email, rol, activo)
  VALUES (NEW.id, NEW.email, 'usuario', true);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- PASO 3: Trigger para updated_at
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_usuarios_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS usuarios_updated_at ON public.usuarios;

CREATE TRIGGER usuarios_updated_at
  BEFORE UPDATE ON public.usuarios
  FOR EACH ROW EXECUTE FUNCTION public.update_usuarios_updated_at();

-- ============================================================================
-- PASO 4: Habilitar RLS
-- ============================================================================
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- PASO 5: Políticas RLS
-- ============================================================================

-- Los usuarios pueden ver su propio perfil
DROP POLICY IF EXISTS "Los usuarios pueden ver su propio perfil" ON public.usuarios;
CREATE POLICY "Los usuarios pueden ver su propio perfil"
  ON public.usuarios
  FOR SELECT
  USING (auth.uid() = id);

-- Los administradores pueden ver todos los usuarios
DROP POLICY IF EXISTS "Los administradores pueden ver todos los usuarios" ON public.usuarios;
CREATE POLICY "Los administradores pueden ver todos los usuarios"
  ON public.usuarios
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol = 'administrador'
    )
  );

-- Los usuarios pueden actualizar su propio perfil (excepto rol)
DROP POLICY IF EXISTS "Los usuarios pueden actualizar su perfil" ON public.usuarios;
CREATE POLICY "Los usuarios pueden actualizar su perfil"
  ON public.usuarios
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND
    rol = (SELECT rol FROM public.usuarios WHERE id = auth.uid())
  );

-- Solo administradores pueden crear usuarios
DROP POLICY IF EXISTS "Solo administradores pueden crear usuarios" ON public.usuarios;
CREATE POLICY "Solo administradores pueden crear usuarios"
  ON public.usuarios
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol = 'administrador'
    )
  );

-- Solo administradores pueden actualizar cualquier usuario
DROP POLICY IF EXISTS "Solo administradores pueden actualizar usuarios" ON public.usuarios;
CREATE POLICY "Solo administradores pueden actualizar usuarios"
  ON public.usuarios
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol = 'administrador'
    )
  );

-- Solo administradores pueden eliminar usuarios
DROP POLICY IF EXISTS "Solo administradores pueden eliminar usuarios" ON public.usuarios;
CREATE POLICY "Solo administradores pueden eliminar usuarios"
  ON public.usuarios
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.usuarios
      WHERE id = auth.uid() AND rol = 'administrador'
    )
  );

-- ============================================================================
-- PASO 6: Migrar usuarios existentes (TODOS serán administradores inicialmente)
-- ============================================================================
-- IMPORTANTE: Ejecuta esto DESPUÉS de los pasos anteriores
INSERT INTO public.usuarios (id, email, rol, activo)
SELECT
  id,
  email,
  'administrador', -- Todos los usuarios existentes serán administradores
  true
FROM auth.users
WHERE email IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================
-- Ejecuta esto para verificar que todo funcionó correctamente:
SELECT * FROM public.usuarios;

-- Deberías ver todos tus usuarios existentes con rol 'administrador'
