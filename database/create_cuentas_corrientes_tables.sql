-- ============================================================================
-- CUENTAS CORRIENTES DE SOCIOS - MIGRACIÓN SQL SERVER → POSTGRESQL
-- ============================================================================
-- Fecha: 2025-12-29
-- Descripción: Tablas para gestionar cuentas corrientes con patrón header-detail
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TABLA: entidades
-- Define qué tipo de entidad maneja la cuenta corriente (Socios, Profesionales)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entidades (
  id INTEGER PRIMARY KEY,
  descripcion VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by VARCHAR(100),
  updated_by VARCHAR(100)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_entidades_descripcion ON entidades(descripcion);

-- Datos iniciales
INSERT INTO entidades (id, descripcion) VALUES
  (0, 'Socios'),
  (1, 'Profesionales')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- TABLA: tipos_movimiento
-- Define la naturaleza del movimiento (Débito, Crédito, Informativo)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tipos_movimiento (
  id INTEGER PRIMARY KEY,
  descripcion VARCHAR(35) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by VARCHAR(100),
  updated_by VARCHAR(100)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_tipos_movimiento_descripcion ON tipos_movimiento(descripcion);

-- Datos iniciales
INSERT INTO tipos_movimiento (id, descripcion) VALUES
  (1, 'Debito'),
  (2, 'Credito'),
  (3, 'Informativo')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- TABLA: tipos_comprobante_socios
-- Define los tipos de comprobantes (COB, MAE, CSV, etc.)
-- Origen SQL Server: comprobantescuentascorrientes
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tipos_comprobante_socios (
  comprobante VARCHAR(3) PRIMARY KEY NOT NULL,
  descripcion VARCHAR(30) NOT NULL,
  id_tipo_movimiento INTEGER REFERENCES tipos_movimiento(id),
  signo NUMERIC,  -- 1 = aumenta deuda, -1 = disminuye deuda
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by VARCHAR(100),
  updated_by VARCHAR(100)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_tipos_comprobante_descripcion ON tipos_comprobante_socios(descripcion);
CREATE INDEX IF NOT EXISTS idx_tipos_comprobante_tipo_mov ON tipos_comprobante_socios(id_tipo_movimiento);

-- Datos iniciales
INSERT INTO tipos_comprobante_socios (comprobante, descripcion, id_tipo_movimiento, signo) VALUES
  ('COB', 'Recibo de Caja', 2, -1),  -- Crédito: paga → disminuye deuda
  ('MAE', 'Maestria', 1, 1),          -- Débito: cargo → aumenta deuda
  ('CSV', 'Salud Visual', 1, 1)       -- Débito: cargo → aumenta deuda
ON CONFLICT (comprobante) DO NOTHING;

-- ----------------------------------------------------------------------------
-- TABLA: cuentas_corrientes (HEADER)
-- Representa cada transacción en la cuenta corriente
-- Origen SQL Server: cuentascorrientes
-- CAMBIOS:
--   - "concepto" → "tipo_comprobante" (evita confusión con tabla conceptos)
--   - Se eliminaron: Cobrador, Serie, idCancelada, idOpCobrador, rg1, rg2, rg3
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cuentas_corrientes (
  idtransaccion BIGSERIAL PRIMARY KEY,
  socio_id INTEGER NOT NULL REFERENCES socios(id) ON DELETE CASCADE,
  entidad_id INTEGER NOT NULL REFERENCES entidades(id),
  fecha DATE NOT NULL,
  tipo_comprobante VARCHAR(3) NOT NULL REFERENCES tipos_comprobante_socios(comprobante),
  punto_venta VARCHAR(14),
  documento_numero VARCHAR(14),
  fecha_rendicion DATE,
  rendicion VARCHAR(20),
  importe NUMERIC(18,2),
  cancelado NUMERIC(18,2) DEFAULT 0,
  vencimiento DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by VARCHAR(100),
  updated_by VARCHAR(100)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_socio ON cuentas_corrientes(socio_id);
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_fecha ON cuentas_corrientes(fecha);
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_entidad ON cuentas_corrientes(entidad_id);
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_tipo_comp ON cuentas_corrientes(tipo_comprobante);
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_documento ON cuentas_corrientes(documento_numero);

-- ----------------------------------------------------------------------------
-- TABLA: detalle_cuentas_corrientes (DETAIL/ITEMS)
-- Cada item dentro de una transacción (concepto facturado)
-- Origen SQL Server: detallecuentascorrientes
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS detalle_cuentas_corrientes (
  idtransaccion BIGINT NOT NULL REFERENCES cuentas_corrientes(idtransaccion) ON DELETE CASCADE,
  item INTEGER NOT NULL,
  concepto VARCHAR(3) NOT NULL REFERENCES conceptos(concepto),
  cantidad NUMERIC(10,2) DEFAULT 1,  -- Por ahora siempre 1
  importe NUMERIC(18,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by VARCHAR(100),
  updated_by VARCHAR(100),
  PRIMARY KEY (idtransaccion, item)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_detalle_cc_transaccion ON detalle_cuentas_corrientes(idtransaccion);
CREATE INDEX IF NOT EXISTS idx_detalle_cc_concepto ON detalle_cuentas_corrientes(concepto);

-- ----------------------------------------------------------------------------
-- RLS POLICIES (Row Level Security)
-- ----------------------------------------------------------------------------

-- Habilitar RLS
ALTER TABLE entidades ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_movimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_comprobante_socios ENABLE ROW LEVEL SECURITY;
ALTER TABLE cuentas_corrientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE detalle_cuentas_corrientes ENABLE ROW LEVEL SECURITY;

-- Entidades (solo lectura)
CREATE POLICY "Entidades son visibles para usuarios autenticados"
  ON entidades FOR SELECT
  TO authenticated
  USING (true);

-- Tipos movimiento (solo lectura)
CREATE POLICY "Tipos movimiento son visibles para usuarios autenticados"
  ON tipos_movimiento FOR SELECT
  TO authenticated
  USING (true);

-- Tipos comprobante (solo lectura)
CREATE POLICY "Tipos comprobante son visibles para usuarios autenticados"
  ON tipos_comprobante_socios FOR SELECT
  TO authenticated
  USING (true);

-- Cuentas corrientes (CRUD completo)
CREATE POLICY "Usuarios autenticados pueden ver cuentas corrientes"
  ON cuentas_corrientes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios autenticados pueden insertar cuentas corrientes"
  ON cuentas_corrientes FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden actualizar cuentas corrientes"
  ON cuentas_corrientes FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden eliminar cuentas corrientes"
  ON cuentas_corrientes FOR DELETE
  TO authenticated
  USING (true);

-- Detalle cuentas corrientes (CRUD completo)
CREATE POLICY "Usuarios autenticados pueden ver detalle cuentas corrientes"
  ON detalle_cuentas_corrientes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios autenticados pueden insertar detalle cuentas corrientes"
  ON detalle_cuentas_corrientes FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden actualizar detalle cuentas corrientes"
  ON detalle_cuentas_corrientes FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Usuarios autenticados pueden eliminar detalle cuentas corrientes"
  ON detalle_cuentas_corrientes FOR DELETE
  TO authenticated
  USING (true);

-- ----------------------------------------------------------------------------
-- TRIGGERS para updated_at automático
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_tipos_comprobante_socios_updated_at BEFORE UPDATE ON tipos_comprobante_socios
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cuentas_corrientes_updated_at BEFORE UPDATE ON cuentas_corrientes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_detalle_cuentas_corrientes_updated_at BEFORE UPDATE ON detalle_cuentas_corrientes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- VISTAS ÚTILES
-- ----------------------------------------------------------------------------

-- Vista de saldos por socio
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
GROUP BY socio_id;

-- Vista de detalle completo con joins
CREATE OR REPLACE VIEW vista_cuentas_corrientes_completa AS
SELECT
  cc.*,
  s.apellido || ', ' || s.nombre AS socio_nombre,
  e.descripcion AS entidad_descripcion,
  tcs.descripcion AS tipo_comprobante_descripcion,
  tm.descripcion AS tipo_movimiento,
  tcs.signo
FROM cuentas_corrientes cc
JOIN socios s ON cc.socio_id = s.id
JOIN entidades e ON cc.entidad_id = e.id
JOIN tipos_comprobante_socios tcs ON cc.tipo_comprobante = tcs.comprobante
LEFT JOIN tipos_movimiento tm ON tcs.id_tipo_movimiento = tm.id;

-- Vista de detalle items con info del concepto
CREATE OR REPLACE VIEW vista_detalle_cc_completa AS
SELECT
  dcc.*,
  c.descripcion AS concepto_descripcion,
  c.modalidad,
  c.grupo
FROM detalle_cuentas_corrientes dcc
JOIN conceptos c ON dcc.concepto = c.concepto;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
