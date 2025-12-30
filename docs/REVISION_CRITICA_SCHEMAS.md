# REVISIÓN CRÍTICA - Comparación SQL Server vs PostgreSQL Propuesto

## ⚠️ IMPORTANTE: REVISIÓN REQUERIDA

Este documento muestra **TODAS** las columnas de las tablas originales de SQL Server comparadas con las propuestas para PostgreSQL. 

**POR FAVOR REVISA CUIDADOSAMENTE** - Marqué con ❌ las columnas que propuse eliminar. Si alguna es crítica para la lógica del negocio, DEBES indicármelo.

---

## 1. TABLAS CONTABLES CORE

### cuentas (Plan de Cuentas)

#### SQL Server Original (11 columnas):
```sql
[cuenta] INT PRIMARY KEY                    ✅ MANTIENE como 'cuenta'
[descripcion] CHAR(35)                      ✅ MANTIENE como 'descripcion' VARCHAR(100)
[corta] INT                                 ❌ ELIMINÉ - ¿Para qué se usa?
[sigla] CHAR(5)                            ✅ MANTIENE como 'sigla' VARCHAR(10)
[Resumida] CHAR(10)                        ❌ ELIMINÉ - ¿Para qué se usa?
[tipocuentaContable] TINYINT               ✅ MANTIENE como 'tipo_cuenta_contable' SMALLINT
[imputable] TINYINT                        ✅ MANTIENE como 'imputable' BOOLEAN
[Rubro] INT                                ✅ MANTIENE como 'rubro'
[subrubro] INT                             ✅ MANTIENE como 'subrubro'
[UBBalance] INT                            ❌ ELIMINÉ - ¿Para qué se usa? ¿Ubicación en Balance?
[UBResultado] INT                          ❌ ELIMINÉ - ¿Para qué se usa? ¿Ubicación en Estado Resultados?
[CLResultado] INT                          ❌ ELIMINÉ - ¿Para qué se usa?
```

**❓ PREGUNTAS:**
- `corta`: ¿Es un código corto alternativo de cuenta?
- `Resumida`: ¿Es para agrupación en reportes?
- `UBBalance`, `UBResultado`, `CLResultado`: ¿Son para ubicación en reportes financieros?

---

### AsientosDiariosHeader (Encabezado Asientos)

#### SQL Server Original (9 columnas):
```sql
[asiento] INT                              ✅ MANTIENE
[aniomes] INT                              ✅ MANTIENE como 'anio_mes'
[tipoasiento] INT                          ✅ MANTIENE como 'tipo_asiento'
[fecha] DATETIME                           ✅ MANTIENE como DATE
[detalle] VARCHAR(50)                      ✅ MANTIENE VARCHAR(255)
[centrocosto] INT                          ✅ MANTIENE como 'centro_costo'
[AsientoCierre] INT                        ✅ MANTIENE como 'asiento_cierre'
[AsientoInterno] INT                       ❌ ELIMINÉ - ¿Para qué se usa?
[TipoAsInterno] INT                        ❌ ELIMINÉ - ¿Para qué se usa?
```

**❓ PREGUNTAS:**
- `AsientoInterno` y `TipoAsInterno`: ¿Son para vincular con asientos generados automáticamente?

---

### AsientosDiariosItems (Líneas de Asientos)

#### SQL Server Original (9 columnas):
```sql
[asiento] INT                              ✅ MANTIENE (via FK)
[item] INT                                 ✅ MANTIENE
[aniomes] INT                              ✅ MANTIENE (via FK)
[tipoasiento] INT                          ✅ MANTIENE (via FK)
[cuenta] INT                               ✅ MANTIENE como FK a 'cuentas'
[debe] NUMERIC(18,2)                       ✅ MANTIENE
[haber] NUMERIC(18,2)                      ✅ MANTIENE
[observacion] VARCHAR(50)                  ✅ MANTIENE VARCHAR(255)
[centrocosto] INT                          ✅ MANTIENE como 'centro_costo'
```

**✅ TODAS LAS COLUMNAS MANTENIDAS**

---

## 2. SOCIOS (MIEMBROS)

### socios - ⚠️ TABLA CON MÁS CAMBIOS

#### SQL Server Original (70+ columnas):

