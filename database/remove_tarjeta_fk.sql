-- Quitar temporalmente el foreign key constraint de tarjeta_id
-- para permitir migrar socios con tarjeta_id que no existan

ALTER TABLE socios 
DROP CONSTRAINT IF EXISTS socios_tarjeta_id_fkey;

-- Verificar
SELECT conname 
FROM pg_constraint 
WHERE conrelid = 'socios'::regclass;
