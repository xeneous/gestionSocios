-- Crear tabla sexos para valores de referencia
CREATE TABLE IF NOT EXISTS sexos (
  id INTEGER PRIMARY KEY,
  descripcion VARCHAR(20) NOT NULL
);

-- Insertar valores de sexos
INSERT INTO sexos (id, descripcion) VALUES
(0, 'No informado'),
(1, 'Masculino'),
(2, 'Femenino')
ON CONFLICT (id) DO NOTHING;
