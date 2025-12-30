-- Insertar tarjeta con ID 0 para casos NULL
-- Ejecutar ANTES de migrar los socios

INSERT INTO tarjetas (id, codigo, descripcion) 
VALUES (0, '0', 'Sin tarjeta / No informada')
ON CONFLICT (id) DO NOTHING;

-- Resetear la secuencia de tarjetas para que empiece desde 1
SELECT setval(pg_get_serial_sequence('tarjetas', 'id'), 
    GREATEST(1, (SELECT COALESCE(MAX(id), 0) + 1 FROM tarjetas WHERE id > 0))
);

-- Verificar
SELECT * FROM tarjetas ORDER BY id;