##### ✅ Datos Personales MANTENIDOS:
```sql
[socio] INT IDENTITY                       ✅ como 'id' SERIAL
[Apellido] CHAR(40)                        ✅ VARCHAR(50)
[nombre] CHAR(40)                          ✅ VARCHAR(50)
[tipodocto] TINYINT                        ✅ como 'tipo_documento' VARCHAR(10)
[numedocto] INT                            ✅ como 'numero_documento' VARCHAR(20)
[Nacionalidad] INT                         ✅ como 'nacionalidad_id'
[Sexo] TINYINT                             ✅ como 'sexo' VARCHAR(1)
[Nacido] DATETIME                          ✅ como 'fecha_nacimiento' DATE
[cuil] CHAR(13)                            ✅ VARCHAR(13)
```

##### ✅ Datos Profesionales MANTENIDOS:
```sql
[Grupo] CHAR(1)                            ✅ CHAR(1)
[nAma] CHAR(10)                            ❌ ELIMINÉ - ¿Número de AMA?
[Residente] CHAR(1)                        ✅ como BOOLEAN
[mesRecibido] TINYINT                      ❌ ELIMINÉ - Combinado en fecha_egreso
[anoRecibido] INT                          ❌ ELIMINÉ - Combinado en fecha_egreso
[tipoMatricula] INT                        ❌ ELIMINÉ - ¿Nacional/Provincial está separado ahora?
[nroMatricula] CHAR(12)                    ✅ como 'matricula_nacional' VARCHAR(20)
[tIpoMatricula2] INT                       ❌ ELIMINÉ
[NroMatricula2] CHAR(12)                   ✅ como 'matricula_provincial' VARCHAR(20)
[FechaIngreso] DATETIME                    ✅ como 'fecha_ingreso' DATE
[FechaBaja] DATETIME                       ✅ como 'fecha_baja' TIMESTAMPTZ
[fresidencia] DATETIME                     ❌ ELIMINÉ - ¿Fecha inicio residencia?
```

##### ✅ Domicilio Principal MANTENIDOS (SOLO UNO):
```sql
[DomicilioPrincipal] CHAR(1)               ❌ ELIMINÉ - Ya no hay 2 domicilios
[Domicilio] VARCHAR(60)                    ✅ VARCHAR(100)
[cpostal] VARCHAR(8)                       ✅ como 'codigo_postal' VARCHAR(10)
[localidad] VARCHAR(50)                    ✅ como 'localidad' VARCHAR(100)
[provincia] INT                            ✅ como 'provincia_id'
[pais] INT                                 ❌ ELIMINÉ - ¿Se usa pais?
[telefono] VARCHAR(100)                    ✅ VARCHAR(50)
[Email] VARCHAR(100)                       ✅ VARCHAR(100)
```

##### ❌ Domicilio Consultorio ELIMINADOS (según tu pedido):
```sql
[Domicilio_consultorio] CHAR(40)           ❌ ELIMINÉ
[cpostal_consultorio] VARCHAR(8)           ❌ ELIMINÉ
[localidad_consultorio] VARCHAR(50)        ❌ ELIMINÉ
[provincia_consultorio] INT                ❌ ELIMINÉ
[pais_consultorio] INT                     ❌ ELIMINÉ
[telefono_consultorio] VARCHAR(50)         ❌ ELIMINÉ
[Fax_Consultorio] VARCHAR(50)              ❌ ELIMINÉ
```

##### ❌ Datos de Cobranza ELIMINADOS:
```sql
[Cobrador] INT                             ❌ ELIMINÉ - ¿Se sigue usando cobrador?
[Tarjeta] INT                              ❌ ELIMINÉ - ¿Se usa débito automático?
[numero] CHAR(16)                          ❌ ELIMINÉ - ¿Número de tarjeta?
[Adherido] CHAR(1)                         ❌ ELIMINÉ
[Vencimiento] DATETIME                     ❌ ELIMINÉ - ¿Vencimiento tarjeta?
[DebitarDesde] DATETIME                    ❌ ELIMINÉ
```

##### ❌ Emails/Observaciones Alternativas ELIMINADAS:
```sql
[EmailAlt1] VARCHAR(50)                    ✅ MANTUVE UNO como 'email_alternativo'
[EmailAlt2] VARCHAR(50)                    ❌ ELIMINÉ
[EmailAlt3] VARCHAR(50)                    ❌ ELIMINÉ
[Fax] VARCHAR(100)                         ❌ ELIMINÉ
[Observa1] NVARCHAR(4000)                  ❌ ELIMINÉ - Ahora en tabla separada observaciones_socios
[Observa2] CHAR(60)                        ❌ ELIMINÉ
```

