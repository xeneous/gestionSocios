# Orden de Ejecución de Scripts de Migración

## 📋 Resumen

Este documento describe el orden correcto para ejecutar todos los scripts de migración desde SQL Server a Supabase/PostgreSQL.

---

## 🗂️ Preparación

### 1. Scripts SQL de Limpieza (ejecutar en Supabase)

**Ubicación:** `database/migrations/`

```bash
# Ejecutar en este orden:
1. limpiar_para_remigracion.sql              # Limpia tablas transaccionales
2. limpiar_espacios_tipos_comprobante.sql    # Elimina espacios de tipos de comprobante
3. deshabilitar_rls.sql                      # Deshabilita Row Level Security
```

**Importante:** El script `limpiar_para_remigracion.sql` borra TODOS los datos de las siguientes tablas:
- `asientos_header`
- `asientos_items`
- `operaciones_detalle_valores_tesoreria`
- `valores_tesoreria`
- `operaciones_detalle_cuentas_corrientes`
- `detalle_cuentas_corrientes`
- `cuentas_corrientes`

---

## 🚀 Orden de Ejecución de Scripts Node.js

**Ubicación:** `scripts/migration/`

### FASE 1: Tablas Maestras y de Referencia

Estas tablas deben migrarse primero porque otras tablas dependen de ellas.

#### 1. Migrar Socios
```bash
node migrate_socios_only.js
```
**Migra:**
- ✅ `socios` (tabla principal de socios/asociados)

**Dependencias:**
- Requiere: `provincias`, `paises`, `tarjetas` (ya deben existir)

---

#### 2. Migrar Tarjetas (si es necesario)
```bash
node migrate_tarjetas_only.js
```
**Migra:**
- ✅ `tarjetas` (catálogo de tarjetas de crédito/débito)

**Nota:** Este script solo es necesario si la tabla de tarjetas no está poblada.

---

### FASE 2: Conceptos y Cuentas

#### 3. Migrar Conceptos y Observaciones
```bash
node migrate_conceptos_observaciones.js
```
**Migra:**
- ✅ `conceptos` (conceptos para cuentas corrientes)
- ✅ Observaciones relacionadas

**Dependencias:**
- Ninguna especial

---

#### 4. Migrar Cuentas Contables
```bash
node migrate_cuentas.js
```
**Migra:**
- ✅ `cuentas` (plan de cuentas contable)

**Dependencias:**
- Ninguna especial

---

### FASE 3: Tablas Transaccionales

#### 5. Migrar Cuentas Corrientes
```bash
node migrate_cuentas_corrientes.js
```
**Migra:**
- ✅ `cuentas_corrientes` (headers de transacciones)
- ✅ `detalle_cuentas_corrientes` (items de transacciones)

**Dependencias:**
- Requiere: `socios`, `profesionales`, `tipos_comprobante_socios`, `conceptos`

**Validaciones:**
- ✅ Valida que socios/profesionales existan
- ✅ Valida que tipos de comprobante existan
- ✅ Valida que conceptos existan
- ⚠️  Omite registros con referencias inválidas

---

#### 6. Migrar Valores de Tesorería
```bash
node migrate_valores_tesoreria.js
```
**Migra:**
- ✅ `conceptos_tesoreria` (conceptos para tesorería)
- ✅ `valores_tesoreria` (cheques, transferencias, etc.)

**Dependencias:**
- Requiere: `conceptos_tesoreria` (se migra en el mismo script)

**Validaciones:**
- ✅ Valida que conceptos de tesorería existan
- ⚠️  Omite valores con conceptos inválidos

---

#### 7. Migrar Asientos de Diario
```bash
node migrate_asientos_diario.js
```
**Migra:**
- ✅ `asientos_header` (headers de asientos contables)
- ✅ `asientos_items` (detalle de asientos contables)

**Dependencias:**
- Requiere: `cuentas` (plan de cuentas)

**Validaciones:**
- ✅ Valida que las cuentas contables existan
- ⚠️  Advierte sobre cuentas no encontradas pero las migra de todos modos

---

## 📊 Diagrama de Dependencias

