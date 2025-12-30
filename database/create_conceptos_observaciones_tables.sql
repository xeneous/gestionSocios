-- ============================================
-- CREAR TABLAS PARA CONCEPTOS Y OBSERVACIONES
-- Ejecutar en Supabase SQL Editor
-- ============================================

-- 1. Tabla CONCEPTOS (maestro)
CREATE TABLE IF NOT EXISTS conceptos (
  id serial PRIMARY KEY,
  concepto varchar(3) NOT NULL UNIQUE,
  entidad smallint DEFAULT 0,
  descripcion varchar(100),
  modalidad varchar(1),
  importe numeric(10,2),
  mes int,
  ano int,
  imputacion_contable int,
  seguro int,
  grupo varchar(1),
  concepto_muni varchar(3),
  modalidad_muni varchar(1),
  importe_muni numeric(10,2),
  cobertura numeric(10,2),
  comision numeric(10,2),
  id_cobertura int,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conceptos_concepto ON conceptos(concepto);
CREATE INDEX IF NOT EXISTS idx_conceptos_entidad ON conceptos(entidad);

COMMENT ON TABLE conceptos IS 'Maestro de conceptos: cuota social, seguros, cursos, etc.';

-- 2. Tabla CONCEPTOS_SOCIOS (relación socio-concepto)
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

CREATE INDEX IF NOT EXISTS idx_conceptos_socios_socio ON conceptos_socios(socio_id);
CREATE INDEX IF NOT EXISTS idx_conceptos_socios_concepto ON conceptos_socios(concepto);
CREATE INDEX IF NOT EXISTS idx_conceptos_socios_activo ON conceptos_socios(socio_id, activo);
CREATE INDEX IF NOT EXISTS idx_conceptos_socios_fecha_alta ON conceptos_socios(fecha_alta DESC);

COMMENT ON TABLE conceptos_socios IS 'Conceptos asignados a cada socio (cuota social, seguros, etc.)';

-- 3. Tabla OBSERVACIONES_SOCIOS (historial de interacciones)
CREATE TABLE IF NOT EXISTS observaciones_socios (
  id serial PRIMARY KEY,
  socio_id int NOT NULL REFERENCES socios(id) ON DELETE CASCADE,
  fecha timestamptz NOT NULL DEFAULT now(),
  observacion text NOT NULL,
  usuario varchar(100),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_observaciones_socios_socio ON observaciones_socios(socio_id);
CREATE INDEX IF NOT EXISTS idx_observaciones_socios_fecha ON observaciones_socios(socio_id, fecha DESC);

COMMENT ON TABLE observaciones_socios IS 'Historial de observaciones e interacciones con socios';

-- Verificar que se crearon correctamente
SELECT 'Tabla conceptos creada' as status, COUNT(*) as registros FROM conceptos
UNION ALL
SELECT 'Tabla conceptos_socios creada', COUNT(*) FROM conceptos_socios
UNION ALL
SELECT 'Tabla observaciones_socios creada', COUNT(*) FROM observaciones_socios;
