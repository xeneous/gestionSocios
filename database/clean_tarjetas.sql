-- Limpiar tabla tarjetas (excepto si hay socios que la referencian)
DELETE FROM tarjetas;

-- Verificar que quedó vacía
SELECT COUNT(*) FROM tarjetas;
