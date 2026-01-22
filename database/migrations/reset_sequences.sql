-- ============================================================================
-- RESET DE SECUENCIAS POST-MIGRACIÓN
-- ============================================================================
-- Este script debe ejecutarse DESPUÉS de cada migración para asegurar que
-- las secuencias de auto-incremento estén correctamente configuradas
-- ============================================================================

DO $$
DECLARE
    max_val BIGINT;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'RESETEANDO SECUENCIAS POST-MIGRACIÓN';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';

    -- valores_tesoreria
    SELECT COALESCE(MAX(id), 0) INTO max_val FROM valores_tesoreria;
    PERFORM setval('valores_tesoreria_id_seq', max_val + 1, false);
    RAISE NOTICE '✅ valores_tesoreria_id_seq -> % (max: %)', max_val + 1, max_val;

    -- cuentas_corrientes
    SELECT COALESCE(MAX(idtransaccion), 0) INTO max_val FROM cuentas_corrientes;
    PERFORM setval('cuentas_corrientes_idtransaccion_seq', max_val + 1, false);
    RAISE NOTICE '✅ cuentas_corrientes_idtransaccion_seq -> % (max: %)', max_val + 1, max_val;

    -- detalle_cuentas_corrientes (si tiene secuencia)
    BEGIN
        SELECT COALESCE(MAX(id), 0) INTO max_val FROM detalle_cuentas_corrientes;
        PERFORM setval('detalle_cuentas_corrientes_id_seq', max_val + 1, false);
        RAISE NOTICE '✅ detalle_cuentas_corrientes_id_seq -> % (max: %)', max_val + 1, max_val;
    EXCEPTION WHEN undefined_table OR undefined_column THEN
        RAISE NOTICE '⚠️  detalle_cuentas_corrientes no tiene secuencia id';
    END;

    -- socios
    SELECT COALESCE(MAX(id), 0) INTO max_val FROM socios;
    PERFORM setval('socios_id_seq', max_val + 1, false);
    RAISE NOTICE '✅ socios_id_seq -> % (max: %)', max_val + 1, max_val;

    -- tarjetas
    SELECT COALESCE(MAX(id), 0) INTO max_val FROM tarjetas;
    PERFORM setval('tarjetas_id_seq', max_val + 1, false);
    RAISE NOTICE '✅ tarjetas_id_seq -> % (max: %)', max_val + 1, max_val;

    -- asientos_header
    BEGIN
        SELECT COALESCE(MAX(id), 0) INTO max_val FROM asientos_header;
        PERFORM setval('asientos_header_id_seq', max_val + 1, false);
        RAISE NOTICE '✅ asientos_header_id_seq -> % (max: %)', max_val + 1, max_val;
    EXCEPTION WHEN undefined_object THEN
        RAISE NOTICE '⚠️  asientos_header_id_seq no existe';
    END;

    -- asientos_items
    BEGIN
        SELECT COALESCE(MAX(id), 0) INTO max_val FROM asientos_items;
        PERFORM setval('asientos_items_id_seq', max_val + 1, false);
        RAISE NOTICE '✅ asientos_items_id_seq -> % (max: %)', max_val + 1, max_val;
    EXCEPTION WHEN undefined_object THEN
        RAISE NOTICE '⚠️  asientos_items_id_seq no existe';
    END;

    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '✅ SECUENCIAS RESETEADAS CORRECTAMENTE';
    RAISE NOTICE '============================================================';
END $$;
