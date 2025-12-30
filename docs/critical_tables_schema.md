# SAO 2026 - Critical Tables Schema Documentation

## User-Confirmed Essential Tables

This document lists all tables marked as critical by the user, with their current SQL Server structure and proposed PostgreSQL migration.

---

## 1. CORE ACCOUNTING

### cuentas (Chart of Accounts)
**Current Structure:**
```sql
-- SQL Server
[cuenta] INT PRIMARY KEY
[descripcion] CHAR(35)
[corta] INT
[sigla] CHAR(5)
[Resumida] CHAR(10)
[tipocuentaContable] TINYINT
[imputable] TINYINT
[Rubro] INT
[subrubro] INT
[UBBalance] INT
[UBResultado] INT
[CLResultado] INT
```

**Proposed PostgreSQL:**
```sql
CREATE TABLE cuentas (
  id SERIAL PRIMARY KEY,
  cuenta INTEGER UNIQUE NOT NULL,
  descripcion VARCHAR(100) NOT NULL,
  sigla VARCHAR(10),
  tipo_cuenta_contable SMALLINT,
  imputable BOOLEAN DEFAULT false,
  rubro INTEGER,
  subrubro INTEGER,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### AsientosDiariosHeader (Journal Entry Headers)
**Current Structure:**
```sql
-- SQL Server
[asiento] INT NOT NULL
[aniomes] INT NOT NULL
[tipoasiento] INT NOT NULL
[fecha] DATETIME NOT NULL
[detalle] VARCHAR(50)
[centrocosto] INT NOT NULL
[AsientoCierre] INT
[AsientoInterno] INT
[TipoAsInterno] INT
PRIMARY KEY (asiento, aniomes, tipoasiento)
```

**Proposed PostgreSQL:**
```sql
CREATE TABLE asientos_header (
  id SERIAL PRIMARY KEY,
  asiento INTEGER NOT NULL,
  anio_mes INTEGER NOT NULL,
  tipo_asiento INTEGER NOT NULL,
  fecha DATE NOT NULL,
  detalle VARCHAR(255),
  centro_costo INTEGER,
  asiento_cierre INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(asiento, anio_mes, tipo_asiento)
);
```

---

### AsientosDiariosItems (Journal Entry Lines)
**Current Structure:**
```sql
-- SQL Server
[asiento] INT NOT NULL
[item] INT NOT NULL
[aniomes] INT NOT NULL
[tipoasiento] INT NOT NULL
[cuenta] INT NOT NULL
[debe] NUMERIC(18, 2)
[haber] NUMERIC(18, 2)
[observacion] VARCHAR(50)
[centrocosto] INT
```

**Proposed PostgreSQL:**
```sql
CREATE TABLE asientos_items (
  id SERIAL PRIMARY KEY,
  asiento_header_id INTEGER REFERENCES asientos_header(id) ON DELETE CASCADE,
  item INTEGER NOT NULL,
  cuenta_id INTEGER REFERENCES cuentas(id),
  debe NUMERIC(18,2) DEFAULT 0,
  haber NUMERIC(18,2) DEFAULT 0,
  observacion VARCHAR(255),
  centro_costo INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_asientos_items_header ON asientos_items(asiento_header_id);
CREATE INDEX idx_asientos_items_cuenta ON asientos_items(cuenta_id);
```

---

## 2. MEMBERS & ENTITIES

### socios (Members)
**Current Structure:** 70+ fields (see schema_utf8.sql line 63-134)

**Proposed Simplified PostgreSQL:**
```sql
CREATE TABLE socios (
  id SERIAL PRIMARY KEY,
  
  -- Personal Info
  apellido VARCHAR(50) NOT NULL,
  nombre VARCHAR(50) NOT NULL,
  tipo_documento VARCHAR(10),
  numero_documento VARCHAR(20),
  cuil VARCHAR(13),
  nacionalidad_id INTEGER,
  sexo VARCHAR(1),
  fecha_nacimiento DATE,
  
  -- Professional Info
  matricula_nacional VARCHAR(20),
  matricula_provincial VARCHAR(20),
  especialidad VARCHAR(100),
  grupo CHAR(1),
  residente BOOLEAN DEFAULT false,
  fecha_ingreso DATE,
  fecha_egreso DATE,
  
  -- Contact (single address)
  domicilio VARCHAR(100),
  localidad VARCHAR(100),
  provincia_id INTEGER REFERENCES provincias(id),
  codigo_postal VARCHAR(10),
  telefono VARCHAR(50),
  celular VARCHAR(50),
  email VARCHAR(100),
  email_alternativo VARCHAR(100),
  
  -- Status & Billing
  activo BOOLEAN DEFAULT true,
  fecha_baja TIMESTAMPTZ,
  cobrador_id INTEGER,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_socios_documento ON socios(numero_documento);
CREATE INDEX idx_socios_email ON socios(email);
CREATE INDEX idx_socios_activo ON socios(activo);
```

---

### clientes (Customers)
**Current Structure:** See schema line 312-365

**Proposed PostgreSQL:**
```sql
CREATE TABLE clientes (
  id SERIAL PRIMARY KEY,
  razon_social VARCHAR(100) NOT NULL,
  nombre VARCHAR(50),
  apellido VARCHAR(50),
  cuit VARCHAR(13),
  
  -- Address
  domicilio VARCHAR(100),
  localidad VARCHAR(100),
  provincia_id INTEGER REFERENCES provincias(id),
  codigo_postal VARCHAR(10),
  
  -- Contact
  telefono VARCHAR(50),
  email VARCHAR(100),
  
  -- Tax & Accounting
  categoria_iva_id INTEGER,
  cuenta_contable_id INTEGER REFERENCES cuentas(id),
  
  -- Status
  activo BOOLEAN DEFAULT true,
  fecha_baja TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### proveedores (Suppliers)
**Current Structure:** See schema line 622-674

**Proposed PostgreSQL:**
```sql
CREATE TABLE proveedores (
  id SERIAL PRIMARY KEY,
  razon_social VARCHAR(100) NOT NULL,
  nombre VARCHAR(50),
  apellido VARCHAR(50),
  cuit VARCHAR(13),
  
  -- Address
  domicilio VARCHAR(100),
  localidad VARCHAR(100),
  provincia_id INTEGER REFERENCES provincias(id),
  codigo_postal VARCHAR(10),
  
  -- Contact
  telefono VARCHAR(50),
  email VARCHAR(100),
  
  -- Tax & Accounting
  categoria_iva_id INTEGER,
  cuenta_contable_id INTEGER REFERENCES cuentas(id),
  
  -- Status
  activo BOOLEAN DEFAULT true,
  fecha_baja TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### Profesionales
**Purpose:** Professional staff/doctors registry

**Proposed PostgreSQL:**
```sql
CREATE TABLE profesionales (
  id SERIAL PRIMARY KEY,
  apellido VARCHAR(50) NOT NULL,
  nombre VARCHAR(50) NOT NULL,
  matricula VARCHAR(20),
  especialidad VARCHAR(100),
  email VARCHAR(100),
  telefono VARCHAR(50),
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 3. MEMBER ACCOUNTS & BILLING

### CuentasCorrientes (Member Current Accounts)
**Current Structure:**
```sql
-- SQL Server
[IdTransaccion] INT IDENTITY PRIMARY KEY
[socio] INT NOT NULL
[Entidad] INT NOT NULL
[Fecha] DATETIME NOT NULL
[Concepto] CHAR(3) NOT NULL
[PuntodeVenta] CHAR(14)
[DocumentoNumero] CHAR(14)
[FechaRendicion] DATETIME
[Rendicion] VARCHAR(20)
[importe] NUMERIC(18, 2)
[Cancelado] NUMERIC(18, 2)
[vencimiento] DATETIME
[Cobrador] INT
```

**Proposed PostgreSQL:**
```sql
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
  cobrador_id INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cc_socio ON cuentas_corrientes(socio_id);
CREATE INDEX idx_cc_fecha ON cuentas_corrientes(fecha);
```

---

### DetalleCuentasCorrientes (CC Details)
**Purpose:** Detail lines for member account transactions

**Proposed PostgreSQL:**
```sql
CREATE TABLE detalle_cuentas_corrientes (
  id SERIAL PRIMARY KEY,
  cuenta_corriente_id INTEGER REFERENCES cuentas_corrientes(id) ON DELETE CASCADE,
  item INTEGER,
  descripcion VARCHAR(255),
  importe NUMERIC(18,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### Conceptos (Billing Concepts)
**Current Structure:**
```sql
-- SQL Server
[Concepto] CHAR(3) PRIMARY KEY
[Entidad] TINYINT NOT NULL
[Descripcion] CHAR(30)
[Modalidad] CHAR(1)
[Importe] NUMERIC(18, 2)
[mes] INT
[ano] INT
[Imputacion_Contable] INT
[Grupo] CHAR(1)
```

**Proposed PostgreSQL:**
```sql
CREATE TABLE conceptos (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(3) UNIQUE NOT NULL,
  entidad SMALLINT NOT NULL,
  descripcion VARCHAR(100),
  modalidad CHAR(1),
  importe_default NUMERIC(18,2),
  cuenta_contable_id INTEGER REFERENCES cuentas(id),
  grupo CHAR(1),
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### Conceptos_Socios (Member-Concept Assignments)
**Current Structure:**
```sql
-- SQL Server
[socio] INT NOT NULL
[Concepto] CHAR(3) NOT NULL
[FechaAlta] DATETIME
[FecHaVigencia] DATETIME
[Importe] NUMERIC(18, 2)
[FechaBaja] DATETIME
[Activo] INT
```

**Proposed PostgreSQL:**
```sql
CREATE TABLE conceptos_socios (
  id SERIAL PRIMARY KEY,
  socio_id INTEGER REFERENCES socios(id),
  concepto_codigo VARCHAR(3) REFERENCES conceptos(codigo),
  fecha_alta DATE,
  fecha_vigencia DATE,
  importe_personalizado NUMERIC(18,2),
  fecha_baja DATE,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_conceptos_socios_socio ON conceptos_socios(socio_id);
```

---

### Conceptos_Profesionales (Professional-Concept Assignments)
**Proposed PostgreSQL:**
```sql
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
```

---

### observaciones_Socios (Member Notes)
**Proposed PostgreSQL:**
```sql
CREATE TABLE observaciones_socios (
  id SERIAL PRIMARY KEY,
  socio_id INTEGER REFERENCES socios(id),
  fecha DATE NOT NULL,
  observacion TEXT,
  usuario VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_obs_socios_socio ON observaciones_socios(socio_id);
```

---

## 4. PURCHASES MODULE

### CompProvHeader (Purchase Headers)
**Current Structure:** See schema line 480-506

**Proposed PostgreSQL:**
```sql
CREATE TABLE compras_header (
  id SERIAL PRIMARY KEY,
  comprobante INTEGER NOT NULL,
  anio_mes INTEGER NOT NULL,
  fecha DATE NOT NULL,
  proveedor_id INTEGER REFERENCES proveedores(id),
  tipo_comprobante_id INTEGER,
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
```

---

### CompProvItems (Purchase Line Items)
**Proposed PostgreSQL:**
```sql
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
```

---

### TipCompModHeader (Purchase Voucher Types)
**Current Structure:** See schema line 513-531

**Proposed PostgreSQL:**
```sql
CREATE TABLE tipos_comprobante_compra (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(10) UNIQUE NOT NULL,
  descripcion VARCHAR(100) NOT NULL,
  signo INTEGER,
  multiplicador INTEGER,
  iva_compras BOOLEAN DEFAULT false,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### TipCompModItems (Purchase Voucher Configuration Items)
**Proposed PostgreSQL:**
```sql
CREATE TABLE tipos_comprobante_compra_items (
  id SERIAL PRIMARY KEY,
  tipo_comprobante_id INTEGER REFERENCES tipos_comprobante_compra(id) ON DELETE CASCADE,
  item INTEGER,
  concepto VARCHAR(3),
  cuenta_id INTEGER REFERENCES cuentas(id),
  descripcion VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 5. SALES MODULE

### tipventModHeader (Sales Voucher Types)
**Current Structure:** See schema line 206-232

**Proposed PostgreSQL:**
```sql
CREATE TABLE tipos_comprobante_venta (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(10) UNIQUE NOT NULL,
  descripcion VARCHAR(100) NOT NULL,
  signo INTEGER,
  multiplicador INTEGER,
  iva_ventas BOOLEAN DEFAULT false,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### tipventModItems (Sales Voucher Configuration Items)
**Proposed PostgreSQL:**
```sql
CREATE TABLE tipos_comprobante_venta_items (
  id SERIAL PRIMARY KEY,
  tipo_comprobante_id INTEGER REFERENCES tipos_comprobante_venta(id) ON DELETE CASCADE,
  item INTEGER,
  concepto VARCHAR(3),
  cuenta_id INTEGER REFERENCES cuentas(id),
  descripcion VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 6. PAYMENT METHODS & CARDS

### Tarjetas (Credit/Debit Cards)
**Proposed PostgreSQL:**
```sql
CREATE TABLE tarjetas (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL,
  tipo VARCHAR(20),
  comision NUMERIC(5,2),
  dias_acreditacion INTEGER,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### PresentacionesTarjetas (Card Batch Submissions)
**Proposed PostgreSQL:**
```sql
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
```

---

## 7. CATEGORIZATION

### Grupos_Agrupados (Member Groups/Categories)
**Proposed PostgreSQL:**
```sql
CREATE TABLE grupos_agrupados (
  id SERIAL PRIMARY KEY,
  codigo CHAR(1) UNIQUE NOT NULL,
  descripcion VARCHAR(100),
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Summary

**Total Critical Tables:** 24 core tables + reference tables

### Implementation Priority:
1. **Phase 1 (Foundation):** cuentas, provincias, conceptos
2. **Phase 2 (Accounting):** asientos_header, asientos_items
3. **Phase 3 (Members):** socios, conceptos_socios, cuentas_corrientes
4. **Phase 4 (Transactions):** compras, tipos_comprobante
5. **Phase 5 (Payments):** tarjetas, presentaciones_tarjetas

---

**Note:** This schema is designed to be extensible. Additional tables can be added as needed without disrupting the core structure.
