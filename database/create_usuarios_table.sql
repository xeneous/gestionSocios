-- ============================================================================
-- TABLA USUARIOS
-- ============================================================================
-- Tabla para gestionar perfiles de usuario y roles
-- Se vincula con auth.users de Supabase

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
-- TRIGGER: Auto-crear registro en usuarios cuando se crea un user en auth
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.usuarios (id, email, rol, activo)
  VALUES (NEW.id, NEW.email, 'usuario', true);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Eliminar trigger si existe
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Crear trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- TRIGGER: Actualizar updated_at automáticamente
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
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

-- Política: Los usuarios pueden ver su propio registro
DROP POLICY IF EXISTS "Los usuarios pueden ver su propio perfil" ON public.usuarios;
CREATE POLICY "Los usuarios pueden ver su propio perfil"
  ON public.usuarios
  FOR SELECT
  USING (auth.uid() = id);

-- Política: Los administradores pueden ver todos los usuarios
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

-- Política: Los usuarios pueden actualizar su propio nombre/apellido (NO el rol)
DROP POLICY IF EXISTS "Los usuarios pueden actualizar su perfil" ON public.usuarios;
CREATE POLICY "Los usuarios pueden actualizar su perfil"
  ON public.usuarios
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND
    rol = (SELECT rol FROM public.usuarios WHERE id = auth.uid()) -- No puede cambiar su propio rol
  );

-- Política: Solo administradores pueden insertar usuarios
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

-- Política: Solo administradores pueden actualizar roles de otros usuarios
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

-- Política: Solo administradores pueden eliminar usuarios
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
-- MIGRAR USUARIOS EXISTENTES
-- ============================================================================
-- Insertar todos los usuarios existentes en auth.users a la tabla usuarios
-- Los usuarios que ya existen serán creados con rol 'usuario' por defecto
INSERT INTO public.usuarios (id, email, rol, activo)
SELECT
  id,
  email,
  'administrador', -- El primer usuario será administrador
  true
FROM auth.users
WHERE email IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- Nota: Después de ejecutar este script, deberías actualizar manualmente
-- el rol del usuario administrador principal desde la UI o con:
-- UPDATE public.usuarios SET rol = 'administrador' WHERE email = 'tu-email@ejemplo.com';
