-- ============================================================================
-- FIX SECURITY LINTS - PARTE 5
-- Recrear vistas sin SECURITY DEFINER
-- En PostgreSQL 15+ (Supabase), CREATE OR REPLACE no quita SECURITY DEFINER
-- si ya estaba puesto. Hay que hacer DROP + CREATE.
-- ============================================================================

-- IMPORTANTE: Las vistas dependen de tablas que YA deben tener RLS habilitado
-- (ejecutar partes 1-4 antes de esta)

-- Eliminar vistas en orden correcto (por dependencias)
DROP VIEW IF EXISTS vista_saldos_socios CASCADE;
DROP VIEW IF EXISTS vista_saldos_profesionales CASCADE;
DROP VIEW IF EXISTS vista_cuentas_corrientes_completa CASCADE;
DROP VIEW IF EXISTS vista_detalle_cc_completa CASCADE;

-- ============================================================================
-- VISTA: vista_saldos_socios
-- ============================================================================
CREATE VIEW public.vista_saldos_socios
WITH (security_invoker = true)
AS
SELECT
  socio_id,
  SUM(CASE
    WHEN tcs.signo = 1 THEN cc.importe
    WHEN tcs.signo = -1 THEN -cc.importe
    ELSE 0
  END) AS saldo_total,
  SUM(cc.cancelado) AS total_cancelado,
  SUM(CASE
    WHEN tcs.signo = 1 THEN cc.importe
    WHEN tcs.signo = -1 THEN -cc.importe
    ELSE 0
  END) - SUM(cc.cancelado) AS saldo_pendiente,
  COUNT(*) AS total_transacciones
FROM cuentas_corrientes cc
LEFT JOIN tipos_comprobante_socios tcs ON cc.tipo_comprobante = tcs.comprobante
WHERE cc.socio_id IS NOT NULL
GROUP BY socio_id;

-- ============================================================================
-- VISTA: vista_saldos_profesionales
-- ============================================================================
CREATE VIEW public.vista_saldos_profesionales
WITH (security_invoker = true)
AS
SELECT
  profesional_id,
  SUM(CASE
    WHEN tcs.signo = 1 THEN cc.importe
    WHEN tcs.signo = -1 THEN -cc.importe
    ELSE 0
  END) AS saldo_total,
  SUM(cc.cancelado) AS total_cancelado,
  SUM(CASE
    WHEN tcs.signo = 1 THEN cc.importe
    WHEN tcs.signo = -1 THEN -cc.importe
    ELSE 0
  END) - SUM(cc.cancelado) AS saldo_pendiente,
  COUNT(*) AS total_transacciones
FROM cuentas_corrientes cc
LEFT JOIN tipos_comprobante_socios tcs ON cc.tipo_comprobante = tcs.comprobante
WHERE cc.profesional_id IS NOT NULL
GROUP BY profesional_id;

-- ============================================================================
-- VISTA: vista_cuentas_corrientes_completa
-- ============================================================================
CREATE VIEW public.vista_cuentas_corrientes_completa
WITH (security_invoker = true)
AS
SELECT
  cc.*,
  CASE
    WHEN cc.socio_id IS NOT NULL THEN s.apellido || ', ' || s.nombre
    WHEN cc.profesional_id IS NOT NULL THEN p.apellido || ', ' || p.nombre
  END AS entidad_nombre,
  e.descripcion AS entidad_descripcion,
  tcs.descripcion AS tipo_comprobante_descripcion,
  tm.descripcion AS tipo_movimiento,
  tcs.signo
FROM cuentas_corrientes cc
LEFT JOIN socios s ON cc.socio_id = s.id
LEFT JOIN profesionales p ON cc.profesional_id = p.id
LEFT JOIN entidades e ON cc.entidad_id = e.id
LEFT JOIN tipos_comprobante_socios tcs ON cc.tipo_comprobante = tcs.comprobante
LEFT JOIN tipos_movimiento tm ON tcs.id_tipo_movimiento = tm.id;

-- ============================================================================
-- VISTA: vista_detalle_cc_completa
-- ============================================================================
CREATE VIEW public.vista_detalle_cc_completa
WITH (security_invoker = true)
AS
SELECT
  dcc.*,
  c.descripcion AS concepto_descripcion,
  c.modalidad,
  c.grupo
FROM detalle_cuentas_corrientes dcc
LEFT JOIN conceptos c ON dcc.concepto = c.concepto;

-- Verificar que no tengan SECURITY DEFINER
SELECT
  schemaname,
  viewname,
  definition
FROM pg_views
WHERE schemaname = 'public'
  AND viewname IN (
    'vista_saldos_socios',
    'vista_saldos_profesionales',
    'vista_cuentas_corrientes_completa',
    'vista_detalle_cc_completa'
  );

SELECT 'Parte 5 OK - vistas recreadas sin SECURITY DEFINER' AS resultado;
