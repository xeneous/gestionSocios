-- ============================================================================
-- CUENTAS CORRIENTES - PARTE 3: Vistas
-- ============================================================================
-- Ejecutar DESPUÉS de la Parte 2

-- Vista de saldos por socio
DROP VIEW IF EXISTS vista_saldos_socios;
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
JOIN tipos_comprobante_socios tcs ON cc.tipo_comprobante = tcs.comprobante
WHERE cc.socio_id IS NOT NULL
GROUP BY socio_id;

-- Vista de saldos por profesional
DROP VIEW IF EXISTS vista_saldos_profesionales;
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
JOIN tipos_comprobante_socios tcs ON cc.tipo_comprobante = tcs.comprobante
WHERE cc.profesional_id IS NOT NULL
GROUP BY profesional_id;

-- Vista de detalle completo con joins (socios y profesionales)
DROP VIEW IF EXISTS vista_cuentas_corrientes_completa;
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
JOIN entidades e ON cc.entidad_id = e.id
JOIN tipos_comprobante_socios tcs ON cc.tipo_comprobante = tcs.comprobante
LEFT JOIN tipos_movimiento tm ON tcs.id_tipo_movimiento = tm.id;

-- Vista de detalle items con info del concepto
DROP VIEW IF EXISTS vista_detalle_cc_completa;
CREATE OR REPLACE VIEW vista_detalle_cc_completa AS
SELECT
  dcc.*,
  c.descripcion AS concepto_descripcion,
  c.modalidad,
  c.grupo
FROM detalle_cuentas_corrientes dcc
JOIN conceptos c ON dcc.concepto = c.concepto;
