-- ============================================================================
-- FIX SECURITY LINTS - PARTE 1
-- Tablas que YA TIENEN policies pero RLS no está habilitado
-- Ejecutar primero esta parte
-- ============================================================================

ALTER TABLE public.compras_header ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.compras_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conceptos_profesionales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conceptos_socios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.observaciones_socios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operaciones_contables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operaciones_detalle_cuentas_corrientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operaciones_detalle_valores_tesoreria ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventas_header ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ventas_items ENABLE ROW LEVEL SECURITY;

-- Verificar
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'compras_header', 'compras_items', 'conceptos_profesionales',
    'conceptos_socios', 'observaciones_socios', 'operaciones_contables',
    'operaciones_detalle_cuentas_corrientes', 'operaciones_detalle_valores_tesoreria',
    'ventas_header', 'ventas_items'
  )
ORDER BY tablename;
