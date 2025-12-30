-- Crear tabla conceptos_socios en Supabase
-- Relación entre socios y conceptos con fechas de alta/baja

CREATE TABLE IF NOT EXISTS conceptos_socios (
  id serial PRIMARY KEY,
  socio_id int NOT NULL REFERENCES socios(id) ON DELETE CASCADE,
  concepto varchar(3) NOT NULL REFERENCES conceptos(concepto),
  fecha_alta date,
  fecha_vigencia date,
  importe numeric(10,2),
  fecha_baja date,
  motivo_baja int,
  activo boolean DEFAULT true,
  cuotas int,
  moneda int,
  id_campo_tarjeta int,
  rechazos int DEFAULT 0,
  presentadas int DEFAULT 0,
  tipo_cambio numeric(10,4),
  valor_origen numeric(10,2),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Índices para consultas eficientes
CREATE INDEX IF NOT EXISTS idx_conceptos_socios_socio ON conceptos_socios(socio_id);
CREATE INDEX IF NOT EXISTS idx_conceptos_socios_concepto ON conceptos_socios(concepto);
CREATE INDEX IF NOT EXISTS idx_conceptos_socios_activo ON conceptos_socios(socio_id, activo);
CREATE INDEX IF NOT EXISTS idx_conceptos_socios_fecha_alta ON conceptos_socios(fecha_alta DESC);

-- Comentarios
COMMENT ON TABLE conceptos_socios IS 'Conceptos asignados a cada socio (cuota social, seguros, etc.)';
COMMENT ON COLUMN conceptos_socios.socio_id IS 'ID del socio';
COMMENT ON COLUMN conceptos_socios.concepto IS 'Código del concepto (CS, RMP, etc.)';
COMMENT ON COLUMN conceptos_socios.fecha_alta IS 'Fecha de alta del concepto para este socio';
COMMENT ON COLUMN conceptos_socios.fecha_baja IS 'Fecha de baja (NULL = activo)';
COMMENT ON COLUMN conceptos_socios.activo IS 'true si está activo (fecha_baja IS NULL)';
