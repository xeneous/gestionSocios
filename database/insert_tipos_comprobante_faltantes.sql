-- ============================================================================
-- INSERTAR TODOS LOS TIPOS DE COMPROBANTE
-- ============================================================================
-- Ejecutar este script en Supabase para agregar TODOS los tipos de comprobante
-- que existen en SQL Server (reemplaza los 3 iniciales)

-- Tipos de comprobante encontrados en SQL Server:
-- DA  (82578 registros) - Débito Automático
-- CS  (45556 registros) - Cuota Social
-- COB (3665 registros)  - Recibo de Caja
-- FC  (2375 registros)  - Factura
-- RDA (1430 registros)  - Reversión Débito Automático
-- PTT (1078 registros)  - Pago Total
-- APT (226 registros)   - Anticipo
-- CM  (4 registros)     - Crédito por Migración

-- NOTA: Se eliminaron espacios finales para evitar problemas con JOINs

INSERT INTO tipos_comprobante_socios (comprobante, descripcion, id_tipo_movimiento, signo) VALUES
  ('DA', 'Débito Automático', 1, 1),           -- Débito: aumenta deuda
  ('CS', 'Cuota Social', 1, 1),                -- Débito: aumenta deuda
  ('COB', 'Recibo de Caja', 2, -1),             -- Crédito: disminuye deuda (pago)
  ('FC', 'Factura', 1, 1),                     -- Débito: aumenta deuda
  ('RDA', 'Reversión Débito Automático', 2, -1), -- Crédito: disminuye deuda
  ('PTT', 'Pago Total', 2, -1),                 -- Crédito: disminuye deuda
  ('APT', 'Anticipo', 2, -1),                   -- Crédito: disminuye deuda
  ('CM', 'Crédito por Migración', 2, -1)       -- Crédito: disminuye deuda
ON CONFLICT (comprobante) DO UPDATE SET
  descripcion = EXCLUDED.descripcion,
  id_tipo_movimiento = EXCLUDED.id_tipo_movimiento,
  signo = EXCLUDED.signo;

-- Verificar los tipos de comprobante insertados
SELECT comprobante, descripcion, id_tipo_movimiento, signo
FROM tipos_comprobante_socios
ORDER BY comprobante;
