-- ============================================================================
-- CUENTAS CORRIENTES - PARTE 2: Tablas Principales (SIN CHECK CONSTRAINT)
-- ============================================================================
-- Ejecutar DESPUÉS de la Parte 1 y verificar que existan las tablas:
-- - socios
-- - profesionales
-- - conceptos
-- - entidades
-- - tipos_comprobante_socios

-- ----------------------------------------------------------------------------
-- TABLA: cuentas_corrientes (HEADER)
-- Puede referenciar a socios (entidad_id=0) o profesionales (entidad_id=1)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cuentas_corrientes (
  idtransaccion BIGSERIAL PRIMARY KEY,
  socio_id INTEGER,
  profesional_id INTEGER,
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

-- Índices
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_socio ON cuentas_corrientes(socio_id);
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_profesional ON cuentas_corrientes(profesional_id);
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_fecha ON cuentas_corrientes(fecha);
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_entidad ON cuentas_corrientes(entidad_id);
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_tipo_comp ON cuentas_corrientes(tipo_comprobante);
CREATE INDEX IF NOT EXISTS idx_cuentas_corrientes_documento ON cuentas_corrientes(documento_numero);

-- Agregar FKs después (para evitar error si profesionales no existe)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'socios') THEN
        ALTER TABLE cuentas_corrientes DROP CONSTRAINT IF EXISTS fk_cuentas_corrientes_socio;
        ALTER TABLE cuentas_corrientes
        ADD CONSTRAINT fk_cuentas_corrientes_socio
        FOREIGN KEY (socio_id) REFERENCES socios(id) ON DELETE CASCADE;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profesionales') THEN
        ALTER TABLE cuentas_corrientes DROP CONSTRAINT IF EXISTS fk_cuentas_corrientes_profesional;
        ALTER TABLE cuentas_corrientes
        ADD CONSTRAINT fk_cuentas_corrientes_profesional
        FOREIGN KEY (profesional_id) REFERENCES profesionales(id) ON DELETE CASCADE;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- TABLA: detalle_cuentas_corrientes (DETAIL/ITEMS)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS detalle_cuentas_corrientes (
  idtransaccion BIGINT NOT NULL REFERENCES cuentas_corrientes(idtransaccion) ON DELETE CASCADE,
  item INTEGER NOT NULL,
  concepto VARCHAR(3) NOT NULL REFERENCES conceptos(concepto),
  cantidad NUMERIC(10,2) DEFAULT 1,
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

-- RLS
ALTER TABLE cuentas_corrientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE detalle_cuentas_corrientes ENABLE ROW LEVEL SECURITY;

-- Policies para cuentas_corrientes
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver cuentas corrientes" ON cuentas_corrientes;
CREATE POLICY "Usuarios autenticados pueden ver cuentas corrientes"
  ON cuentas_corrientes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar cuentas corrientes" ON cuentas_corrientes;
CREATE POLICY "Usuarios autenticados pueden insertar cuentas corrientes"
  ON cuentas_corrientes FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar cuentas corrientes" ON cuentas_corrientes;
CREATE POLICY "Usuarios autenticados pueden actualizar cuentas corrientes"
  ON cuentas_corrientes FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar cuentas corrientes" ON cuentas_corrientes;
CREATE POLICY "Usuarios autenticados pueden eliminar cuentas corrientes"
  ON cuentas_corrientes FOR DELETE
  TO authenticated
  USING (true);

-- Policies para detalle_cuentas_corrientes
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver detalle cuentas corrientes" ON detalle_cuentas_corrientes;
CREATE POLICY "Usuarios autenticados pueden ver detalle cuentas corrientes"
  ON detalle_cuentas_corrientes FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar detalle cuentas corrientes" ON detalle_cuentas_corrientes;
CREATE POLICY "Usuarios autenticados pueden insertar detalle cuentas corrientes"
  ON detalle_cuentas_corrientes FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar detalle cuentas corrientes" ON detalle_cuentas_corrientes;
CREATE POLICY "Usuarios autenticados pueden actualizar detalle cuentas corrientes"
  ON detalle_cuentas_corrientes FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar detalle cuentas corrientes" ON detalle_cuentas_corrientes;
CREATE POLICY "Usuarios autenticados pueden eliminar detalle cuentas corrientes"
  ON detalle_cuentas_corrientes FOR DELETE
  TO authenticated
  USING (true);

-- Triggers
DROP TRIGGER IF EXISTS update_cuentas_corrientes_updated_at ON cuentas_corrientes;
CREATE TRIGGER update_cuentas_corrientes_updated_at BEFORE UPDATE ON cuentas_corrientes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_detalle_cuentas_corrientes_updated_at ON detalle_cuentas_corrientes;
CREATE TRIGGER update_detalle_cuentas_corrientes_updated_at BEFORE UPDATE ON detalle_cuentas_corrientes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Agregar CHECK constraint al final (opcional, validar en la app)
-- ALTER TABLE cuentas_corrientes DROP CONSTRAINT IF EXISTS check_entidad_referencia;
-- ALTER TABLE cuentas_corrientes
-- ADD CONSTRAINT check_entidad_referencia CHECK (
--   (entidad_id = 0 AND socio_id IS NOT NULL AND profesional_id IS NULL) OR
--   (entidad_id = 1 AND profesional_id IS NOT NULL AND socio_id IS NULL)
-- );
