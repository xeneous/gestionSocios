-- Crear tabla observaciones_socios en Supabase
-- Historial de interacciones con cada socio

CREATE TABLE IF NOT EXISTS observaciones_socios (
  id serial PRIMARY KEY,
  socio_id int NOT NULL REFERENCES socios(id) ON DELETE CASCADE,
  fecha timestamptz NOT NULL DEFAULT now(),
  observacion text NOT NULL,
  usuario varchar(100),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Índices para consultas eficientes
CREATE INDEX IF NOT EXISTS idx_observaciones_socios_socio ON observaciones_socios(socio_id);
CREATE INDEX IF NOT EXISTS idx_observaciones_socios_fecha ON observaciones_socios(socio_id, fecha DESC);

-- Comentarios
COMMENT ON TABLE observaciones_socios IS 'Historial de observaciones e interacciones con socios';
COMMENT ON COLUMN observaciones_socios.socio_id IS 'ID del socio';
COMMENT ON COLUMN observaciones_socios.fecha IS 'Fecha y hora de la observación';
COMMENT ON COLUMN observaciones_socios.observacion IS 'Texto de la observación';
COMMENT ON COLUMN observaciones_socios.usuario IS 'Usuario que registró la observación';
