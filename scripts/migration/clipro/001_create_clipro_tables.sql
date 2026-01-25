-- =============================================================================
-- Script: Creación de tablas para Clientes/Proveedores (CLIPRO)
-- Base de datos: Supabase (PostgreSQL)
-- Fecha: 2026-01-24
-- =============================================================================

-- Eliminar tablas existentes si existen (en orden correcto por dependencias)
DROP TABLE IF EXISTS ven_cli_items CASCADE;
DROP TABLE IF EXISTS ven_cli_header CASCADE;
DROP TABLE IF EXISTS comp_prov_items CASCADE;
DROP TABLE IF EXISTS comp_prov_header CASCADE;
DROP TABLE IF EXISTS contactos_clientes CASCADE;
DROP TABLE IF EXISTS contactos_proveedores CASCADE;
DROP TABLE IF EXISTS tip_vent_mod_items CASCADE;
DROP TABLE IF EXISTS tip_vent_mod_header CASCADE;
DROP TABLE IF EXISTS tip_comp_mod_items CASCADE;
DROP TABLE IF EXISTS tip_comp_mod_header CASCADE;
DROP TABLE IF EXISTS clientes CASCADE;
DROP TABLE IF EXISTS proveedores CASCADE;
DROP TABLE IF EXISTS categorias_iva CASCADE;

-- =============================================================================
-- TABLA: categorias_iva
-- Categorías de IVA para facturación
-- =============================================================================
CREATE TABLE categorias_iva (
    id_civa SERIAL PRIMARY KEY,
    descripcion VARCHAR(25),
    ganancias INTEGER,
    tipo_factura_compras CHAR(1),
    tipo_factura_ventas CHAR(1),
    resumido VARCHAR(4)
);

COMMENT ON TABLE categorias_iva IS 'Categorías de IVA para facturación';

