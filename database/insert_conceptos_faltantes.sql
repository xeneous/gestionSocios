-- ============================================================================
-- INSERTAR CONCEPTOS FALTANTES
-- ============================================================================
-- Ejecutar este script en Supabase para agregar los conceptos que existen
-- en cuentas corrientes pero no están en la tabla conceptos

-- Conceptos faltantes: SUN, IC

INSERT INTO conceptos (concepto, descripcion, importe, modalidad, grupo) VALUES
  ('SUN', 'Seguros Unidos', 0, 'M', 1),  -- Asumiendo modalidad Mensual y grupo 1
  ('IC', 'Ingreso por Concepto', 0, 'M', 1)  -- Asumiendo modalidad Mensual y grupo 1
ON CONFLICT (concepto) DO UPDATE SET
  descripcion = EXCLUDED.descripcion,
  importe = EXCLUDED.importe,
  modalidad = EXCLUDED.modalidad,
  grupo = EXCLUDED.grupo;

-- Verificar los conceptos insertados
SELECT concepto, descripcion
FROM conceptos
WHERE concepto IN ('SUN', 'IC')
ORDER BY concepto;