```
TABLAS BASE (ya existen en Supabase)
├── provincias
├── paises
├── tipos_comprobante_socios
└── profesionales

FASE 1: MAESTRAS
├── tarjetas
└── socios (depende de: provincias, paises, tarjetas)

FASE 2: CONCEPTOS Y CUENTAS
├── conceptos
├── cuentas
└── conceptos_tesoreria

FASE 3: TRANSACCIONALES
├── cuentas_corrientes (depende de: socios, profesionales, tipos_comprobante_socios)
│   └── detalle_cuentas_corrientes (depende de: cuentas_corrientes, conceptos)
├── valores_tesoreria (depende de: conceptos_tesoreria)
│   └── operaciones_detalle_valores_tesoreria (depende de: valores_tesoreria)
└── asientos_header
    └── asientos_items (depende de: asientos_header, cuentas)
```

---

## 🎯 Script de Ejecución Completa

Si quieres ejecutar todo de una vez (después de limpiar con SQL):

```bash
# Ejecutar en orden:
node migrate_socios_only.js &&
node migrate_conceptos_observaciones.js &&
node migrate_cuentas.js &&
node migrate_cuentas_corrientes.js &&
node migrate_valores_tesoreria.js &&
node migrate_asientos_diario.js
```

**⚠️ Advertencia:** Este comando ejecutará todos los scripts en secuencia. Si alguno falla, los siguientes no se ejecutarán.

---

## 🔧 Configuración

Todos los scripts requieren un archivo `.env` en el directorio `scripts/migration/` con:

```env
# SQL Server (origen)
SQLSERVER_SERVER=tu_servidor
SQLSERVER_PORT=1433
SQLSERVER_USER=tu_usuario
SQLSERVER_PASSWORD=tu_password
SQLSERVER_DATABASE=tu_base_datos

# Supabase (destino)
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key
```

---

## ✅ Verificación Post-Migración

Después de ejecutar todos los scripts, verifica:

### 1. Contar registros en cada tabla

```sql
-- En Supabase SQL Editor:
SELECT 'socios' as tabla, COUNT(*) as registros FROM socios
UNION ALL
SELECT 'cuentas_corrientes', COUNT(*) FROM cuentas_corrientes
UNION ALL
SELECT 'detalle_cuentas_corrientes', COUNT(*) FROM detalle_cuentas_corrientes
UNION ALL
SELECT 'valores_tesoreria', COUNT(*) FROM valores_tesoreria
UNION ALL
SELECT 'asientos_header', COUNT(*) FROM asientos_header
UNION ALL
SELECT 'asientos_items', COUNT(*) FROM asientos_items
ORDER BY tabla;
```

### 2. Verificar integridad referencial

```sql
-- Verificar que no hay cuentas_corrientes huérfanas
SELECT COUNT(*) as huerfanas
FROM cuentas_corrientes cc
WHERE (cc.socio_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM socios s WHERE s.id = cc.socio_id
))
OR (cc.profesional_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM profesionales p WHERE p.id = cc.profesional_id
));
```

### 3. Ejecutar script de limpieza para verificar

```bash
node verify_migration.js  # (crear este script si es necesario)
```

---

## 🚨 Troubleshooting

### Error: "violates foreign key constraint"

**Causa:** Estás intentando migrar una tabla antes de sus dependencias.

**Solución:** Revisa el orden de ejecución y asegúrate de seguir las fases.

---

### Error: "duplicate key value violates unique constraint"

**Causa:** Ya existen datos en la tabla destino.

**Solución:** Ejecuta el script de limpieza SQL primero.

---

### Algunos registros son omitidos

**Causa:** Los scripts validan foreign keys y omiten registros con referencias inválidas.

**Solución:**
1. Revisa los logs del script para ver qué se omitió
2. Verifica que las tablas de referencia estén migradas
3. Verifica que los datos en SQL Server sean consistentes

---

## 📝 Notas Adicionales

### Re-migración

Si necesitas volver a ejecutar la migración:

1. Ejecuta `limpiar_para_remigracion.sql` en Supabase
2. Vuelve a ejecutar los scripts en orden

### Logs

Todos los scripts generan logs detallados en consola que muestran:
- ✅ Registros migrados exitosamente
- ⚠️  Registros omitidos (con razón)
- ❌ Errores encontrados

### Performance

Los scripts usan batch processing (lotes de 100-1000 registros) para optimizar la velocidad de migración.

---

## 🆘 Soporte

Si encuentras problemas durante la migración, revisa:

1. Los logs en consola de cada script
2. Los mensajes de error de PostgreSQL
3. La configuración del archivo `.env`
4. Las tablas de referencia que deben existir previamente

---

**Última actualización:** 2026-01-09
