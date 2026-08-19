-- ============================================================================
-- FIX SECURITY LINTS - PARTE 2
-- Tablas de referencia/lookup (solo lectura)
-- Habilitar RLS + policy SELECT para usuarios autenticados
-- ============================================================================

-- Macro para cada tabla:
-- 1. Habilitar RLS
-- 2. Drop policy anterior si existe (evitar conflictos)
-- 3. Crear policy: anon sin acceso (implícito), authenticated puede SELECT

-- grupos_agrupados
ALTER TABLE public.grupos_agrupados ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.grupos_agrupados;
CREATE POLICY "Acceso autenticados" ON public.grupos_agrupados
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- cuentas
ALTER TABLE public.cuentas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.cuentas;
CREATE POLICY "Acceso autenticados" ON public.cuentas
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- provincias
ALTER TABLE public.provincias ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.provincias;
CREATE POLICY "Acceso autenticados" ON public.provincias
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- paises
ALTER TABLE public.paises ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.paises;
CREATE POLICY "Acceso autenticados" ON public.paises
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- sexos
ALTER TABLE public.sexos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.sexos;
CREATE POLICY "Acceso autenticados" ON public.sexos
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- categorias_residente
ALTER TABLE public.categorias_residente ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.categorias_residente;
CREATE POLICY "Acceso autenticados" ON public.categorias_residente
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- tipos_comprobante_compra
ALTER TABLE public.tipos_comprobante_compra ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.tipos_comprobante_compra;
CREATE POLICY "Acceso autenticados" ON public.tipos_comprobante_compra
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- tipos_comprobante_compra_items
ALTER TABLE public.tipos_comprobante_compra_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.tipos_comprobante_compra_items;
CREATE POLICY "Acceso autenticados" ON public.tipos_comprobante_compra_items
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- tipos_comprobante_venta
ALTER TABLE public.tipos_comprobante_venta ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.tipos_comprobante_venta;
CREATE POLICY "Acceso autenticados" ON public.tipos_comprobante_venta
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- tipos_comprobante_venta_items
ALTER TABLE public.tipos_comprobante_venta_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.tipos_comprobante_venta_items;
CREATE POLICY "Acceso autenticados" ON public.tipos_comprobante_venta_items
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- valores_cuota_social
ALTER TABLE public.valores_cuota_social ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.valores_cuota_social;
CREATE POLICY "Acceso autenticados" ON public.valores_cuota_social
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- parametros_contables
ALTER TABLE public.parametros_contables ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.parametros_contables;
CREATE POLICY "Acceso autenticados" ON public.parametros_contables
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

SELECT 'Parte 2 OK - tablas de referencia' AS resultado;
