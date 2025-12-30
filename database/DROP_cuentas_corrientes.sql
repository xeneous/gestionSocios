-- ============================================================================
-- LIMPIAR TABLAS DE CUENTAS CORRIENTES
-- ============================================================================
-- Ejecutar ANTES de crear las tablas nuevamente

-- Eliminar vistas primero (dependen de las tablas)
DROP VIEW IF EXISTS vista_detalle_cc_completa CASCADE;
DROP VIEW IF EXISTS vista_cuentas_corrientes_completa CASCADE;
DROP VIEW IF EXISTS vista_saldos_profesionales CASCADE;
DROP VIEW IF EXISTS vista_saldos_socios CASCADE;

-- Eliminar tablas (CASCADE elimina constraints automáticamente)
DROP TABLE IF EXISTS detalle_cuentas_corrientes CASCADE;
DROP TABLE IF EXISTS cuentas_corrientes CASCADE;

-- NO eliminar estas tablas de referencia:
-- DROP TABLE IF EXISTS tipos_comprobante_socios CASCADE;
-- DROP TABLE IF EXISTS tipos_movimiento CASCADE;
-- DROP TABLE IF EXISTS entidades CASCADE;
