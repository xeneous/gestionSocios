# Guía de Ejecución: Refactor Cuentas + Migración

## ⚠️ IMPORTANTE: Ejecutar en este orden exacto

---

## PASO 1: Refactor Base de Datos en Supabase

### 1.1 - Refactorizar tabla cuentas

**Archivo:** [`refactor_cuentas_pk.sql`](file:///c:/Users/Daniel/StudioProjects/SAO%202026/database/refactor_cuentas_pk.sql)

**Acciones:**
1. Abrir Supabase → SQL Editor
2. Copiar y pegar el contenido completo del archivo
3. Ejecutar
4. Verificar que las queries de verificación al final muestren:
   - ✅ Columna `id` eliminada
   - ✅ Columna `cuenta` es PRIMARY KEY
   - ✅ 7 Foreign Keys apuntando a `cuentas(cuenta)`

### 1.2 - Actualizar tabla conceptos

**Archivo:** [`update_conceptos_cuenta.sql`](file:///c:/Users/Daniel/StudioProjects/SAO%202026/database/update_conceptos_cuenta.sql)

**Acciones:**
1. En el mismo SQL Editor de Supabase
2. Copiar y pegar el contenido del archivo
3. Ejecutar
4. Verificar que la query final muestre:
   - ✅ Columna `cuenta_contable` existe
   - ✅ Columna `cuenta_contable_id` NO existe

---

## PASO 2: Migración de Datos desde SQL Server

### 2.1 - Migrar Plan de Cuentas

**Archivo:** [`migrate_cuentas.js`](file:///c:/Users/Daniel/StudioProjects/SAO%202026/scripts/migration/migrate_cuentas.js)

**Comando:**
```bash
cd "c:\Users\Daniel\StudioProjects\SAO 2026\scripts\migration"
node migrate_cuentas.js
```

**Verificar:**
- ✅ Se migran todas las cuentas
- ✅ Muestra tabla de muestra al final
- ✅ Sin errores

### 2.2 - Migrar Conceptos, Conceptos_Socios y Observaciones

**Archivo:** [`migrate_conceptos_observaciones.js`](file:///c:/Users/Daniel/StudioProjects/SAO%202026/scripts/migration/migrate_conceptos_observaciones.js)

**Comando:**
```bash
cd "c:\Users\Daniel\StudioProjects\SAO 2026\scripts\migration"
node migrate_conceptos_observaciones.js
```

**Verificar:**
- ✅ Se migran conceptos (con cuenta_contable válida)
- ✅ Se migran conceptos_socios
- ✅ Se migran observaciones_socios
- ✅ Sin errores de FKs

---

## PASO 3: Verificación en Supabase

### 3.1 - Verificar integridad de datos

Ejecutar en Supabase SQL Editor:

```sql
-- Verificar cuentas
SELECT COUNT(*) as total_cuentas FROM cuentas;

-- Verificar conceptos con cuentas válidas
SELECT 
    c.concepto,
    c.descripcion,
    c.cuenta_contable,
    ct.descripcion as cuenta_desc
FROM conceptos c
LEFT JOIN cuentas ct ON c.cuenta_contable = ct.cuenta
LIMIT 10;

-- Verificar que NO haya conceptos con cuentas inválidas
SELECT COUNT(*) as conceptos_sin_cuenta_valida
FROM conceptos c
LEFT JOIN cuentas ct ON c.cuenta_contable = ct.cuenta
WHERE c.cuenta_contable IS NOT NULL AND ct.cuenta IS NULL;
-- Debe retornar 0

-- Conteos finales
SELECT 
  (SELECT COUNT(*) FROM cuentas) as total_cuentas,
  (SELECT COUNT(*) FROM conceptos) as total_conceptos,
  (SELECT COUNT(*) FROM conceptos_socios) as total_conceptos_socios,
  (SELECT COUNT(*) FROM observaciones_socios) as total_observaciones;
```

---

## PASO 4: Actualizar Código Flutter

**PENDIENTE** - Se hará después de verificar que la migración fue exitosa

---

## 📋 Checklist de Ejecución

- [ ] Paso 1.1: Refactorizar tabla cuentas en Supabase
- [ ] Paso 1.2: Actualizar tabla conceptos en Supabase
- [ ] Paso 2.1: Migrar plan de cuentas
- [ ] Paso 2.2: Migrar conceptos y observaciones
- [ ] Paso 3.1: Verificar integridad de datos

**Una vez completado todo, avísame para continuar con el código Flutter.**
