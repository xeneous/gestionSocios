-- Limpiar provincias duplicadas
-- Solo mantener las primeras 27, eliminar el resto

DELETE FROM provincias 
WHERE id NOT IN (
  SELECT MIN(id) 
  FROM provincias 
  GROUP BY codigo
);

-- Verificar
SELECT COUNT(*) as total FROM provincias;
SELECT * FROM provincias ORDER BY codigo;
