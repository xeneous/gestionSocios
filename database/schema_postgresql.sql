-- ============================================================================
-- SAO 2026 - PostgreSQL Database Schema
-- Sistema Contable Integrado
-- ============================================================================
-- Usuario revisó y aprobó tabla por tabla todas las definiciones
-- Fecha: 2025-12-22
-- ============================================================================

-- ============================================================================
-- TABLAS DE REFERENCIA
-- ============================================================================

CREATE TABLE provincias (
  id SERIAL PRIMARY KEY,
  codigo INTEGER,
  descripcion VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE categorias_iva (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(10),
  descripcion VARCHAR(100),
  ganancias INTEGER,
  tipo_factura_compras CHAR(1),
  tipo_factura_ventas CHAR(1),
  resumido VARCHAR(10),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE grupos_agrupados (
  id SERIAL PRIMARY KEY,
  codigo CHAR(1) UNIQUE NOT NULL,
  descripcion VARCHAR(100),
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tarjetas (
  id SERIAL PRIMARY KEY,
  codigo INTEGER UNIQUE NOT NULL,
  descripcion VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PLAN DE CUENTAS (CORE CONTABLE)
-- ============================================================================

CREATE TABLE cuentas (
  id SERIAL PRIMARY KEY,
  cuenta INTEGER UNIQUE NOT NULL,           -- Número de cuenta completo
  corta INTEGER,                            -- Cuenta abreviada (4 dígitos máx) para carga rápida
  descripcion VARCHAR(100) NOT NULL,        -- Descripción completa
  descripcion_resumida VARCHAR(50),         -- Descripción corta para reportes
  sigla VARCHAR(10),                        -- Sigla/abreviatura
  tipo_cuenta_contable SMALLINT,            -- Tipo de cuenta
  imputable BOOLEAN DEFAULT false,          -- Si se puede imputar
  rubro INTEGER,                            -- Rubro
  subrubro INTEGER,                         -- Subrubro
  activo BOOLEAN DEFAULT true,              -- Estado activo/inactivo
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cuentas_cuenta ON cuentas(cuenta);
CREATE INDEX idx_cuentas_corta ON cuentas(corta) WHERE corta IS NOT NULL;
CREATE INDEX idx_cuentas_activo ON cuentas(activo);

-- ============================================================================
-- ASIENTOS CONTABLES (CORE CONTABLE)
-- ============================================================================

CREATE TABLE asientos_header (
  id SERIAL,                                -- ID interno para FKs
  asiento INTEGER NOT NULL,                 -- Número de asiento
  anio_mes INTEGER NOT NULL,                -- Período YYYYMM
  tipo_asiento INTEGER NOT NULL,            -- Tipo de asiento
  fecha DATE NOT NULL,                      -- Fecha del asiento
  detalle VARCHAR(255),                     -- Detalle/descripción
  centro_costo INTEGER,                     -- Centro de costo
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (asiento, anio_mes, tipo_asiento),
  UNIQUE (id)
);

CREATE INDEX idx_asientos_header_fecha ON asientos_header(fecha);
CREATE INDEX idx_asientos_header_periodo ON asientos_header(anio_mes);

CREATE TABLE asientos_items (
  id SERIAL PRIMARY KEY,
  asiento INTEGER NOT NULL,
  anio_mes INTEGER NOT NULL,
  tipo_asiento INTEGER NOT NULL,
  item INTEGER NOT NULL,
  cuenta_id INTEGER REFERENCES cuentas(id),
  debe NUMERIC(18,2) DEFAULT 0,
  haber NUMERIC(18,2) DEFAULT 0,
  observacion VARCHAR(255),
  centro_costo INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  FOREIGN KEY (asiento, anio_mes, tipo_asiento) 
    REFERENCES asientos_header(asiento, anio_mes, tipo_asiento) ON DELETE CASCADE
);

CREATE INDEX idx_asientos_items_asiento ON asientos_items(asiento, anio_mes, tipo_asiento);
CREATE INDEX idx_asientos_items_cuenta ON asientos_items(cuenta_id);

-- ============================================================================
-- TARJETAS (Para débito automático)
-- ============================================================================

CREATE TABLE tarjetas (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,              -- VISA, MASTERCARD, AMEX
  codigo VARCHAR(10),                       -- Código interno
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- SOCIOS (MIEMBROS)
-- ============================================================================

CREATE TABLE socios (
  id SERIAL PRIMARY KEY,
  
  -- Datos Personales
  apellido VARCHAR(50) NOT NULL,
  nombre VARCHAR(50) NOT NULL,
  tipo_documento VARCHAR(10),               -- DNI/LC/LE/PAS
  numero_documento VARCHAR(20),
  cuil VARCHAR(13),
  nacionalidad_id INTEGER,
  sexo VARCHAR(1),
  fecha_nacimiento DATE,
  
  -- Datos Profesionales
  grupo CHAR(1),                            -- Tipo/categoría de socio
  grupo_desde DATE,                         -- Fecha desde que está en ese grupo
  residente BOOLEAN DEFAULT false,
  fecha_inicio_residencia DATE,             -- fresidencia
  matricula_nacional VARCHAR(20),
  matricula_provincial VARCHAR(20),
  fecha_ingreso DATE,                       -- Ingreso a SAO
  
  -- Domicilio (único)
  domicilio VARCHAR(100),
  localidad VARCHAR(100),
  provincia_id INTEGER REFERENCES provincias(id),
  codigo_postal VARCHAR(10),
  pais_id INTEGER,                          -- Para socios del exterior
  telefono VARCHAR(50),
  telefono_secundario VARCHAR(50),          -- Era "Fax"
  
  -- Contacto Email
  email VARCHAR(100),
  email_alternativo VARCHAR(100),           -- Era EmailAlt1
  
  -- Débito Automático
  tarjeta_id INTEGER,  -- No FK constraint - tarjetas table not imported
  numero_tarjeta VARCHAR(16),
  adherido_debito BOOLEAN DEFAULT false,
  vencimiento_tarjeta DATE,
  debitar_desde DATE,
  
  -- Estado
  activo BOOLEAN DEFAULT true,
  fecha_baja TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_socios_documento ON socios(numero_documento);
CREATE INDEX idx_socios_email ON socios(email);
CREATE INDEX idx_socios_activo ON socios(activo);
CREATE INDEX idx_socios_grupo ON socios(grupo);

-- ============================================================================
-- PROFESIONALES (Mismo esquema que socios)
-- ============================================================================

CREATE TABLE profesionales (
  id SERIAL PRIMARY KEY,
  
  -- Datos Personales
  apellido VARCHAR(50) NOT NULL,
  nombre VARCHAR(50) NOT NULL,
  tipo_documento VARCHAR(10),
  numero_documento VARCHAR(20),
  cuil VARCHAR(13),
  nacionalidad_id INTEGER,
  sexo VARCHAR(1),
  fecha_nacimiento DATE,
  
  -- Datos Profesionales
  grupo CHAR(1),
  grupo_desde DATE,
  matricula_nacional VARCHAR(20),
  matricula_provincial VARCHAR(20),
  especialidad VARCHAR(100),
  
  -- Domicilio
  domicilio VARCHAR(100),
  localidad VARCHAR(100),
  provincia_id INTEGER REFERENCES provincias(id),
  codigo_postal VARCHAR(10),
  pais_id INTEGER,
  telefono VARCHAR(50),
  telefono_secundario VARCHAR(50),
  
  -- Contacto Email
  email VARCHAR(100),
  email_alternativo VARCHAR(100),
  
  -- Estado
  activo BOOLEAN DEFAULT true,
  fecha_baja TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_profesionales_documento ON profesionales(numero_documento);
CREATE INDEX idx_profesionales_email ON profesionales(email);
CREATE INDEX idx_profesionales_activo ON profesionales(activo);

-- ============================================================================
-- OBSERVACIONES DE SOCIOS
-- ============================================================================

CREATE TABLE observaciones_socios (
  id SERIAL PRIMARY KEY,
  socio_id INTEGER REFERENCES socios(id),
  fecha DATE NOT NULL,
  observacion TEXT,
  usuario VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_obs_socios_socio ON observaciones_socios(socio_id);

-- ============================================================================
-- CLIENTES
-- ============================================================================

CREATE TABLE clientes (
  id SERIAL PRIMARY KEY,
  razon_social VARCHAR(100) NOT NULL,
  nombre VARCHAR(50),
  apellido VARCHAR(50),
  cuit VARCHAR(13),
  tipo_documento INTEGER,
  numero_documento INTEGER,
  
  -- Domicilio
  domicilio VARCHAR(100),
  localidad VARCHAR(100),
  provincia_id INTEGER REFERENCES provincias(id),
  codigo_postal VARCHAR(10),
  pais_id INTEGER,
  
  -- Contacto
  telefono VARCHAR(50),
  telefono_secundario VARCHAR(50),
  email VARCHAR(100),
  
  -- Impositivo
  categoria_iva_id INTEGER REFERENCES categorias_iva(id),
  ingresos_brutos VARCHAR(12),
  
  -- Contable
  cuenta_contable_id INTEGER REFERENCES cuentas(id),
  
  -- Estado
  activo BOOLEAN DEFAULT true,
  fecha_baja TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_clientes_cuit ON clientes(cuit);
CREATE INDEX idx_clientes_activo ON clientes(activo);

-- ============================================================================
-- PROVEEDORES
-- ============================================================================

CREATE TABLE proveedores (
  id SERIAL PRIMARY KEY,
  razon_social VARCHAR(100) NOT NULL,
  nombre VARCHAR(50),
  apellido VARCHAR(50),
  cuit VARCHAR(13),
  tipo_documento INTEGER,
  numero_documento INTEGER,
  
  -- Domicilio
  domicilio VARCHAR(100),
  localidad VARCHAR(100),
  provincia_id INTEGER REFERENCES provincias(id),
  codigo_postal VARCHAR(10),
  pais_id INTEGER,
  
  -- Contacto
  telefono VARCHAR(50),
  telefono_secundario VARCHAR(50),
  email VARCHAR(100),
  
  -- Impositivo
  categoria_iva_id INTEGER REFERENCES categorias_iva(id),
  ingresos_brutos VARCHAR(12),
  
  -- Contable
  cuenta_contable_id INTEGER REFERENCES cuentas(id),
  
  -- Estado
  activo BOOLEAN DEFAULT true,
  fecha_baja TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_proveedores_cuit ON proveedores(cuit);
CREATE INDEX idx_proveedores_activo ON proveedores(activo);

-- ============================================================================
-- CONCEPTOS (FACTURACIÓN)
-- ============================================================================

CREATE TABLE conceptos (
  id SERIAL PRIMARY KEY,
  concepto VARCHAR(3) UNIQUE NOT NULL,        -- Código del concepto
  entidad SMALLINT NOT NULL,                -- Entidad
  descripcion VARCHAR(100) NOT NULL,
  modalidad CHAR(1),                        -- A definir (Mensual, Anual, etc.)
  importe NUMERIC(18,2),                    -- Importe
  cuenta_contable_id INTEGER REFERENCES cuentas(id),
  grupo CHAR(1),                            -- Grupo socio/profesional
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conceptos_concepto ON conceptos(concepto);
CREATE INDEX idx_conceptos_activo ON conceptos(activo);

-- ============================================================================
-- CONCEPTOS ASIGNADOS A SOCIOS
-- ============================================================================

CREATE TABLE conceptos_socios (
  id SERIAL PRIMARY KEY,
  socio_id INTEGER REFERENCES socios(id),
  concepto VARCHAR(3) REFERENCES conceptos(concepto),
  fecha_alta DATE,
  fecha_vigencia DATE,
  importe_personalizado NUMERIC(18,2),
  fecha_baja DATE,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conceptos_socios_socio ON conceptos_socios(socio_id);
CREATE INDEX idx_conceptos_socios_concepto ON conceptos_socios(concepto);

-- ============================================================================
-- CONCEPTOS ASIGNADOS A PROFESIONALES
-- ============================================================================

CREATE TABLE conceptos_profesionales (
  id SERIAL PRIMARY KEY,
  profesional_id INTEGER REFERENCES profesionales(id),
  concepto_codigo VARCHAR(3) REFERENCES conceptos(codigo),
  fecha_alta DATE,
  fecha_vigencia DATE,
  importe_personalizado NUMERIC(18,2),
  fecha_baja DATE,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conceptos_prof_profesional ON conceptos_profesionales(profesional_id);
CREATE INDEX idx_conceptos_prof_concepto ON conceptos_profesionales(concepto_codigo);

-- ============================================================================
-- CUENTAS CORRIENTES DE SOCIOS
-- ============================================================================

CREATE TABLE cuentas_corrientes (
  id SERIAL PRIMARY KEY,
  socio_id INTEGER REFERENCES socios(id),
  entidad INTEGER,
  fecha DATE NOT NULL,
  concepto_codigo VARCHAR(3) REFERENCES conceptos(codigo),
  punto_venta VARCHAR(20),
  documento_numero VARCHAR(20),
  importe NUMERIC(18,2) NOT NULL,
  cancelado NUMERIC(18,2) DEFAULT 0,
  vencimiento DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cc_socio ON cuentas_corrientes(socio_id);
CREATE INDEX idx_cc_fecha ON cuentas_corrientes(fecha);
CREATE INDEX idx_cc_concepto ON cuentas_corrientes(concepto_codigo);

-- ============================================================================
-- DETALLE CUENTAS CORRIENTES
-- ============================================================================

CREATE TABLE detalle_cuentas_corrientes (
  id SERIAL PRIMARY KEY,
  cuenta_corriente_id INTEGER REFERENCES cuentas_corrientes(id) ON DELETE CASCADE,
  item INTEGER NOT NULL,
  concepto_codigo VARCHAR(3) REFERENCES conceptos(codigo),
  cantidad NUMERIC(18,2) DEFAULT 1,
  importe NUMERIC(18,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_detalle_cc_cuenta ON detalle_cuentas_corrientes(cuenta_corriente_id);

-- ============================================================================
-- PRESENTACIONES DE TARJETAS
-- ============================================================================

CREATE TABLE presentaciones_tarjetas (
  id SERIAL PRIMARY KEY,
  tarjeta_id INTEGER REFERENCES tarjetas(id),
  fecha_presentacion DATE NOT NULL,
  fecha_acreditacion DATE,
  total NUMERIC(18,2),
  comision NUMERIC(18,2),
  neto NUMERIC(18,2),
  procesado BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_pres_tarjetas_fecha ON presentaciones_tarjetas(fecha_presentacion);
CREATE INDEX idx_pres_tarjetas_tarjeta ON presentaciones_tarjetas(tarjeta_id);

-- ============================================================================
-- TIPOS DE COMPROBANTES - COMPRAS
-- ============================================================================

CREATE TABLE tipos_comprobante_compra (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(10) UNIQUE NOT NULL,
  descripcion VARCHAR(100) NOT NULL,
  multiplicador INTEGER,                    -- 1 o -1 para NC
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tipos_comprobante_compra_items (
  id SERIAL PRIMARY KEY,
  tipo_comprobante_id INTEGER REFERENCES tipos_comprobante_compra(id) ON DELETE CASCADE,
  concepto VARCHAR(3),
  signo INTEGER,                            -- Debe/Haber
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- TIPOS DE COMPROBANTES - VENTAS
-- ============================================================================

CREATE TABLE tipos_comprobante_venta (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(10) UNIQUE NOT NULL,
  descripcion VARCHAR(100) NOT NULL,
  multiplicador INTEGER,                    -- 1 o -1 para NC
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE tipos_comprobante_venta_items (
  id SERIAL PRIMARY KEY,
  tipo_comprobante_id INTEGER REFERENCES tipos_comprobante_venta(id) ON DELETE CASCADE,
  concepto VARCHAR(3),
  signo INTEGER,                            -- Debe/Haber
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- COMPRAS - HEADER
-- ============================================================================

CREATE TABLE compras_header (
  id SERIAL PRIMARY KEY,
  comprobante INTEGER NOT NULL,
  anio_mes INTEGER NOT NULL,
  fecha DATE NOT NULL,
  proveedor_id INTEGER REFERENCES proveedores(id),
  tipo_comprobante_id INTEGER REFERENCES tipos_comprobante_compra(id),
  nro_comprobante VARCHAR(20) NOT NULL,
  tipo_factura CHAR(1),
  total_importe NUMERIC(18,2) NOT NULL,
  cancelado NUMERIC(18,2) DEFAULT 0,
  fecha_vencimiento DATE,
  estado VARCHAR(2),
  centro_costo INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_compras_fecha ON compras_header(fecha);
CREATE INDEX idx_compras_proveedor ON compras_header(proveedor_id);

-- ============================================================================
-- COMPRAS - ITEMS
-- ============================================================================

CREATE TABLE compras_items (
  id SERIAL PRIMARY KEY,
  compra_header_id INTEGER REFERENCES compras_header(id) ON DELETE CASCADE,
  item INTEGER NOT NULL,
  concepto VARCHAR(3),
  cuenta_id INTEGER REFERENCES cuentas(id),
  importe NUMERIC(18,4) NOT NULL,
  base_contable NUMERIC(18,2),
  alicuota NUMERIC(18,2),
  area INTEGER,
  detalle VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_compras_items_header ON compras_items(compra_header_id);
CREATE INDEX idx_compras_items_cuenta ON compras_items(cuenta_id);

-- ============================================================================
-- VENTAS - HEADER
-- ============================================================================

CREATE TABLE ventas_header (
  id SERIAL PRIMARY KEY,
  comprobante INTEGER NOT NULL,
  anio_mes INTEGER NOT NULL,
  fecha DATE NOT NULL,
  cliente_id INTEGER REFERENCES clientes(id),
  tipo_comprobante_id INTEGER REFERENCES tipos_comprobante_venta(id),
  nro_comprobante VARCHAR(20),
  tipo_factura CHAR(1),
  total_importe NUMERIC(18,2) NOT NULL,
  cancelado NUMERIC(18,2) DEFAULT 0,
  fecha_vencimiento DATE,
  estado VARCHAR(2),
  centro_costo INTEGER,
  descripcion_importe VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ventas_fecha ON ventas_header(fecha);
CREATE INDEX idx_ventas_cliente ON ventas_header(cliente_id);

-- ============================================================================
-- VENTAS - ITEMS
-- ============================================================================

CREATE TABLE ventas_items (
  id SERIAL PRIMARY KEY,
  venta_header_id INTEGER REFERENCES ventas_header(id) ON DELETE CASCADE,
  item INTEGER NOT NULL,
  concepto VARCHAR(3),
  cuenta_id INTEGER REFERENCES cuentas(id),
  importe NUMERIC(18,2) NOT NULL,
  base_contable NUMERIC(18,2),
  alicuota NUMERIC(18,2),
  area INTEGER,
  detalle VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_ventas_items_header ON ventas_items(venta_header_id);
CREATE INDEX idx_ventas_items_cuenta ON ventas_items(cuenta_id);

-- ============================================================================
-- CONTACTOS DE PROVEEDORES
-- ============================================================================

CREATE TABLE contactos_proveedores (
  id SERIAL PRIMARY KEY,
  proveedor_id INTEGER REFERENCES proveedores(id) ON DELETE CASCADE,
  nombre_apellido VARCHAR(100),
  sector VARCHAR(100),
  cargo VARCHAR(100),
  sucursal VARCHAR(100),
  telefono VARCHAR(50),
  email VARCHAR(100),
  fecha_nacimiento DATE,
  observacion VARCHAR(255),
  fecha_alta DATE,
  fecha_baja DATE,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_contactos_prov_proveedor ON contactos_proveedores(proveedor_id);
CREATE INDEX idx_contactos_prov_activo ON contactos_proveedores(activo);

-- ============================================================================
-- CONTACTOS DE CLIENTES
-- ============================================================================

CREATE TABLE contactos_clientes (
  id SERIAL PRIMARY KEY,
  cliente_id INTEGER REFERENCES clientes(id) ON DELETE CASCADE,
  nombre_apellido VARCHAR(100),
  sector VARCHAR(100),
  cargo VARCHAR(100),
  sucursal VARCHAR(100),
  telefono VARCHAR(50),
  email VARCHAR(100),
  fecha_nacimiento DATE,
  observacion VARCHAR(255),
  fecha_alta DATE,
  fecha_baja DATE,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_contactos_cli_cliente ON contactos_clientes(cliente_id);
CREATE INDEX idx_contactos_cli_activo ON contactos_clientes(activo);

-- ============================================================================
-- TESORERÍA - CONCEPTOS
-- ============================================================================

CREATE TABLE conceptos_tesoreria (
  id SERIAL PRIMARY KEY,
  descripcion VARCHAR(100) NOT NULL,
  cuenta_contable_id INTEGER REFERENCES cuentas(id),
  modalidad INTEGER,
  tipo_concepto CHAR(2),                   -- CI/CE (Cobro/Pago, Ingreso/Egreso)
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conceptos_tesoro_activo ON conceptos_tesoreria(activo);

-- ============================================================================
-- TESORERÍA - VALORES
-- ============================================================================

CREATE TABLE valores_tesoreria (
  id SERIAL PRIMARY KEY,
  transaccion_origen_id INTEGER NOT NULL,  -- Link a la operación que generó el valor
  tipo_movimiento INTEGER NOT NULL,         -- Tipo de movimiento
  concepto_tesoreria_id INTEGER REFERENCES conceptos_tesoreria(id),
  fecha_emision DATE,
  fecha_vencimiento DATE,
  banco_id INTEGER,                         -- Si aplica (cheques)
  cuenta VARCHAR(50),                       -- Número de cuenta
  sucursal VARCHAR(50),
  numero VARCHAR(20),                       -- Número de cheque/valor
  numero_interno INTEGER,                   -- Número interno de control
  firma VARCHAR(100),                       -- Firma del cheque
  importe NUMERIC(18,2) NOT NULL,
  cancelado NUMERIC(18,2) DEFAULT 0,
  operador_id INTEGER,                      -- Usuario que registró
  observaciones TEXT,
  tipo_cambio NUMERIC(18,4),               -- Si es moneda extranjera
  importe_base NUMERIC(18,2),              -- Importe en moneda base
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_valores_tesoro_fecha_emision ON valores_tesoreria(fecha_emision);
CREATE INDEX idx_valores_tesoro_fecha_venc ON valores_tesoreria(fecha_vencimiento);
CREATE INDEX idx_valores_tesoro_concepto ON valores_tesoreria(concepto_tesoreria_id);

-- ============================================================================
-- COMENTARIOS FINALES
-- ============================================================================
-- Este schema fue revisado tabla por tabla con el usuario
-- Campos eliminados fueron aprobados tras explicar su uso
-- Reglas especiales de migración documentadas en migration_notes.md
-- ============================================================================
