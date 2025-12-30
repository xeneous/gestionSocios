-- Agregar columnas faltantes a la tabla socios
-- Este script es idempotente (se puede ejecutar múltiples veces sin problemas)

-- Columnas de contacto
ALTER TABLE socios ADD COLUMN IF NOT EXISTS celular VARCHAR(50);
ALTER TABLE socios ADD COLUMN IF NOT EXISTS telefono_secundario VARCHAR(50);
ALTER TABLE socios ADD COLUMN IF NOT EXISTS email_alternativo VARCHAR(100);

-- Columnas de domicilio
ALTER TABLE socios ADD COLUMN IF NOT EXISTS pais_id INTEGER;

-- Columnas profesionales
ALTER TABLE socios ADD COLUMN IF NOT EXISTS matricula_nacional VARCHAR(50);
ALTER TABLE socios ADD COLUMN IF NOT EXISTS matricula_provincial VARCHAR(50);
ALTER TABLE socios ADD COLUMN IF NOT EXISTS grupo_desde DATE;
ALTER TABLE socios ADD COLUMN IF NOT EXISTS fecha_inicio_residencia DATE;

-- Columnas de débito automático
ALTER TABLE socios ADD COLUMN IF NOT EXISTS adherido_debito BOOLEAN DEFAULT false;
ALTER TABLE socios ADD COLUMN IF NOT EXISTS numero_tarjeta VARCHAR(16);
ALTER TABLE socios ADD COLUMN IF NOT EXISTS vencimiento_tarjeta DATE;
ALTER TABLE socios ADD COLUMN IF NOT EXISTS debitar_desde DATE;

-- Verificar columnas agregadas
SELECT 
    column_name, 
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'socios' 
ORDER BY ordinal_position;
