-- Crear tabla provincias basada en la estructura de SQL Server
CREATE TABLE IF NOT EXISTS provincias (
  id INTEGER PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL
);

-- Insertar provincias tal como están en SQL Server
INSERT INTO provincias (id, nombre) VALUES
(0, ''),
(1, 'BUENOS AIRES'),
(2, 'CIUDAD DE BS AS'),
(3, 'CORDOBA'),
(4, 'RIO NEGRO'),
(5, 'ENTRE RIOS'),
(6, 'CATAMARCA'),
(8, 'JUJUY'),
(9, 'SALTA'),
(10, 'SANTIAGO DEL ESTERO'),
(11, 'TIERRA DEL FUEGO'),
(12, 'CORRIENTES'),
(13, 'CHUBUT'),
(14, 'SANTA FE'),
(16, 'LA PAMPA'),
(17, 'CHACO'),
(18, 'LA RIOJA'),
(19, 'FORMOSA'),
(20, 'SAN JUAN'),
(21, 'SAN LUIS'),
(22, 'MENDOZA'),
(23, 'NEUQUEN'),
(24, 'SANTA CRUZ'),
(25, 'TUCUMAN'),
(26, 'MISIONES'),
(27, 'ISLAS MALVINAS'),
(28, 'TF ANTARTIDA ARGENTINA')
ON CONFLICT (id) DO NOTHING;

-- Verificar
SELECT COUNT(*) as total FROM provincias;
SELECT * FROM provincias WHERE id != 0 ORDER BY nombre;