##### ❌ Campos Sin Propósito Claro ELIMINADOS:
```sql
[gDesde] DATETIME                          ❌ ELIMINÉ - ¿Qué es?
[EstadoCivil] TINYINT                      ❌ ELIMINÉ
[pr] CHAR(10)                              ❌ ELIMINÉ - ¿Qué es?
[prc] CHAR(10)                             ❌ ELIMINÉ
[cpais] CHAR(10)                           ❌ ELIMINÉ
[cpaisc] CHAR(10)                          ❌ ELIMINÉ
[fechanac] DATETIME                        ❌ DUPLICADO de 'Nacido'
[nacdos] CHAR(10)                          ❌ ELIMINÉ
[tdDos] CHAR(10)                           ❌ ELIMINÉ
[ndDos] VARCHAR(50)                        ❌ ELIMINÉ
[amaDos] VARCHAR(50)                       ❌ ELIMINÉ
[Matricula] VARCHAR(50)                    ❌ DUPLICADO
[pairDos] CHAR(10)                         ❌ ELIMINÉ
[PaicDos] CHAR(10)                         ❌ ELIMINÉ
[domicEnvio] TINYINT                       ❌ ELIMINÉ
[FechaGrupo] DATETIME                      ❌ ELIMINÉ
[fResidente] DATETIME                      ❌ DUPLICADO de fresidencia
[identificador] DATETIME                   ❌ ELIMINÉ - ¿Qué es?
[ultimageneracion] DATETIME                ❌ ELIMINÉ - ¿Para sistema de facturación?
[seguro] INT                               ❌ ELIMINÉ
[cuotas] INT                               ❌ ELIMINÉ
[aceptoseguro] INT                         ❌ ELIMINÉ
```

**🚨 TABLA SOCIOS: REVISIÓN URGENTE REQUERIDA**
- De 70+ campos reduje a ~20
- ¿Cobrador se sigue usando?
- ¿Débito automático con tarjeta se usa?
- ¿El campo 'seguro' es importante?
- ¿'ultimageneracion' es para facturación automática?

---

## 3. CONCEPTOS Y FACTURACIÓN

### Conceptos

#### SQL Server Original (11 columnas):
```sql
[Concepto] CHAR(3) PRIMARY KEY             ✅ como 'codigo' VARCHAR(3)
[Entidad] TINYINT                          ✅ como 'entidad' SMALLINT
[Descripcion] CHAR(30)                     ✅ VARCHAR(100)
[Modalidad] CHAR(1)                        ✅ CHAR(1)
[Importe] NUMERIC(18,2)                    ✅ como 'importe_default'
[mes] INT                                  ❌ ELIMINÉ - ¿Para qué mes?
[ano] INT                                  ❌ ELIMINÉ - ¿Para qué año?
[Imputacion_Contable] INT                  ✅ como 'cuenta_contable_id'
[Seguro] INT                               ❌ ELIMINÉ - ¿Tipo de seguro?
[Grupo] CHAR(1)                            ✅ CHAR(1)
[Concepto_Muni] CHAR(3)                    ❌ ELIMINÉ - ¿Municipal?
[Modalidad_Muni] CHAR(1)                   ❌ ELIMINÉ
[Importe_Muni] NUMERIC(18,2)               ❌ ELIMINÉ
[idconcepto] INT IDENTITY                  ✅ como 'id' SERIAL
[Cobertura] NUMERIC(18,0)                  ❌ ELIMINÉ - ¿Cobertura de seguro?
[Comision] NUMERIC(18,2)                   ❌ ELIMINÉ - ¿Comisión tarjeta?
[idCobertura] INT                          ❌ ELIMINÉ
```

**❓ PREGUNTAS:**
- `mes`/`ano`: ¿Son para vigencia de precios por período?
- Campos `_Muni`: ¿Hay tarifas diferentes para municipales?
- `Cobertura`/`Comision`: ¿Son para seguros médicos?

---

### CuentasCorrientes (Cuenta Corriente Socios)

