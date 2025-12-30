-- Verificar que tarjetas existen en Supabase
SELECT id, codigo, descripcion FROM tarjetas ORDER BY id;

-- Verificar si existe tarjeta con ID=0
SELECT * FROM tarjetas WHERE id = 0;

-- Ver cuántas tarjetas hay
SELECT COUNT(*) as total_tarjetas FROM tarjetas;
