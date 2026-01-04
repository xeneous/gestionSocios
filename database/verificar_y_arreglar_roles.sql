-- ============================================================================
-- SCRIPT DE VERIFICACIÓN Y CORRECCIÓN DE ROLES
-- ============================================================================

-- PASO 1: Verificar si la tabla usuarios existe
SELECT EXISTS (
   SELECT FROM information_schema.tables
   WHERE table_schema = 'public'
   AND table_name = 'usuarios'
);
-- Si retorna 'false', ejecutá primero EJECUTAR_PRIMERO_usuarios.sql

-- PASO 2: Ver usuarios en auth.users
SELECT id, email, created_at
FROM auth.users
ORDER BY created_at;

-- PASO 3: Ver usuarios en public.usuarios
SELECT id, email, rol, activo, created_at
FROM public.usuarios
ORDER BY created_at;

-- PASO 4: Si la tabla existe pero está vacía, insertar usuarios existentes
INSERT INTO public.usuarios (id, email, rol, activo)
SELECT
  id,
  email,
  'administrador', -- Todos serán administradores
  true
FROM auth.users
WHERE email IS NOT NULL
  AND id NOT IN (SELECT id FROM public.usuarios) -- Solo los que no existen
ON CONFLICT (id) DO NOTHING;

-- PASO 5: Actualizar tu usuario específico a administrador
-- REEMPLAZA 'tu-email@example.com' con tu email real
UPDATE public.usuarios
SET rol = 'administrador'
WHERE email = 'admin@saov2.com'; -- <-- CAMBIA ESTO POR TU EMAIL

-- PASO 6: Verificar el resultado
SELECT id, email, rol, activo
FROM public.usuarios
WHERE email = 'admin@saov2.com'; -- <-- CAMBIA ESTO POR TU EMAIL

-- PASO 7: Agregar constraint para supervisor si no existe
ALTER TABLE public.usuarios
DROP CONSTRAINT IF EXISTS usuarios_rol_check;

ALTER TABLE public.usuarios
ADD CONSTRAINT usuarios_rol_check
CHECK (rol IN ('usuario', 'contable', 'supervisor', 'administrador'));

-- ============================================================================
-- RESULTADO ESPERADO
-- ============================================================================
-- Deberías ver tu usuario con:
-- - id: (tu UUID)
-- - email: tu-email@example.com
-- - rol: administrador
-- - activo: true
