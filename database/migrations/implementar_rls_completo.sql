-- ============================================================================
-- IMPLEMENTACIÓN DE ROW LEVEL SECURITY (RLS)
-- Fecha: 2026-01-07
-- Descripción: Habilita RLS en todas las tablas principales para protección
-- ============================================================================

-- ============================================================================
-- POLÍTICA DE SEGURIDAD:
-- - Usuarios anónimos (anon): SIN ACCESO a ninguna tabla
-- - Usuarios autenticados (authenticated): LECTURA en todas las tablas
-- - Service role: ACCESO COMPLETO (usado por la aplicación Flutter)
-- ============================================================================

-- ============================================================================
-- CUENTAS CORRIENTES
-- ============================================================================

ALTER TABLE public.cuentas_corrientes ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes si existen
DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.cuentas_corrientes;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.cuentas_corrientes;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.cuentas_corrientes;

-- Crear nuevas políticas
CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.cuentas_corrientes
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.cuentas_corrientes
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.cuentas_corrientes
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- DETALLE CUENTAS CORRIENTES
-- ============================================================================

ALTER TABLE public.detalle_cuentas_corrientes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.detalle_cuentas_corrientes;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.detalle_cuentas_corrientes;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.detalle_cuentas_corrientes;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.detalle_cuentas_corrientes
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.detalle_cuentas_corrientes
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.detalle_cuentas_corrientes
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- VALORES TESORERIA
-- ============================================================================

ALTER TABLE public.valores_tesoreria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.valores_tesoreria;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.valores_tesoreria;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.valores_tesoreria;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.valores_tesoreria
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.valores_tesoreria
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.valores_tesoreria
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- ASIENTOS HEADER
-- ============================================================================

ALTER TABLE public.asientos_header ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.asientos_header;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.asientos_header;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.asientos_header;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.asientos_header
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.asientos_header
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.asientos_header
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- ASIENTOS ITEMS
-- ============================================================================

ALTER TABLE public.asientos_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.asientos_items;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.asientos_items;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.asientos_items;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.asientos_items
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.asientos_items
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.asientos_items
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- SOCIOS
-- ============================================================================

ALTER TABLE public.socios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.socios;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.socios;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.socios;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.socios
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.socios
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.socios
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- PROFESIONALES
-- ============================================================================

ALTER TABLE public.profesionales ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.profesionales;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.profesionales;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.profesionales;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.profesionales
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.profesionales
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.profesionales
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- CONCEPTOS
-- ============================================================================

ALTER TABLE public.conceptos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.conceptos;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.conceptos;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.conceptos;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.conceptos
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.conceptos
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.conceptos
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- CONCEPTOS TESORERIA
-- ============================================================================

ALTER TABLE public.conceptos_tesoreria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.conceptos_tesoreria;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.conceptos_tesoreria;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.conceptos_tesoreria;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.conceptos_tesoreria
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.conceptos_tesoreria
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.conceptos_tesoreria
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- TIPOS COMPROBANTE SOCIOS
-- ============================================================================

ALTER TABLE public.tipos_comprobante_socios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.tipos_comprobante_socios;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.tipos_comprobante_socios;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.tipos_comprobante_socios;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.tipos_comprobante_socios
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.tipos_comprobante_socios
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.tipos_comprobante_socios
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- TARJETAS
-- ============================================================================

ALTER TABLE public.tarjetas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.tarjetas;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.tarjetas;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.tarjetas;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.tarjetas
  FOR ALL
  TO anon
  USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.tarjetas
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.tarjetas
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- RESUMEN Y VERIFICACIÓN
-- ============================================================================

DO $$
DECLARE
    tabla_record RECORD;
    count_tablas INTEGER := 0;
    count_rls_enabled INTEGER := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'VERIFICACIÓN DE ROW LEVEL SECURITY (RLS)';
    RAISE NOTICE '============================================================';

    FOR tabla_record IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename IN (
            'cuentas_corrientes',
            'detalle_cuentas_corrientes',
            'valores_tesoreria',
            'asientos_header',
            'asientos_items',
            'socios',
            'profesionales',
            'conceptos',
            'conceptos_tesoreria',
            'tipos_comprobante_socios',
            'tarjetas'
        )
        ORDER BY tablename
    LOOP
        count_tablas := count_tablas + 1;

        -- Verificar si RLS está habilitado
        IF EXISTS (
            SELECT 1
            FROM pg_tables
            WHERE schemaname = 'public'
            AND tablename = tabla_record.tablename
            AND rowsecurity = true
        ) THEN
            count_rls_enabled := count_rls_enabled + 1;
            RAISE NOTICE '✅ % - RLS HABILITADO', tabla_record.tablename;
        ELSE
            RAISE WARNING '❌ % - RLS NO HABILITADO', tabla_record.tablename;
        END IF;
    END LOOP;

    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Total tablas procesadas: %', count_tablas;
    RAISE NOTICE 'Total tablas con RLS: %', count_rls_enabled;

    IF count_tablas = count_rls_enabled THEN
        RAISE NOTICE '✅ TODAS LAS TABLAS TIENEN RLS HABILITADO';
    ELSE
        RAISE WARNING '⚠️  ALGUNAS TABLAS NO TIENEN RLS HABILITADO';
    END IF;
    RAISE NOTICE '============================================================';
END $$;

-- ============================================================================
-- FIN DE IMPLEMENTACIÓN RLS
-- ============================================================================
