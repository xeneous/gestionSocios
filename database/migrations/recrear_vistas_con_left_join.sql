-- ============================================================================
-- RECREAR VISTAS CON LEFT JOIN EN LUGAR DE INNER JOIN
-- ============================================================================
-- Esto soluciona el problema de registros que no aparecen cuando
-- tipo_comprobante no existe en tipos_comprobante_socios
-- ============================================================================

-- Eliminar vistas existentes
DROP VIEW IF EXISTS vista_saldos_socios CASCADE;
DROP VIEW IF EXISTS vista_saldos_profesionales CASCADE;
DROP VIEW IF EXISTS vista_cuentas_corrientes_completa CASCADE;
DROP VIEW IF EXISTS vista_detalle_cc_completa CASCADE;

-- ============================================================================
-- VISTA DE SALDOS POR SOCIO
-- ============================================================================
CREATE OR REPLACE VIEW vista_saldos_socios AS
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
-- VISTA DE SALDOS POR PROFESIONAL
-- ============================================================================
CREATE OR REPLACE VIEW vista_saldos_profesionales AS
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
-- VISTA DE CUENTAS CORRIENTES COMPLETA
-- ============================================================================
CREATE OR REPLACE VIEW vista_cuentas_corrientes_completa AS
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
-- VISTA DE DETALLE COMPLETO
-- ============================================================================
CREATE OR REPLACE VIEW vista_detalle_cc_completa AS
SELECT
  dcc.*,
  c.descripcion AS concepto_descripcion,
  c.modalidad,
  c.grupo
FROM detalle_cuentas_corrientes dcc
LEFT JOIN conceptos c ON dcc.concepto = c.concepto;

-- ============================================================================
-- VERIFICAR VISTAS CREADAS
-- ============================================================================
SELECT
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'VIEW'
  AND table_name LIKE 'vista%'
ORDER BY table_name;

-- ============================================================================
-- FIN
-- ============================================================================
