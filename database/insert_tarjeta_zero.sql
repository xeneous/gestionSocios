-- Insertar tarjeta con ID=0 para socios sin tarjeta
INSERT INTO tarjetas (id, codigo, descripcion)
VALUES (0, 0, 'Sin tarjeta')
ON CONFLICT (id) DO NOTHING;

-- Verificar
SELECT * FROM tarjetas WHERE id = 0;
