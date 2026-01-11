-- Habilitar RLS en las tablas de asientos
ALTER TABLE asientos_header ENABLE ROW LEVEL SECURITY;
ALTER TABLE asientos_items ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes si las hay
DROP POLICY IF EXISTS "Allow all operations on asientos_header" ON asientos_header;
DROP POLICY IF EXISTS "Allow all operations on asientos_items" ON asientos_items;

-- Crear políticas que permitan todas las operaciones
CREATE POLICY "Allow all operations on asientos_header"
  ON asientos_header
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow all operations on asientos_items"
  ON asientos_items
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);
