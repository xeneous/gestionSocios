-- ============================================================================
-- FIX: AGREGAR SECUENCIA PARA AUTOGENERAR ID EN VALORES_TESORERIA
-- ============================================================================

-- Crear secuencia para valores_tesoreria
CREATE SEQUENCE IF NOT EXISTS public.valores_tesoreria_id_seq;

-- Obtener el máximo ID actual
DO $$
DECLARE
  max_id INTEGER;
BEGIN
  SELECT COALESCE(MAX(id), 0) INTO max_id FROM public.valores_tesoreria;
  PERFORM setval('public.valores_tesoreria_id_seq', max_id);
END $$;

-- Establecer la secuencia como default para la columna id
ALTER TABLE public.valores_tesoreria
  ALTER COLUMN id SET DEFAULT nextval('public.valores_tesoreria_id_seq');

-- Asignar la secuencia a la columna (para que se elimine si se elimina la columna)
ALTER SEQUENCE public.valores_tesoreria_id_seq OWNED BY public.valores_tesoreria.id;

-- Verificar
SELECT
  column_name,
  column_default,
  data_type
FROM information_schema.columns
WHERE table_name = 'valores_tesoreria'
  AND column_name = 'id';
