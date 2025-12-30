-- PASO 1: Insertar tarjeta con ID=0 (crítico para socios sin tarjeta)
INSERT INTO tarjetas (id, codigo, descripcion)
VALUES (0, 0, 'Sin tarjeta')
ON CONFLICT (id) DO NOTHING;

-- PASO 2: Crear tabla sexos si no existe
CREATE TABLE IF NOT EXISTS sexos (
  id INTEGER PRIMARY KEY,
  descripcion VARCHAR(50) NOT NULL
);

INSERT INTO sexos (id, descripcion) VALUES
(0, 'No informado'),
(1, 'Masculino'),
(2, 'Femenino')
ON CONFLICT (id) DO NOTHING;

-- VERIFICACIÓN
SELECT 'tarjeta_0' as item, COUNT(*) as count FROM tarjetas WHERE id = 0
UNION ALL
SELECT 'sexos', COUNT(*) FROM sexos;
