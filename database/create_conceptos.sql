-- Crear tabla conceptos en Supabase
-- Basado en estructura SQL Server

CREATE TABLE IF NOT EXISTS conceptos (
  id serial PRIMARY KEY,
  concepto varchar(3) NOT NULL UNIQUE,
  entidad smallint DEFAULT 0,
  descripcion varchar(100),
  modalidad varchar(1),
  importe numeric(10,2),
  grupo varchar(1),
  activo boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  cuenta_contable int
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_conceptos_concepto ON conceptos(concepto);
CREATE INDEX IF NOT EXISTS idx_conceptos_entidad ON conceptos(entidad);

-- Comentarios
COMMENT ON TABLE conceptos IS 'Maestro de conceptos: cuota social, seguros, cursos, etc.';
COMMENT ON COLUMN conceptos.concepto IS 'Código de 3 caracteres del concepto (CS, RMP, C20, etc.)';
COMMENT ON COLUMN conceptos.entidad IS '0=SAO, 1=FUNDOSA';
COMMENT ON COLUMN conceptos.descripcion IS 'Descripción del concepto';
COMMENT ON COLUMN conceptos.modalidad IS 'I=Individual, etc.';
