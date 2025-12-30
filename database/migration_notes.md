# Notas de Migración SQL Server → PostgreSQL

## Reglas Especiales de Migración

### Tabla: `socios`

#### 1. Domicilio (UN SOLO DOMICILIO)
**Campo en SQL Server:** `DomicilioPrincipal` (CHAR(1))
- Valores: 'P' = Particular, 'C' = Consultorio

**Regla de migración:**
```sql
-- Si DomicilioPrincipal = 'P' migrar campos Particular
-- Si DomicilioPrincipal = 'C' migrar campos Consultorio

CASE 
  WHEN DomicilioPrincipal = 'P' THEN
    domicilio = Domicilio
    localidad = localidad
    provincia_id = provincia
    codigo_postal = cpostal
    telefono = telefono
  WHEN DomicilioPrincipal = 'C' THEN
    domicilio = Domicilio_consultorio
    localidad = localidad_consultorio
    provincia_id = provincia_consultorio
    codigo_postal = cpostal_consultorio
    telefono = telefono_consultorio
END
```

#### 2. Matrículas (Nacional vs Provincial)
**Campos en SQL Server:**
- `tipoMatricula` (INT)
- `nroMatricula` (CHAR(12))
- `tipoMatricula2` (INT)
- `NroMatricula2` (CHAR(12))

**Regla de migración:**
```sql
-- Usar campo tipoMatricula para determinar Nacional/Provincial
-- Revisar valores en tabla tipos de matrícula del sistema actual
-- Mapear según corresponda

-- Ejemplo (ajustar según valores reales):
IF tipoMatricula = 1 THEN
  matricula_nacional = nroMatricula
ELSE IF tipoMatricula = 2 THEN
  matricula_provincial = nroMatricula

IF tipoMatricula2 = 1 THEN
  matricula_nacional = NroMatricula2
ELSE IF tipoMatricula2 = 2 THEN
  matricula_provincial = NroMatricula2
```

#### 3. Observaciones
**Campos en SQL Server:**
- `Observa1` (NVARCHAR(4000))
- `Observa2` (CHAR(60))

**Regla de migración:**
```sql
-- Migrar a tabla observaciones_socios
-- Si Observa1 tiene contenido, crear registro
-- Si Observa2 tiene contenido, crear segundo registro

INSERT INTO observaciones_socios (socio_id, fecha, observacion)
SELECT 
  socio, 
  FechaIngreso, -- o CURRENT_DATE
  Observa1
FROM socios
WHERE Observa1 IS NOT NULL AND LTRIM(RTRIM(Observa1)) <> '';

INSERT INTO observaciones_socios (socio_id, fecha, observacion)
SELECT 
  socio,
  FechaIngreso,
  Observa2
FROM socios  
WHERE Observa2 IS NOT NULL AND LTRIM(RTRIM(Observa2)) <> '';
```

---

### Tabla: `cuentas`

**Migración directa** - Todos los campos se mapean 1:1

---

### Tabla: `AsientosDiariosHeader`

**Migración directa** - Campos eliminados no necesitan lógica especial

---

### Tabla: `AsientosDiariosItems`

**Migración directa** - Se mantiene estructura completa

---

### Tabla: `Conceptos`

**Migración directa** - Campos eliminados (seguros, municipales) se descartan

---

### Tabla: `CuentasCorrientes`

**Migración directa** - Campos de cobrador y rendición se descartan

---

### Tabla: `DetalleCuentasCorrientes`

**Migración directa** - Campo cantidad siempre migra con valor default 1 si es NULL

---

### Tabla: `Clientes` y `Proveedores`

**Teléfonos:**
```sql
-- Migrar solo primeros 2 teléfonos
telefono = Telefono1
telefono_secundario = Telefono2
-- Telefono3-6 se descartan
```

**Campos impositivos eliminados:**
- percepcionIB
- retencionIB  
- Jurisdiccion
- CuentaSubdiario

