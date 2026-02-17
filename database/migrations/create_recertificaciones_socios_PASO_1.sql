-- PASO 1: Crear la tabla
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
