-- Script para crear tabla de trazabilidad de imputaciones (pagos)
-- Ejecutar en Supabase SQL Editor

-- ============================================================================
-- Tabla notas_imputacion: Registra qué comprobantes fueron pagados por qué OP/Recibo
-- ============================================================================

CREATE TABLE IF NOT EXISTS notas_imputacion (
    id SERIAL PRIMARY KEY,

    -- ID de la operación de pago (OP para proveedores, Recibo para clientes/socios)
    id_operacion INTEGER NOT NULL,

    -- ID de la transacción/comprobante que se está pagando
    id_transaccion INTEGER NOT NULL,

    -- Importe imputado (cuánto se pagó de esa transacción)
    importe NUMERIC(18, 2) NOT NULL,

    -- Tipo de operación:
    -- 1 = Orden de Pago (proveedores)
    -- 2 = Recibo (clientes)
    -- 3 = Recibo (socios)
    tipo_operacion INTEGER NOT NULL DEFAULT 1,

    -- Observaciones opcionales
    observacion VARCHAR(100),

    -- Fecha de creación automática
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Constraints
    CONSTRAINT chk_importe_positivo CHECK (importe > 0),
    CONSTRAINT chk_tipo_operacion CHECK (tipo_operacion IN (1, 2, 3))
);

-- Índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_notas_imputacion_operacion
    ON notas_imputacion(id_operacion, tipo_operacion);

CREATE INDEX IF NOT EXISTS idx_notas_imputacion_transaccion
    ON notas_imputacion(id_transaccion);

-- Comentarios
COMMENT ON TABLE notas_imputacion IS 'Trazabilidad de imputaciones: qué comprobantes fueron pagados por qué operación';
COMMENT ON COLUMN notas_imputacion.id_operacion IS 'ID de la OP o Recibo que realizó el pago';
COMMENT ON COLUMN notas_imputacion.id_transaccion IS 'ID del comprobante (factura) que se pagó';
COMMENT ON COLUMN notas_imputacion.importe IS 'Monto imputado/pagado';
COMMENT ON COLUMN notas_imputacion.tipo_operacion IS '1=OP Proveedor, 2=Recibo Cliente, 3=Recibo Socio';

-- ============================================================================
-- Verificar creación
-- ============================================================================
SELECT 'notas_imputacion' as tabla, COUNT(*) as registros FROM notas_imputacion;
