-- =============================================================================
-- Migración: presentaciones_tarjetas + rechazos_tarjetas
-- Ejecutar en Supabase SQL Editor
-- RLS: NO habilitar hasta verificar funcionamiento
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. detalle_presentaciones_tarjetas
--    Una fila por socio/profesional incluido en una presentación DA.
--    Equivale a la tabla presentacionestarjetas de MSSQL.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS detalle_presentaciones_tarjetas (
  id            bigserial       PRIMARY KEY,
  tarjeta_id    int             NOT NULL,    -- 1=Visa, 2=Mastercard (ver tabla tarjetas)
  periodo       int             NOT NULL,    -- YYYYMM (ej: 202602)
  socio_id      int             NOT NULL,    -- id del socio o profesional
  entidad_id    int             NOT NULL DEFAULT 0,  -- 0=socio, 1=profesional
  importe       numeric(15,2)   NOT NULL,
  numero_tarjeta varchar(20),               -- número de tarjeta al momento de presentar
  created_at    timestamptz     NOT NULL DEFAULT now()
);

COMMENT ON TABLE  detalle_presentaciones_tarjetas                IS 'Historial de ítems incluidos en cada presentación de débito automático';
COMMENT ON COLUMN detalle_presentaciones_tarjetas.tarjeta_id     IS '1=Visa, 2=Mastercard (FK a tarjetas.id)';
COMMENT ON COLUMN detalle_presentaciones_tarjetas.periodo        IS 'Período YYYYMM de la presentación';
COMMENT ON COLUMN detalle_presentaciones_tarjetas.socio_id       IS 'ID del socio o profesional (discriminado por entidad_id)';
COMMENT ON COLUMN detalle_presentaciones_tarjetas.entidad_id     IS '0=socio, 1=profesional';
COMMENT ON COLUMN detalle_presentaciones_tarjetas.numero_tarjeta IS 'Número de tarjeta al momento de la presentación (antes de posibles actualizaciones)';

CREATE INDEX IF NOT EXISTS idx_det_presentaciones_tarjeta_periodo
  ON detalle_presentaciones_tarjetas(tarjeta_id, periodo);

CREATE INDEX IF NOT EXISTS idx_det_presentaciones_socio_periodo
  ON detalle_presentaciones_tarjetas(socio_id, entidad_id, periodo);

-- -----------------------------------------------------------------------------
-- 2. rechazos_tarjetas
--    Una fila por rechazo procesado (Visa o Mastercard).
--    Agrega el motivo que no existe en cuentas_corrientes.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rechazos_tarjetas (
  id              bigserial       PRIMARY KEY,
  tarjeta_id      int             NOT NULL,    -- 1=Visa, 2=Mastercard (ver tabla tarjetas)
  periodo         int             NOT NULL,    -- YYYYMM del DA original
  socio_id        int             NOT NULL,
  entidad_id      int             NOT NULL DEFAULT 0,
  importe         numeric(15,2)   NOT NULL,
  numero_tarjeta  varchar(20),
  motivo          text,
  fecha_rechazo   date,
  created_at      timestamptz     NOT NULL DEFAULT now()
);

COMMENT ON TABLE  rechazos_tarjetas              IS 'Historial de rechazos de débito automático con código y descripción del motivo';
COMMENT ON COLUMN rechazos_tarjetas.tarjeta_id   IS '1=Visa, 2=Mastercard (FK a tarjetas.id)';
COMMENT ON COLUMN rechazos_tarjetas.periodo      IS 'Período YYYYMM del DA original que fue rechazado';
COMMENT ON COLUMN rechazos_tarjetas.motivo       IS 'Código y descripción del rechazo según el archivo de la tarjeta';
COMMENT ON COLUMN rechazos_tarjetas.fecha_rechazo IS 'Fecha de la presentación original (para Visa: del archivo; para MC: ingresada por usuario)';

CREATE INDEX IF NOT EXISTS idx_rechazos_tarjeta_periodo
  ON rechazos_tarjetas(tarjeta_id, periodo);

CREATE INDEX IF NOT EXISTS idx_rechazos_socio_periodo
  ON rechazos_tarjetas(socio_id, entidad_id, periodo);
