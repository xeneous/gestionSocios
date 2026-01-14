-- ============================================================================
-- DESHABILITAR ROW LEVEL SECURITY (RLS)
-- Fecha: 2026-01-13
-- Descripción: Deshabilita RLS en todas las tablas principales
-- ============================================================================
--
-- JUSTIFICACIÓN:
-- La aplicación Flutter maneja su propia autenticación y control de acceso.
-- No utiliza Supabase Auth, por lo tanto RLS no aporta seguridad adicional
-- y solo genera problemas de acceso.
--
-- SEGURIDAD:
-- - La API key (anon o service_role) debe mantenerse PRIVADA
-- - NUNCA exponer las keys en código cliente web
-- - La app Flutter es código nativo compilado, las keys no son fácilmente extraíbles
-- - Se recomienda implementar una capa de API intermedia para producción
--
-- ALTERNATIVAS FUTURAS:
-- 1. Migrar la autenticación de la app a Supabase Auth y re-habilitar RLS
-- 2. Implementar una API Gateway/Backend intermedio que use service_role
--    y exponga endpoints públicos con su propia autenticación
-- ============================================================================

-- Deshabilitar RLS en todas las tablas
ALTER TABLE public.socios DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cuentas_corrientes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.detalle_cuentas_corrientes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.valores_tesoreria DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.operaciones_detalle_valores_tesoreria DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.asientos_header DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.asientos_items DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.profesionales DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.conceptos DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.conceptos_socios DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.observaciones_socios DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.conceptos_tesoreria DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipos_comprobante_socios DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.tarjetas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.cuentas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.operaciones_contables DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.operaciones_detalle_cuentas_corrientes DISABLE ROW LEVEL SECURITY;

-- Eliminar todas las políticas existentes
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
            r.policyname, r.schemaname, r.tablename);
        RAISE NOTICE 'Política eliminada: % en tabla %', r.policyname, r.tablename;
    END LOOP;
END $$;

-- Verificar que RLS está deshabilitado
DO $$
DECLARE
    tabla_record RECORD;
    count_tablas INTEGER := 0;
    count_rls_disabled INTEGER := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'VERIFICACIÓN DE ROW LEVEL SECURITY (RLS)';
    RAISE NOTICE '============================================================';

    FOR tabla_record IN
        SELECT tablename, rowsecurity
        FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename IN (
            'socios',
            'cuentas_corrientes',
            'detalle_cuentas_corrientes',
            'valores_tesoreria',
            'operaciones_detalle_valores_tesoreria',
            'asientos_header',
            'asientos_items',
            'profesionales',
            'conceptos',
            'conceptos_socios',
            'observaciones_socios',
            'conceptos_tesoreria',
            'tipos_comprobante_socios',
            'tarjetas',
            'cuentas',
            'operaciones_contables',
            'operaciones_detalle_cuentas_corrientes'
        )
        ORDER BY tablename
    LOOP
        count_tablas := count_tablas + 1;

        IF tabla_record.rowsecurity = false THEN
            count_rls_disabled := count_rls_disabled + 1;
            RAISE NOTICE '✅ % - RLS DESHABILITADO', tabla_record.tablename;
        ELSE
            RAISE WARNING '❌ % - RLS TODAVÍA HABILITADO', tabla_record.tablename;
        END IF;
    END LOOP;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Total tablas procesadas: %', count_tablas;
    RAISE NOTICE 'Total tablas con RLS deshabilitado: %', count_rls_disabled;

    IF count_tablas = count_rls_disabled THEN
        RAISE NOTICE '✅ TODAS LAS TABLAS TIENEN RLS DESHABILITADO';
    ELSE
        RAISE WARNING '⚠️  ALGUNAS TABLAS TODAVÍA TIENEN RLS HABILITADO';
    END IF;
    RAISE NOTICE '============================================================';
END $$;

-- ============================================================================
-- FIN DE DESHABILITACIÓN RLS
-- ============================================================================
