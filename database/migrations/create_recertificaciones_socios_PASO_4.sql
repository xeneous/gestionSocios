-- PASO 4: Habilitar RLS y crear políticas
-- Ejecutar DESPUÉS del Paso 3

ALTER TABLE recertificaciones_socios ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir lectura a usuarios autenticados" ON recertificaciones_socios
  FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Permitir inserción a usuarios autenticados" ON recertificaciones_socios
  FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Permitir actualización a usuarios autenticados" ON recertificaciones_socios
  FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Permitir eliminación a usuarios autenticados" ON recertificaciones_socios
  FOR DELETE
  USING (auth.role() = 'authenticated');
