-- Agregar columna categoria_residente a socios
ALTER TABLE socios
ADD COLUMN IF NOT EXISTS categoria_residente VARCHAR(2) REFERENCES categorias_residente(codigo);

COMMENT ON COLUMN socios.categoria_residente IS 'Categoría de residente (R1, R2, R3) - determina el descuento en cuota social';

-- Renombrar fecha_fin_descuento a fecha_fin_residencia (más descriptivo)
ALTER TABLE socios RENAME COLUMN fecha_fin_descuento TO fecha_fin_residencia;

COMMENT ON COLUMN socios.fecha_fin_residencia IS 'Fecha de fin de la residencia';

-- Migrar datos existentes
UPDATE socios SET categoria_residente = 'R1' WHERE residente = true AND descuento_primer_anio = true;
UPDATE socios SET categoria_residente = 'R3' WHERE residente = true AND (descuento_primer_anio = false OR descuento_primer_anio IS NULL);

-- Eliminar columna obsoleta (después de verificar que la migración funcionó)
-- ALTER TABLE socios DROP COLUMN IF EXISTS descuento_primer_anio;
