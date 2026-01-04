-- ============================================================================
-- Insertar tipo de comprobante CS (Cuota Social)
-- ============================================================================
-- NOTA: El comprobante tiene espacio al final para mantener consistencia
-- con el resto de la base de datos (VARCHAR(3) con padding)
-- ============================================================================

INSERT INTO public.tipos_comprobante_socios (comprobante, descripcion)
VALUES ('CS ', 'Cuota Social')
ON CONFLICT (comprobante) DO NOTHING;

-- Verificar
SELECT * FROM public.tipos_comprobante_socios WHERE comprobante = 'CS ';
