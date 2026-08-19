-- ============================================================================
-- FIX SECURITY LINTS - PARTE 3
-- Tablas activas (datos operativos)
-- Habilitar RLS + policy ALL para usuarios autenticados
-- ============================================================================

-- proveedores_new
ALTER TABLE public.proveedores_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.proveedores_new;
CREATE POLICY "Acceso autenticados" ON public.proveedores_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- clientes_new
ALTER TABLE public.clientes_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.clientes_new;
CREATE POLICY "Acceso autenticados" ON public.clientes_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- comp_prov_header_new
ALTER TABLE public.comp_prov_header_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.comp_prov_header_new;
CREATE POLICY "Acceso autenticados" ON public.comp_prov_header_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- comp_prov_items_new
ALTER TABLE public.comp_prov_items_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.comp_prov_items_new;
CREATE POLICY "Acceso autenticados" ON public.comp_prov_items_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- ven_cli_header_new
ALTER TABLE public.ven_cli_header_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.ven_cli_header_new;
CREATE POLICY "Acceso autenticados" ON public.ven_cli_header_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- ven_cli_items_new
ALTER TABLE public.ven_cli_items_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.ven_cli_items_new;
CREATE POLICY "Acceso autenticados" ON public.ven_cli_items_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- notas_imputacion_new
ALTER TABLE public.notas_imputacion_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.notas_imputacion_new;
CREATE POLICY "Acceso autenticados" ON public.notas_imputacion_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- notas_imputacion
ALTER TABLE public.notas_imputacion ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.notas_imputacion;
CREATE POLICY "Acceso autenticados" ON public.notas_imputacion
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- presentaciones_tarjetas
ALTER TABLE public.presentaciones_tarjetas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.presentaciones_tarjetas;
CREATE POLICY "Acceso autenticados" ON public.presentaciones_tarjetas
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- detalle_presentaciones_tarjetas
ALTER TABLE public.detalle_presentaciones_tarjetas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.detalle_presentaciones_tarjetas;
CREATE POLICY "Acceso autenticados" ON public.detalle_presentaciones_tarjetas
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- rechazos_tarjetas
ALTER TABLE public.rechazos_tarjetas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.rechazos_tarjetas;
CREATE POLICY "Acceso autenticados" ON public.rechazos_tarjetas
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- valores_tesoreria_new
ALTER TABLE public.valores_tesoreria_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.valores_tesoreria_new;
CREATE POLICY "Acceso autenticados" ON public.valores_tesoreria_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- operaciones_contables_new
ALTER TABLE public.operaciones_contables_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.operaciones_contables_new;
CREATE POLICY "Acceso autenticados" ON public.operaciones_contables_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- operaciones_detalle_valores_tesoreria_new
ALTER TABLE public.operaciones_detalle_valores_tesoreria_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.operaciones_detalle_valores_tesoreria_new;
CREATE POLICY "Acceso autenticados" ON public.operaciones_detalle_valores_tesoreria_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- asientos_header_new
ALTER TABLE public.asientos_header_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.asientos_header_new;
CREATE POLICY "Acceso autenticados" ON public.asientos_header_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- asientos_items_new
ALTER TABLE public.asientos_items_new ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.asientos_items_new;
CREATE POLICY "Acceso autenticados" ON public.asientos_items_new
  FOR ALL TO authenticated USING (auth.uid() IS NOT NULL) WITH CHECK (auth.uid() IS NOT NULL);

-- usuarios (ya tiene policies — solo habilitar si no está y refrescar)
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.usuarios;
-- No tocar las policies existentes de usuarios (fix_usuarios_rls_v2)
-- Verificar que existan las 4 policies (select/insert/update/delete)

SELECT 'Parte 3 OK - tablas activas' AS resultado;
