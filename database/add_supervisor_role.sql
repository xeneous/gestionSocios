-- ============================================================================
-- AGREGAR ROL SUPERVISOR
-- ============================================================================
-- Este script agrega el rol 'supervisor' a la tabla usuarios

-- Modificar el constraint para incluir el nuevo rol
ALTER TABLE public.usuarios
DROP CONSTRAINT IF EXISTS usuarios_rol_check;

ALTER TABLE public.usuarios
ADD CONSTRAINT usuarios_rol_check
CHECK (rol IN ('usuario', 'contable', 'supervisor', 'administrador'));

-- Verificación
SELECT DISTINCT rol FROM public.usuarios ORDER BY rol;