#### SQL Server Original (17 columnas):
```sql
[IdTransaccion] INT IDENTITY               ✅ como 'id' SERIAL
[socio] INT                                ✅ como 'socio_id'
[Entidad] INT                              ✅ como 'entidad'
[Fecha] DATETIME                           ✅ como DATE
[Concepto] CHAR(3)                         ✅ como 'concepto_codigo'
[PuntodeVenta] CHAR(14)                    ✅ como 'punto_venta' VARCHAR(20)
[DocumentoNumero] CHAR(14)                 ✅ como 'documento_numero' VARCHAR(20)
[FechaRendicion] DATETIME                  ❌ ELIMINÉ - ¿Para rendiciones de cobrador?
[Rendicion] VARCHAR(20)                    ❌ ELIMINÉ
[importe] NUMERIC(18,2)                    ✅ NUMERIC(18,2)
[Cancelado] NUMERIC(18,2)                  ✅ NUMERIC(18,2)
[vencimiento] DATETIME                     ✅ como DATE
[Cobrador] INT                             ✅ como 'cobrador_id'
[Serie] VARCHAR(50)                        ❌ ELIMINÉ - ¿Serie de factura?
[idCancelada] NUMERIC(18,0)                ❌ ELIMINÉ - ¿Link a cancelación?
[idOpCobrador] NUMERIC(18,0)               ❌ ELIMINÉ - ¿Op de cobrador?
[rg1] VARCHAR(100)                         ❌ ELIMINÉ - ¿Qué son rg1, rg2, rg3?
[rg2] VARCHAR(100)                         ❌ ELIMINÉ
[rg3] VARCHAR(100)                         ❌ ELIMINÉ
```

**❓ PREGUNTAS:**
- ¿Se siguen usando cobradores y rendiciones?
- ¿Qué son los campos rg1, rg2, rg3?
- ¿Serie es importante para auditcontoría?

---

### DetalleCuentasCorrientes

#### SQL Server Original (5 columnas):
```sql
[idTransaccion] INT                        ✅ como 'cuenta_corriente_id'
[item] INT                                 ✅ MANTIENE
[Concepto] CHAR(3)                         ❌ ELIMINÉ - agregué 'descripcion' en su lugar
[Cantidad] NUMERIC(18,2)                   ❌ ELIMINÉ - ¿Se usa cantidad?
[importe] NUMERIC(18,2)                    ✅ MANTIENE
```

**❓ PREGUNTAS:**
- `Cantidad`: ¿Se usa para conceptos con cantidad (ej: 3 meses)?
- `Concepto`: ¿Cada línea tiene su concepto diferente?

---

## 4. COMPRAS

### TipCompModItems (Config Items de Tipos de Comprobante)

#### SQL Server Original (3 columnas):
```sql
[codigo] INT                               ✅ como 'tipo_comprobante_id'
[concepto] CHAR(5)                         ✅ VARCHAR(3)
[signo] INT                                ❌ ELIMINÉ - ¿Debe/Haber multiplicador?
```

**❓ PREGUNTA:**
- `signo`: ¿Es para indicar si suma o resta en la cuenta contable?

---

### tipventModItems (Config Items de Tipos Venta)

#### SQL Server Original (3 columnas):
```sql
[codigo] INT                               ✅ como 'tipo_comprobante_id'
[concepto] CHAR(5)                         ✅ VARCHAR(3)
[signo] INT                                ❌ ELIMINÉ - ¿Debe/Haber multiplicador?
```

**❓ PREGUNTA:**
- `signo`: ¿Es para indicar si suma o resta en la cuenta contable?

---

## RESUMEN DE CAMPOS ELIMINADOS POR TABLA

| Tabla | Total Original | Propuesta | Eliminados | % Reducción |
|-------|----------------|-----------|------------|-------------|
| cuentas | 12 | 9 | 3 | 25% |
| AsientosDiariosHeader | 9 | 7 | 2 | 22% |
| AsientosDiariosItems | 9 | 9 | 0 | 0% |
| socios | 70+ | 20 | 50+ | 71% |
| Conceptos | 16 | 9 | 7 | 44% |
| CuentasCorrientes | 17 | 13 | 4 | 24% |
| DetalleCuentasCorrientes | 5 | 4 | 1 | 20% |

---

## ACCIÓN REQUERIDA ⚠️

Por favor revisa especialmente:

1. **Tabla socios** - Eliminé 50+ campos (71%)
   - ¿Cobrador/Tarjeta/Débito automático se usan?
   - ¿Seguro y aceptoseguro son importantes?
   - ¿ultimageneracion es para facturación automática?

2. **Tabla Conceptos** - Eliminé campos relacionados a:
   - Municipales (Concepto_Muni, Modalidad_Muni, Importe_Muni)
   - Seguros (Seguro, Cobertura, idCobertura, Comision)
   
3. **Tabla cuentas** - Eliminé:
   - `corta`, `Resumida` - ¿Se usan para reportes?
   - `UBBalance`, `UBResultado`, `CLResultado` - ¿Ubicaciones en estados financieros?

4. **CuentasCorrientes** - Eliminé:
   - Campos de rendición (FechaRendicion, Rendicion, idOpCobrador)
   - Campos rg1, rg2, rg3

**Indica qué campos debo restaurar antes de continuar.**
