-- Tabla de recertificaciones de socios
-- Ejecutar en Supabase SQL Editor

CREATE TABLE IF NOT EXISTS recertificaciones_socios (
  id SERIAL PRIMARY KEY,
  socio_id INTEGER NOT NULL REFERENCES socios(id) ON DELETE CASCADE,
  fecha_recertificacion DATE NOT NULL,
  titulo VARCHAR(200) NOT NULL,
  estado VARCHAR(20) NOT NULL CHECK (estado IN ('Iniciada', 'En proceso', 'Finalizada')),

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para consultas por socio
CREATE INDEX IF NOT EXISTS idx_recertificaciones_socio_id ON recertificaciones_socios(socio_id);

-- Índice para consultas por estado
CREATE INDEX IF NOT EXISTS idx_recertificaciones_estado ON recertificaciones_socios(estado);

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_recertificaciones_socios_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS recertificaciones_socios_updated_at ON recertificaciones_socios;
CREATE TRIGGER recertificaciones_socios_updated_at
  BEFORE UPDATE ON recertificaciones_socios
  FOR EACH ROW
  EXECUTE FUNCTION update_recertificaciones_socios_updated_at();

-- Habilitar RLS
ALTER TABLE recertificaciones_socios ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON recertificaciones_socios;
DROP POLICY IF EXISTS "Permitir inserción a usuarios autenticados" ON recertificaciones_socios;
DROP POLICY IF EXISTS "Permitir actualización a usuarios autenticados" ON recertificaciones_socios;
DROP POLICY IF EXISTS "Permitir eliminación a usuarios autenticados" ON recertificaciones_socios;

CREATE POLICY "Permitir lectura a usuarios autenticados" ON recertificaciones_socios
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Permitir inserción a usuarios autenticados" ON recertificaciones_socios
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Permitir actualización a usuarios autenticados" ON recertificaciones_socios
  FOR UPDATE
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Permitir eliminación a usuarios autenticados" ON recertificaciones_socios
  FOR DELETE
  USING (auth.uid() IS NOT NULL);
