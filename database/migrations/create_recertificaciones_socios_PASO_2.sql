-- PASO 2: Crear índices
-- Ejecutar DESPUÉS del Paso 1

CREATE INDEX IF NOT EXISTS idx_recertificaciones_socio_id ON recertificaciones_socios(socio_id);
CREATE INDEX IF NOT EXISTS idx_recertificaciones_estado ON recertificaciones_socios(estado);