-- =============================================================================
-- TABLA: clientes (Sponsors)
-- Maestro de clientes/sponsors
-- =============================================================================
CREATE TABLE clientes (
    codigo SERIAL PRIMARY KEY,
    razon_social VARCHAR(60),
    domicilio VARCHAR(40),
    localidad VARCHAR(40),
    codigo_postal VARCHAR(8),
    id_provincia INTEGER,
    tipo1 SMALLINT,
    telefono1 VARCHAR(40),
    tipo2 SMALLINT,
    telefono2 VARCHAR(40),
    tipo3 SMALLINT,
    telefono3 VARCHAR(40),
    tipo4 SMALLINT,
    telefono4 VARCHAR(40),
    tipo5 SMALLINT,
    telefono5 VARCHAR(40),
    tipo6 SMALLINT,
    telefono6 VARCHAR(40),
    mail VARCHAR(50),
    notas TEXT,
    fecha TIMESTAMP,
    vendedor SMALLINT,
    hora TIMESTAMP,
    id_cliente_ant INTEGER,
    nombre VARCHAR(30),
    apellido VARCHAR(30),
    tipo_cuenta SMALLINT,
    categoria SMALLINT,
    cuit VARCHAR(13),
    civa SMALLINT,
    cuenta INTEGER,
    cuenta_subdiario INTEGER,
    fecha_nac TIMESTAMP,
    activo INTEGER DEFAULT 1,
    codigo_externo VARCHAR(20),
    vencimiento TIMESTAMP,
    hora_atencion VARCHAR(50),
    alerta VARCHAR(255),
    cventa INTEGER,
    tabla_ganancia INTEGER,
    id_zona INTEGER,
    fecha_baja TIMESTAMP,
    tipo_docto INTEGER,
    numero_docto INTEGER,
    descuento NUMERIC(18, 2),
    tipo_cuenta_comis INTEGER,
    ibrutos VARCHAR(12),
    percepcion_ib NUMERIC(8, 2),
    retencion_ib NUMERIC(8, 2),
    id_pais INTEGER,
    jurisdiccion INTEGER,
    adicional VARCHAR(60),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE clientes IS 'Maestro de clientes/sponsors';

CREATE INDEX idx_clientes_razon_social ON clientes(razon_social);
CREATE INDEX idx_clientes_cuit ON clientes(cuit);
CREATE INDEX idx_clientes_activo ON clientes(activo);

-- =============================================================================
-- TABLA: contactos_clientes
-- Contactos de clientes
-- =============================================================================
CREATE TABLE contactos_clientes (
    id_contacto SERIAL PRIMARY KEY,
    codigo INTEGER REFERENCES clientes(codigo) ON DELETE CASCADE,
    nyap VARCHAR(50),
    sector VARCHAR(60),
    telefono VARCHAR(50),
    mail VARCHAR(50),
    observacion VARCHAR(60),
    nacido TIMESTAMP,
    sucursal VARCHAR(60),
    cargo VARCHAR(60),
    alta TIMESTAMP,
    baja TIMESTAMP
);

COMMENT ON TABLE contactos_clientes IS 'Contactos de clientes';

CREATE INDEX idx_contactos_clientes_codigo ON contactos_clientes(codigo);

-- =============================================================================
-- TABLA: proveedores
-- Maestro de proveedores
-- =============================================================================
CREATE TABLE proveedores (
    codigo SERIAL PRIMARY KEY,
    razon_social VARCHAR(60),
    domicilio VARCHAR(40),
    localidad VARCHAR(40),
    codigo_postal VARCHAR(8),
    id_provincia INTEGER,
    cuenta INTEGER,
    tipo1 SMALLINT,
    telefono1 VARCHAR(40),
    tipo2 SMALLINT,
    telefono2 VARCHAR(40),
    tipo3 SMALLINT,
    telefono3 VARCHAR(40),
    tipo4 SMALLINT,
    telefono4 VARCHAR(40),
    tipo5 SMALLINT,
    telefono5 VARCHAR(40),
    tipo6 SMALLINT,
    telefono6 VARCHAR(40),
    mail VARCHAR(50),
    notas TEXT,
    fecha TIMESTAMP,
    vendedor SMALLINT,
    hora TIMESTAMP,
    id_cliente_ant INTEGER,
    nombre VARCHAR(30),
    apellido VARCHAR(30),
    tipo_cuenta SMALLINT,
    categoria SMALLINT,
    cuit VARCHAR(13),
    civa SMALLINT,
    cuenta_subdiario INTEGER,
    fecha_nac TIMESTAMP,
    activo INTEGER DEFAULT 1,
    codigo_externo VARCHAR(20),
    vencimiento TIMESTAMP,
    hora_atencion VARCHAR(50),
    alerta VARCHAR(255),
    cventa INTEGER,
    id_zona INTEGER,
    fecha_baja TIMESTAMP,
    tabla_ganancia INTEGER,
    tipo_docto INTEGER,
    numero_docto INTEGER,
    descuento NUMERIC(18, 2),
    ibrutos VARCHAR(12),
    percepcion_ib NUMERIC(8, 2),
    retencion_ib NUMERIC(8, 2),
    id_pais INTEGER,
    jurisdiccion INTEGER,
    adicional VARCHAR(60),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE proveedores IS 'Maestro de proveedores';

CREATE INDEX idx_proveedores_razon_social ON proveedores(razon_social);
CREATE INDEX idx_proveedores_cuit ON proveedores(cuit);
CREATE INDEX idx_proveedores_activo ON proveedores(activo);

-- =============================================================================
-- TABLA: contactos_proveedores
-- Contactos de proveedores
-- =============================================================================
CREATE TABLE contactos_proveedores (
    id_contacto SERIAL PRIMARY KEY,
    codigo INTEGER REFERENCES proveedores(codigo) ON DELETE CASCADE,
    nyap VARCHAR(50),
    sector VARCHAR(60),
    telefono VARCHAR(50),
    mail VARCHAR(50),
    observacion VARCHAR(60),
    nacido TIMESTAMP,
    sucursal VARCHAR(60),
    cargo VARCHAR(60),
    alta TIMESTAMP,
    baja TIMESTAMP
);

COMMENT ON TABLE contactos_proveedores IS 'Contactos de proveedores';

CREATE INDEX idx_contactos_proveedores_codigo ON contactos_proveedores(codigo);

-- =============================================================================
-- TABLA: tip_vent_mod_header
-- Tipos de comprobante de ventas (header)
-- =============================================================================
CREATE TABLE tip_vent_mod_header (
    codigo SERIAL PRIMARY KEY,
    comprobante CHAR(5) NOT NULL UNIQUE,
    descripcion VARCHAR(25) NOT NULL,
    signo INTEGER,
    multiplicador INTEGER,
    sicore VARCHAR(2),
    tipo_stock INTEGER,
    modulo INTEGER,
    iva_ventas CHAR(1) DEFAULT 'S',
    c_mov INTEGER,
    comp VARCHAR(10),
    conc_compra VARCHAR(3),
    ie INTEGER,
    wsa INTEGER,
    wsb INTEGER,
    wse INTEGER,
    wsc INTEGER
);

COMMENT ON TABLE tip_vent_mod_header IS 'Tipos de comprobante de ventas';

-- =============================================================================
-- TABLA: tip_vent_mod_items
-- Tipos de comprobante de ventas (items/conceptos)
-- =============================================================================
CREATE TABLE tip_vent_mod_items (
    id SERIAL PRIMARY KEY,
    codigo INTEGER NOT NULL REFERENCES tip_vent_mod_header(codigo) ON DELETE CASCADE,
    concepto CHAR(5) NOT NULL,
    signo INTEGER NOT NULL
);

COMMENT ON TABLE tip_vent_mod_items IS 'Items/conceptos de tipos de comprobante de ventas';

CREATE INDEX idx_tip_vent_mod_items_codigo ON tip_vent_mod_items(codigo);

-- =============================================================================
-- TABLA: tip_comp_mod_header
-- Tipos de comprobante de compras (header)
-- =============================================================================
CREATE TABLE tip_comp_mod_header (
    codigo SERIAL PRIMARY KEY,
    comprobante CHAR(5) NOT NULL,
    descripcion VARCHAR(25) NOT NULL,
    signo INTEGER,
    multiplicador INTEGER,
    sicore CHAR(2),
    tipo_stock INTEGER,
    c_mov INTEGER,
    comp VARCHAR(50),
    iva_compras VARCHAR(1),
    ie INTEGER,
    br VARCHAR(2),
    modulo INTEGER
);

COMMENT ON TABLE tip_comp_mod_header IS 'Tipos de comprobante de compras';

-- =============================================================================
-- TABLA: tip_comp_mod_items
-- Tipos de comprobante de compras (items/conceptos)
-- =============================================================================
CREATE TABLE tip_comp_mod_items (
    id SERIAL PRIMARY KEY,
    codigo INTEGER NOT NULL REFERENCES tip_comp_mod_header(codigo) ON DELETE CASCADE,
    concepto CHAR(5) NOT NULL,
    signo INTEGER NOT NULL
);

COMMENT ON TABLE tip_comp_mod_items IS 'Items/conceptos de tipos de comprobante de compras';

CREATE INDEX idx_tip_comp_mod_items_codigo ON tip_comp_mod_items(codigo);

-- =============================================================================
-- TABLA: ven_cli_header
-- Cuenta corriente de clientes (header de transacciones)
-- =============================================================================
CREATE TABLE ven_cli_header (
    id_transaccion SERIAL PRIMARY KEY,
    comprobante INTEGER NOT NULL,
    anio_mes INTEGER NOT NULL,
    fecha TIMESTAMP NOT NULL,
    cliente INTEGER NOT NULL REFERENCES clientes(codigo),
    tipo_comprobante INTEGER NOT NULL,
    nro_comprobante CHAR(12),
    tipo_factura CHAR(1),
    total_importe NUMERIC(18, 2) NOT NULL,
    cancelado NUMERIC(18, 2) DEFAULT 0,
    fecha1_venc TIMESTAMP,
    fecha2_venc TIMESTAMP,
    estado CHAR(2),
    fecha_real TIMESTAMP NOT NULL,
    centro_costo INTEGER,
    descripcion_importe VARCHAR(255),
    moneda INTEGER,
    importe_origen NUMERIC(18, 2),
    tc NUMERIC(18, 4),
    doc_c NUMERIC(18, 0),
    cancelado_origen NUMERIC(18, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE ven_cli_header IS 'Cuenta corriente de clientes - Header de transacciones';

CREATE INDEX idx_ven_cli_header_cliente ON ven_cli_header(cliente);
CREATE INDEX idx_ven_cli_header_fecha ON ven_cli_header(fecha);
CREATE INDEX idx_ven_cli_header_anio_mes ON ven_cli_header(anio_mes);
CREATE INDEX idx_ven_cli_header_comprobante ON ven_cli_header(comprobante);

-- =============================================================================
-- TABLA: ven_cli_items
-- Cuenta corriente de clientes (items de transacciones)
-- =============================================================================
CREATE TABLE ven_cli_items (
    id_campo SERIAL PRIMARY KEY,
    id_transaccion INTEGER REFERENCES ven_cli_header(id_transaccion) ON DELETE CASCADE,
    comprobante INTEGER NOT NULL,
    anio_mes INTEGER NOT NULL,
    item INTEGER NOT NULL,
    concepto CHAR(3) NOT NULL,
    cuenta INTEGER NOT NULL,
    importe NUMERIC(18, 2) NOT NULL,
    base_contable NUMERIC(18, 2) NOT NULL,
    area INTEGER,
    detalle VARCHAR(60),
    alicuota NUMERIC(18, 2) NOT NULL,
    grilla VARCHAR(30),
    base NUMERIC(18, 2)
);

COMMENT ON TABLE ven_cli_items IS 'Cuenta corriente de clientes - Items de transacciones';

CREATE INDEX idx_ven_cli_items_id_transaccion ON ven_cli_items(id_transaccion);
CREATE INDEX idx_ven_cli_items_comprobante ON ven_cli_items(comprobante);

-- =============================================================================
-- TABLA: comp_prov_header
-- Cuenta corriente de proveedores (header de transacciones)
-- =============================================================================
CREATE TABLE comp_prov_header (
    id_transaccion SERIAL PRIMARY KEY,
    comprobante INTEGER NOT NULL,
    anio_mes INTEGER NOT NULL,
    fecha TIMESTAMP NOT NULL,
    proveedor INTEGER NOT NULL REFERENCES proveedores(codigo),
    tipo_comprobante INTEGER NOT NULL,
    nro_comprobante CHAR(12) NOT NULL,
    tipo_factura CHAR(1),
    total_importe NUMERIC(18, 2) NOT NULL,
    cancelado NUMERIC(18, 2) DEFAULT 0,
    fecha1_venc TIMESTAMP,
    fecha2_venc TIMESTAMP,
    estado CHAR(1) NOT NULL,
    fecha_real TIMESTAMP NOT NULL,
    centro_costo INTEGER,
    descripcion_importe VARCHAR(255),
    moneda INTEGER,
    importe_origen NUMERIC(18, 2),
    tc NUMERIC(18, 3),
    doc_c NUMERIC(18, 0),
    cancelado_origen NUMERIC(18, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE comp_prov_header IS 'Cuenta corriente de proveedores - Header de transacciones';

CREATE INDEX idx_comp_prov_header_proveedor ON comp_prov_header(proveedor);
CREATE INDEX idx_comp_prov_header_fecha ON comp_prov_header(fecha);
CREATE INDEX idx_comp_prov_header_anio_mes ON comp_prov_header(anio_mes);
CREATE INDEX idx_comp_prov_header_comprobante ON comp_prov_header(comprobante);

-- =============================================================================
-- TABLA: comp_prov_items
-- Cuenta corriente de proveedores (items de transacciones)
-- =============================================================================
CREATE TABLE comp_prov_items (
    id_campo SERIAL PRIMARY KEY,
    id_transaccion INTEGER REFERENCES comp_prov_header(id_transaccion) ON DELETE CASCADE,
    comprobante INTEGER NOT NULL,
    anio_mes INTEGER NOT NULL,
    item INTEGER NOT NULL,
    concepto CHAR(3) NOT NULL,
    cuenta INTEGER NOT NULL,
    importe NUMERIC(18, 4) NOT NULL,
    base_contable NUMERIC(18, 2) NOT NULL,
    area INTEGER,
    detalle VARCHAR(60),
    alicuota NUMERIC(18, 2) NOT NULL,
    grilla VARCHAR(30),
    base NUMERIC(18, 2),
    fecha_cierre TIMESTAMP,
    factura VARCHAR(20)
);

COMMENT ON TABLE comp_prov_items IS 'Cuenta corriente de proveedores - Items de transacciones';

CREATE INDEX idx_comp_prov_items_id_transaccion ON comp_prov_items(id_transaccion);
CREATE INDEX idx_comp_prov_items_comprobante ON comp_prov_items(comprobante);

-- =============================================================================
-- Habilitar RLS (Row Level Security) para todas las tablas
-- =============================================================================
ALTER TABLE categorias_iva ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE contactos_clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE contactos_proveedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE tip_vent_mod_header ENABLE ROW LEVEL SECURITY;
ALTER TABLE tip_vent_mod_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE tip_comp_mod_header ENABLE ROW LEVEL SECURITY;
ALTER TABLE tip_comp_mod_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE ven_cli_header ENABLE ROW LEVEL SECURITY;
ALTER TABLE ven_cli_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE comp_prov_header ENABLE ROW LEVEL SECURITY;
ALTER TABLE comp_prov_items ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- Políticas RLS - Acceso para usuarios autenticados
-- =============================================================================
CREATE POLICY "Acceso completo para usuarios autenticados" ON categorias_iva FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON clientes FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON contactos_clientes FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON proveedores FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON contactos_proveedores FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON tip_vent_mod_header FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON tip_vent_mod_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON tip_comp_mod_header FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON tip_comp_mod_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON ven_cli_header FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON ven_cli_items FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON comp_prov_header FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "Acceso completo para usuarios autenticados" ON comp_prov_items FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- =============================================================================
-- Triggers para actualizar updated_at
-- =============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_clientes_updated_at BEFORE UPDATE ON clientes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_proveedores_updated_at BEFORE UPDATE ON proveedores FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
