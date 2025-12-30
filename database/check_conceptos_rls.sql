-- Ver si hay políticas RLS activas en la tabla conceptos
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'conceptos';

-- Ver las políticas RLS definidas
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'conceptos';

-- Intentar seleccionar datos
SELECT COUNT(*) as total FROM conceptos;
SELECT * FROM conceptos LIMIT 5;
