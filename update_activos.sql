-- Actualizar todos los clientes a activos
UPDATE clientes SET activo = 1 WHERE activo IS NULL OR activo != 1;

-- Actualizar todos los proveedores a activos
UPDATE proveedores SET activo = 1 WHERE activo IS NULL OR activo != 1;
