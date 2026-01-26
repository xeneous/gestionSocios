-- =============================================================================
-- Script: Crear tabla de parámetros contables
-- Base de datos: Supabase (PostgreSQL)
-- Fecha: 2026-01-25
-- =============================================================================

-- Tabla de parámetros contables del sistema
CREATE TABLE IF NOT EXISTS parametros_contables (
    id SERIAL PRIMARY KEY,
    clave VARCHAR(50) NOT NULL UNIQUE,
    valor VARCHAR(255),
    descripcion VARCHAR(255),
    tipo VARCHAR(20) DEFAULT 'texto', -- texto, numero, cuenta, fecha
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice para búsqueda por clave
CREATE INDEX IF NOT EXISTS idx_parametros_contables_clave ON parametros_contables(clave);

-- Insertar parámetros iniciales
INSERT INTO parametros_contables (clave, valor, descripcion, tipo) VALUES
    ('CUENTA_PROVEEDORES', NULL, 'Cuenta contable para Proveedores (Pasivo)', 'cuenta'),
    ('CUENTA_CLIENTES', NULL, 'Cuenta contable para Clientes (Activo)', 'cuenta'),
    ('CUENTA_SPONSORS', NULL, 'Cuenta contable para Sponsors (Activo)', 'cuenta')
ON CONFLICT (clave) DO NOTHING;

-- Trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_parametros_contables_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_parametros_contables_updated_at ON parametros_contables;
CREATE TRIGGER trigger_parametros_contables_updated_at
    BEFORE UPDATE ON parametros_contables
    FOR EACH ROW
    EXECUTE FUNCTION update_parametros_contables_updated_at();

-- Verificar creación
SELECT * FROM parametros_contables ORDER BY id;
