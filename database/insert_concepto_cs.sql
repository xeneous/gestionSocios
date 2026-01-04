-- ============================================================================
-- Insertar concepto CS (Cuota Social)
-- ============================================================================
-- NOTA: El concepto tiene espacio al final para mantener consistencia
-- con el resto de la base de datos (VARCHAR(3) con padding)
-- ============================================================================

INSERT INTO public.conceptos (concepto, entidad, descripcion, modalidad, grupo, activo)
VALUES ('CS ', 0, 'Cuota Social', 'I', 'A', true)
ON CONFLICT (concepto) DO NOTHING;

-- Verificar
SELECT * FROM public.conceptos WHERE concepto = 'CS ';
