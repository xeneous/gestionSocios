-- ============================================================================
-- CUENTAS CORRIENTES - PARTE 1: Tablas de Referencia (Sin dependencias)
-- ============================================================================
-- Ejecutar esta parte PRIMERO

-- ----------------------------------------------------------------------------
-- TABLA: entidades
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entidades (
  id INTEGER PRIMARY KEY,
  descripcion VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by VARCHAR(100),
  updated_by VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_entidades_descripcion ON entidades(descripcion);

INSERT INTO entidades (id, descripcion) VALUES
  (0, 'Socios'),
  (1, 'Profesionales')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- TABLA: tipos_movimiento
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tipos_movimiento (
  id INTEGER PRIMARY KEY,
  descripcion VARCHAR(35) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by VARCHAR(100),
  updated_by VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_tipos_movimiento_descripcion ON tipos_movimiento(descripcion);

INSERT INTO tipos_movimiento (id, descripcion) VALUES
  (1, 'Debito'),
  (2, 'Credito'),
  (3, 'Informativo')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- TABLA: tipos_comprobante_socios
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tipos_comprobante_socios (
  comprobante VARCHAR(3) PRIMARY KEY NOT NULL,
  descripcion VARCHAR(30) NOT NULL,
  id_tipo_movimiento INTEGER REFERENCES tipos_movimiento(id),
  signo NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_by VARCHAR(100),
  updated_by VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_tipos_comprobante_descripcion ON tipos_comprobante_socios(descripcion);
CREATE INDEX IF NOT EXISTS idx_tipos_comprobante_tipo_mov ON tipos_comprobante_socios(id_tipo_movimiento);

INSERT INTO tipos_comprobante_socios (comprobante, descripcion, id_tipo_movimiento, signo) VALUES
  ('COB', 'Recibo de Caja', 2, -1),
  ('MAE', 'Maestria', 1, 1),
  ('CSV', 'Salud Visual', 1, 1)
ON CONFLICT (comprobante) DO NOTHING;

-- RLS para estas tablas
ALTER TABLE entidades ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_movimiento ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_comprobante_socios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Entidades son visibles para usuarios autenticados" ON entidades;
CREATE POLICY "Entidades son visibles para usuarios autenticados"
  ON entidades FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Tipos movimiento son visibles para usuarios autenticados" ON tipos_movimiento;
CREATE POLICY "Tipos movimiento son visibles para usuarios autenticados"
  ON tipos_movimiento FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Tipos comprobante son visibles para usuarios autenticados" ON tipos_comprobante_socios;
CREATE POLICY "Tipos comprobante son visibles para usuarios autenticados"
  ON tipos_comprobante_socios FOR SELECT
  TO authenticated
  USING (true);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_tipos_comprobante_socios_updated_at ON tipos_comprobante_socios;
CREATE TRIGGER update_tipos_comprobante_socios_updated_at BEFORE UPDATE ON tipos_comprobante_socios
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
