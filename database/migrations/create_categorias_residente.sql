-- Tabla de categorías de residente con porcentajes de descuento
CREATE TABLE IF NOT EXISTS categorias_residente (
  codigo VARCHAR(2) PRIMARY KEY,
  descripcion VARCHAR(50) NOT NULL,
  porcentaje_descuento NUMERIC(5,2) NOT NULL DEFAULT 0,
  orden INT NOT NULL DEFAULT 0,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE categorias_residente IS 'Categorías de residentes con sus porcentajes de descuento en cuota social';
COMMENT ON COLUMN categorias_residente.codigo IS 'Código de categoría (R1, R2, R)';
COMMENT ON COLUMN categorias_residente.porcentaje_descuento IS 'Porcentaje de descuento sobre cuota social (0-100)';
COMMENT ON COLUMN categorias_residente.orden IS 'Orden de la categoría (1=primer año, 2=segundo, etc.)';

-- Valores iniciales: R1 y R2 no pagan (100% descuento), RS paga completo (0% descuento)
INSERT INTO categorias_residente (codigo, descripcion, porcentaje_descuento, orden) VALUES
('R1', 'Residente 1er año', 100.00, 1),
('R2', 'Residente 2do año', 100.00, 2),
('RS', 'Residente 3er año y mas', 0.00, 3)
ON CONFLICT (codigo) DO NOTHING;
