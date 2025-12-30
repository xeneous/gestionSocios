-- Verificar y crear tablas de referencia necesarias

-- Tabla sexos
CREATE TABLE IF NOT EXISTS sexos (
  id INTEGER PRIMARY KEY,
  descripcion VARCHAR(20) NOT NULL
);

-- Insertar valores de sexos si no existen
INSERT INTO sexos (id, descripcion) VALUES
(0, 'No informado'),
(1, 'Masculino'),
(2, 'Femenino')
ON CONFLICT (id) DO NOTHING;

-- Tabla paises (si no existe)
CREATE TABLE IF NOT EXISTS paises (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  codigo VARCHAR(10)
);

-- Insertar Argentina como país por defecto
INSERT INTO paises (id, nombre, codigo) VALUES
(1, 'Argentina', 'AR')
ON CONFLICT (id) DO NOTHING;

-- Verificar datos
SELECT 'sexos' as tabla, COUNT(*) as registros FROM sexos
UNION ALL
SELECT 'provincias', COUNT(*) FROM provincias
UNION ALL
SELECT 'paises', COUNT(*) FROM paises;