Se descartan durante migración.

---

### Tabla: `Profesionales`

**Misma estructura que socios** - Aplicar mismas reglas de:
- Domicilio
- Matrículas
- Observaciones (si aplica)

---

## Mapeo de Tipos de Datos

| SQL Server | PostgreSQL | Notas |
|------------|------------|-------|
| INT | INTEGER | Directo |
| INT IDENTITY | SERIAL | Auto-incremento |
| TINYINT | SMALLINT | PostgreSQL no tiene TINYINT |
| CHAR(n) | CHAR(n) o VARCHAR(n) | Preferir VARCHAR para flexibilidad |
| NVARCHAR(n) | VARCHAR(n) | PostgreSQL UTF-8 por defecto |
| DATETIME | TIMESTAMPTZ o DATE | Según necesidad timezone |
| NUMERIC(18,2) | NUMERIC(18,2) | Directo |
| BIT | BOOLEAN | Mapear 0/1 a FALSE/TRUE |

---

## Validaciones Post-Migración

### 1. Conteos de registros
```sql
-- Verificar que coincidan cantidades migradas
SELECT 'socios', COUNT(*) FROM socios;
SELECT 'clientes', COUNT(*) FROM clientes;
SELECT 'proveedores', COUNT(*) FROM proveedores;
SELECT 'cuentas', COUNT(*) FROM cuentas;
-- etc.
```

### 2. Balances contables
```sql
-- Verificar que asientos cuadren
SELECT 
  asiento, anio_mes, tipo_asiento,
  SUM(debe) as total_debe,
  SUM(haber) as total_haber,
  SUM(debe) - SUM(haber) as diferencia
FROM asientos_items
GROUP BY asiento, anio_mes, tipo_asiento
HAVING SUM(debe) - SUM(haber) <> 0;
-- Debe retornar 0 registros
```

### 3. Referencias FK
```sql
-- Verificar integridad referencial
-- Cuentas en items que existan en plan de cuentas
SELECT COUNT(*) 
FROM asientos_items ai
LEFT JOIN cuentas c ON ai.cuenta_id = c.id
WHERE c.id IS NULL;
-- Debe retornar 0
```

### 4. Emails duplicados
```sql
-- Verificar emails únicos si es requerimiento
SELECT email, COUNT(*) 
FROM socios 
WHERE email IS NOT NULL
GROUP BY email 
HAVING COUNT(*) > 1;
```

---

## Scripts de Migración

Los scripts de migración completassarán:

1. `01_create_schema.sql` - Schema PostgreSQL completo
2. `02_migrate_reference_data.sql` - Provincias, Categorías IVA, etc.
3. `03_migrate_plan_cuentas.sql` - Plan de cuentas
4. `04_migrate_entities.sql` - Socios, Clientes, Proveedores
5. `05_migrate_transactional.sql` - Asientos, Cuentas Corrientes
6. `06_validate.sql` - Validaciones post-migración

---

## Consideraciones Importantes

1. **Encoding:** SQL Server usa UTF-16, PostgreSQL UTF-8. Asegurar conversión correcta.

2. **Secuencias:** Los campos IDENTITY migran a SERIAL. Verificar que las secuencias inicien en el valor correcto:
```sql
SELECT setval('socios_id_seq', (SELECT MAX(id) FROM socios));
```

3. **Fechas NULL:** SQL Server permite varias representaciones. Normalizar a NULL en PostgreSQL.

4. **Strings vacíos vs NULL:** Decidir si '' debe migrar como '' o NULL. Recomendación: NULL para consistencia.

5. **Backup:** SIEMPRE tener backup completo de SQL Server antes de migración.

---

## Próximos Pasos

Una vez aprobado el schema final:
1. Crear proyecto Supabase
2. Ejecutar schema_postgresql.sql
3. Desarrollar scripts de migración de datos
4. Probar migración en ambiente de desarrollo
5. Validar con usuario
6. Migración a producción
