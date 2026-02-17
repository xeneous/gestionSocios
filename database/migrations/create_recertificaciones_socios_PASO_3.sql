-- PASO 3: Crear trigger para updated_at
-- Ejecutar DESPUÉS del Paso 2

CREATE OR REPLACE FUNCTION update_recertificaciones_socios_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER recertificaciones_socios_updated_at
  BEFORE UPDATE ON recertificaciones_socios
  FOR EACH ROW
  EXECUTE FUNCTION update_recertificaciones_socios_updated_at();
