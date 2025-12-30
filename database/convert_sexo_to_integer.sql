-- Convertir columna sexo de VARCHAR a INTEGER
-- Este script actualiza la columna sexo en la tabla socios para usar IDs numéricos

-- Paso 1: Agregar nueva columna temporal
ALTER TABLE socios ADD COLUMN IF NOT EXISTS sexo_new INTEGER;

-- Paso 2: Convertir valores existentes
-- Mapear valores string a números: 'M' -> 1, 'F' -> 2, otros -> 0
UPDATE socios 
SET sexo_new = CASE 
    WHEN sexo = 'M' OR sexo = '1' THEN 1
    WHEN sexo = 'F' OR sexo = '2' THEN 2
    ELSE 0
END
WHERE sexo IS NOT NULL;

-- Paso 3: Eliminar columna antigua
ALTER TABLE socios DROP COLUMN IF EXISTS sexo;

-- Paso 4: Renombrar nueva columna
ALTER TABLE socios RENAME COLUMN sexo_new TO sexo;

-- Paso 5: Establecer valor por defecto
ALTER TABLE socios ALTER COLUMN sexo SET DEFAULT 0;

-- Verificar cambios
SELECT 
    column_name, 
    data_type,
    column_default
FROM information_schema.columns 
WHERE table_name = 'socios' AND column_name = 'sexo';

-- Ver distribución de valores
SELECT sexo, COUNT(*) as cantidad
FROM socios
GROUP BY sexo
ORDER BY sexo;
