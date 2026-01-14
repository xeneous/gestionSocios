-- ============================================================================
-- SCRIPT DE LIMPIEZA PARA RE-MIGRACIÓN
-- Fecha: 2026-01-13
-- Descripción: Limpia las tablas respetando integridad referencial
-- IMPORTANTE: Este script BORRA TODOS LOS DATOS de las siguientes tablas:
--   - asientos_header
--   - asientos_items
--   - operaciones_detalle_valores_tesoreria
--   - valores_tesoreria
--   - operaciones_detalle_cuentas_corrientes
--   - detalle_cuentas_corrientes
--   - cuentas_corrientes
--   - cuentas
--   - conceptos_socios
--   - observaciones_socios
--   - socios
-- ============================================================================

-- Verificar que estamos usando la base de datos correcta
DO $$
BEGIN
    RAISE NOTICE 'Iniciando limpieza de tablas para re-migración...';
END $$;

-- ============================================================================
-- PASO 1: Eliminar datos en orden correcto (de dependientes a padres)
-- ============================================================================

DO $$
BEGIN
    -- 1.1 Limpiar asientos_items (depende de asientos_header)
    DELETE FROM public.asientos_items;
    RAISE NOTICE '✅ Tabla asientos_items limpiada';

    -- 1.2 Limpiar asientos_header
    DELETE FROM public.asientos_header;
    RAISE NOTICE '✅ Tabla asientos_header limpiada';

    -- 1.3 Limpiar operaciones_detalle_valores_tesoreria (depende de valores_tesoreria)
    DELETE FROM public.operaciones_detalle_valores_tesoreria;
    RAISE NOTICE '✅ Tabla operaciones_detalle_valores_tesoreria limpiada';

    -- 1.4 Limpiar valores_tesoreria (depende de idtransaccion_origen)
    DELETE FROM public.valores_tesoreria;
    RAISE NOTICE '✅ Tabla valores_tesoreria limpiada';

    -- 1.5 Limpiar operaciones_detalle_cuentas_corrientes (depende de cuentas_corrientes)
    DELETE FROM public.operaciones_detalle_cuentas_corrientes;
    RAISE NOTICE '✅ Tabla operaciones_detalle_cuentas_corrientes limpiada';

    -- 1.6 Limpiar detalle_cuentas_corrientes (depende de cuentas_corrientes)
    DELETE FROM public.detalle_cuentas_corrientes;
    RAISE NOTICE '✅ Tabla detalle_cuentas_corrientes limpiada';

    -- 1.7 Limpiar cuentas_corrientes (tabla padre)
    DELETE FROM public.cuentas_corrientes;
    RAISE NOTICE '✅ Tabla cuentas_corrientes limpiada';

    -- 1.8 Limpiar cuentas (plan de cuentas contable)
    DELETE FROM public.cuentas;
    RAISE NOTICE '✅ Tabla cuentas limpiada';

    -- 1.9 Limpiar conceptos_socios (depende de socios)
    DELETE FROM public.conceptos_socios;
    RAISE NOTICE '✅ Tabla conceptos_socios limpiada';

    -- 1.10 Limpiar observaciones_socios (depende de socios)
    DELETE FROM public.observaciones_socios;
    RAISE NOTICE '✅ Tabla observaciones_socios limpiada';

    -- 1.11 Limpiar socios (tabla padre)
    DELETE FROM public.socios WHERE id != 0;
    RAISE NOTICE '✅ Tabla socios limpiada';
END $$;

-- ============================================================================
-- PASO 2: Resetear secuencias (si existen)
-- ============================================================================

-- Resetear secuencia de valores_tesoreria si existe
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_sequences WHERE schemaname = 'public' AND sequencename = 'valores_tesoreria_id_seq') THEN
        PERFORM setval('public.valores_tesoreria_id_seq', 1, false);
        RAISE NOTICE '✅ Secuencia valores_tesoreria_id_seq reseteada';
    END IF;
END $$;

-- ============================================================================
-- PASO 3: Verificar limpieza
-- ============================================================================

DO $$
DECLARE
    count_asientos_header INTEGER;
    count_asientos_items INTEGER;
    count_operaciones_detalle_vt INTEGER;
    count_valores INTEGER;
    count_operaciones_detalle_cc INTEGER;
    count_detalle_cc INTEGER;
    count_cc INTEGER;
    count_conceptos_socios INTEGER;
    count_observaciones_socios INTEGER;
    count_socios INTEGER;
BEGIN
    SELECT COUNT(*) INTO count_asientos_header FROM public.asientos_header;
    SELECT COUNT(*) INTO count_asientos_items FROM public.asientos_items;
    SELECT COUNT(*) INTO count_operaciones_detalle_vt FROM public.operaciones_detalle_valores_tesoreria;
    SELECT COUNT(*) INTO count_valores FROM public.valores_tesoreria;
    SELECT COUNT(*) INTO count_operaciones_detalle_cc FROM public.operaciones_detalle_cuentas_corrientes;
    SELECT COUNT(*) INTO count_detalle_cc FROM public.detalle_cuentas_corrientes;
    SELECT COUNT(*) INTO count_cc FROM public.cuentas_corrientes;
    SELECT COUNT(*) INTO count_conceptos_socios FROM public.conceptos_socios;
    SELECT COUNT(*) INTO count_observaciones_socios FROM public.observaciones_socios;
    SELECT COUNT(*) INTO count_socios FROM public.socios WHERE id != 0;

    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'VERIFICACIÓN DE LIMPIEZA:';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'asientos_header: % registros', count_asientos_header;
    RAISE NOTICE 'asientos_items: % registros', count_asientos_items;
    RAISE NOTICE 'operaciones_detalle_valores_tesoreria: % registros', count_operaciones_detalle_vt;
    RAISE NOTICE 'valores_tesoreria: % registros', count_valores;
    RAISE NOTICE 'operaciones_detalle_cuentas_corrientes: % registros', count_operaciones_detalle_cc;
    RAISE NOTICE 'detalle_cuentas_corrientes: % registros', count_detalle_cc;
    RAISE NOTICE 'cuentas_corrientes: % registros', count_cc;
    RAISE NOTICE 'conceptos_socios: % registros', count_conceptos_socios;
    RAISE NOTICE 'observaciones_socios: % registros', count_observaciones_socios;
    RAISE NOTICE 'socios: % registros', count_socios;
    RAISE NOTICE '============================================================';

    IF count_asientos_header = 0 AND count_asientos_items = 0 AND
       count_operaciones_detalle_vt = 0 AND count_valores = 0 AND
       count_operaciones_detalle_cc = 0 AND count_detalle_cc = 0 AND
       count_cc = 0 AND count_conceptos_socios = 0 AND
       count_observaciones_socios = 0 AND count_socios = 0 THEN
        RAISE NOTICE '✅ TODAS LAS TABLAS LIMPIADAS EXITOSAMENTE';
    ELSE
        RAISE WARNING '⚠️  ADVERTENCIA: Algunas tablas aún tienen datos';
    END IF;
    RAISE NOTICE '============================================================';
END $$;

-- ============================================================================
-- FIN DEL SCRIPT DE LIMPIEZA
-- ============================================================================
