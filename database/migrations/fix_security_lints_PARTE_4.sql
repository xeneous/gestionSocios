-- ============================================================================
-- FIX SECURITY LINTS - PARTE 4
-- Tablas de backup (solo lectura para usuarios autenticados)
-- Estas tablas son backups históricos — no se modifican desde la app
-- ============================================================================

-- socios_bak
ALTER TABLE public.socios_bak ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.socios_bak;
CREATE POLICY "Acceso autenticados" ON public.socios_bak
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

-- Backups 0308
ALTER TABLE public.comp_prov_header_bak_0308 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.comp_prov_header_bak_0308;
CREATE POLICY "Acceso autenticados" ON public.comp_prov_header_bak_0308
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.comp_prov_items_bak_0308 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.comp_prov_items_bak_0308;
CREATE POLICY "Acceso autenticados" ON public.comp_prov_items_bak_0308
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.valores_tesoreria_bak_0308 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.valores_tesoreria_bak_0308;
CREATE POLICY "Acceso autenticados" ON public.valores_tesoreria_bak_0308
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.asientos_header_bak_0308 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.asientos_header_bak_0308;
CREATE POLICY "Acceso autenticados" ON public.asientos_header_bak_0308
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.asientos_items_bak_0308 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.asientos_items_bak_0308;
CREATE POLICY "Acceso autenticados" ON public.asientos_items_bak_0308
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.notas_imputacion_bak_0308 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.notas_imputacion_bak_0308;
CREATE POLICY "Acceso autenticados" ON public.notas_imputacion_bak_0308
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.operaciones_contables_bak_0308 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.operaciones_contables_bak_0308;
CREATE POLICY "Acceso autenticados" ON public.operaciones_contables_bak_0308
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.operaciones_detalle_bak_0308 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.operaciones_detalle_bak_0308;
CREATE POLICY "Acceso autenticados" ON public.operaciones_detalle_bak_0308
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

-- Backups 0703
ALTER TABLE public.proveedores_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.proveedores_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.proveedores_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.clientes_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.clientes_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.clientes_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.comp_prov_header_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.comp_prov_header_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.comp_prov_header_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.comp_prov_items_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.comp_prov_items_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.comp_prov_items_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.ven_cli_header_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.ven_cli_header_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.ven_cli_header_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.ven_cli_items_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.ven_cli_items_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.ven_cli_items_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.valores_tesoreria_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.valores_tesoreria_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.valores_tesoreria_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.notas_imputacion_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.notas_imputacion_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.notas_imputacion_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.operaciones_contables_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.operaciones_contables_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.operaciones_contables_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.operaciones_detalle_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.operaciones_detalle_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.operaciones_detalle_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.asientos_header_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.asientos_header_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.asientos_header_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

ALTER TABLE public.asientos_items_bak_0703 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso autenticados" ON public.asientos_items_bak_0703;
CREATE POLICY "Acceso autenticados" ON public.asientos_items_bak_0703
  FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

SELECT 'Parte 4 OK - tablas de backup' AS resultado;
