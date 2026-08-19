-- ============================================================================
-- FIX URGENTE - PARTE 1B
-- PARTE_1 habilitó RLS en 10 tablas que ya tenían policies de escritura
-- (INSERT/UPDATE/DELETE) pero NINGUNA de lectura (SELECT). Resultado: esas
-- 10 tablas quedaron con SELECT bloqueado para todo el mundo (rompe
-- rechazos, recibos, compras, ventas y todo lo que las lea).
-- Agrega la policy de SELECT que faltaba, con el mismo patrón que ya usa
-- el proyecto (ver create_archivos_socios.sql / implementar_rls_completo.sql).
-- ============================================================================

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.compras_header;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.compras_header FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.compras_items;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.compras_items FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.conceptos_profesionales;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.conceptos_profesionales FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.conceptos_socios;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.conceptos_socios FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.observaciones_socios;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.observaciones_socios FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.operaciones_contables;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.operaciones_contables FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.operaciones_detalle_cuentas_corrientes;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.operaciones_detalle_cuentas_corrientes FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.operaciones_detalle_valores_tesoreria;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.operaciones_detalle_valores_tesoreria FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.ventas_header;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.ventas_header FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.ventas_items;
CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.ventas_items FOR SELECT TO authenticated USING (auth.uid() IS NOT NULL);

-- Verificar: debe haber 4 policies por tabla (lectura + las 3 que ya existían)
SELECT tablename, COUNT(*) AS cantidad_policies
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'compras_header', 'compras_items', 'conceptos_profesionales',
    'conceptos_socios', 'observaciones_socios', 'operaciones_contables',
    'operaciones_detalle_cuentas_corrientes', 'operaciones_detalle_valores_tesoreria',
    'ventas_header', 'ventas_items'
  )
GROUP BY tablename
ORDER BY tablename;
