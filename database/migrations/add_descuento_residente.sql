-- Agregar campos para descuento primer año de residentes
-- Ejecutar en Supabase SQL Editor

ALTER TABLE socios
ADD COLUMN IF NOT EXISTS descuento_primer_anio BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS fecha_fin_descuento DATE;

-- Comentarios descriptivos
COMMENT ON COLUMN socios.descuento_primer_anio IS 'Indica si el residente tiene descuento del 50% en el primer año';
COMMENT ON COLUMN socios.fecha_fin_descuento IS 'Fecha hasta la cual aplica el descuento del 50%';
