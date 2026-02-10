-- Tabla de categorías de residente con porcentajes de descuento
CREATE TABLE IF NOT EXISTS categorias_residente (
  codigo VARCHAR(2) PRIMARY KEY,
  descripcion VARCHAR(50) NOT NULL,
  porcentaje_descuento NUMERIC(5,2) NOT NULL DEFAULT 0,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE categorias_residente IS 'Categorías de residentes con sus porcentajes de descuento en cuota social';
COMMENT ON COLUMN categorias_residente.codigo IS 'Código de categoría (R1, R2, R3)';
COMMENT ON COLUMN categorias_residente.porcentaje_descuento IS 'Porcentaje de descuento sobre cuota social (0-100)';

-- Valores iniciales: R1 y R2 no pagan (100% descuento), R3 paga completo (0% descuento)
INSERT INTO categorias_residente (codigo, descripcion, porcentaje_descuento) VALUES
('R1', 'Residente 1er año', 100.00),
('R2', 'Residente 2do año', 100.00),
('R3', 'Residente 3er año', 0.00)
ON CONFLICT (codigo) DO NOTHING;
