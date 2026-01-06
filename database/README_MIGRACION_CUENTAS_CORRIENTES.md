# Guía de Migración de Cuentas Corrientes con IDs Específicos

## Problema

Al migrar datos de cuentas corrientes desde otra fuente, enfrentamos estos desafíos:
1. **Foreign Keys**: La tabla `detalle_cuentas_corrientes` referencia a `cuentas_corrientes`
2. **Campos SERIAL**: El campo `idtransaccion` es autoincrementable
3. **IDs Específicos**: Necesitamos mantener los IDs originales de la migración

## Solución

PostgreSQL permite insertar con IDs específicos usando `OVERRIDING SYSTEM VALUE` y manejar constraints temporalmente.

---

## 📋 Scripts Disponibles

### 1. `migrate_cuentas_corrientes_complete.sql`
**Uso**: Migración completa con IDs específicos

**Características**:
- ✅ Deshabilita triggers temporalmente
- ✅ Permite insertar con IDs específicos usando `OVERRIDING SYSTEM VALUE`
- ✅ Actualiza la secuencia automáticamente
- ✅ Incluye verificaciones de integridad
- ✅ Todo dentro de una transacción (puedes hacer ROLLBACK si algo falla)

**Cuándo usarlo**: Cuando tienes un script de Node.js o datos en CSV/JSON y necesitas migrar todo de una vez.

---

### 2. `delete_cuentas_corrientes_safe.sql`
**Uso**: Borrado seguro de datos existentes

**Opciones**:
- **Opción 1**: Borrar registros específicos por condición
- **Opción 2**: Borrar todo y reiniciar secuencias (TRUNCATE)
- **Opción 3**: Borrar todo sin reiniciar secuencia

**Cuándo usarlo**: Antes de migrar, para limpiar datos de prueba o empezar desde cero.

---

### 3. `migration_helper_cuentas_corrientes.sql`
**Uso**: Referencia y ejemplos para casos específicos

**Incluye**:
- Comandos para deshabilitar/habilitar triggers
- Ejemplos de INSERT con IDs específicos
- Comandos para actualizar secuencias
- Verificaciones de integridad

**Cuándo usarlo**: Como referencia o para copiar comandos específicos.

---

## 🚀 Flujo Recomendado de Migración

### Paso 1: Backup
```sql
-- Hacer backup de las tablas (por si acaso)
CREATE TABLE cuentas_corrientes_backup AS SELECT * FROM cuentas_corrientes;
CREATE TABLE detalle_cuentas_corrientes_backup AS SELECT * FROM detalle_cuentas_corrientes;
```

### Paso 2: Limpiar datos existentes (si es necesario)
```sql
-- Ejecutar delete_cuentas_corrientes_safe.sql
-- O manualmente:
BEGIN;
ALTER TABLE cuentas_corrientes DISABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes DISABLE TRIGGER ALL;
TRUNCATE TABLE cuentas_corrientes RESTART IDENTITY CASCADE;
ALTER TABLE cuentas_corrientes ENABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes ENABLE TRIGGER ALL;
COMMIT;
```

### Paso 3: Migrar datos
Editar `migrate_cuentas_corrientes_complete.sql` y reemplazar los datos de ejemplo con tus datos reales:

```sql
-- En FASE 3, reemplazar:
INSERT INTO cuentas_corrientes (...)
OVERRIDING SYSTEM VALUE
VALUES
  (1, 123, 'CS ', 1, '202601', '2026-01-15', 5000.00, 0, 'Cuota'),
  (2, 124, 'CS ', 2, '202601', '2026-01-15', 5000.00, 0, 'Cuota'),
  -- ... más registros

-- En FASE 4, reemplazar:
INSERT INTO detalle_cuentas_corrientes (...)
VALUES
  (1, 1, 'CS', 5000.00, 'Cuota Social'),
  (2, 1, 'CS', 5000.00, 'Cuota Social'),
  -- ... más registros
```

### Paso 4: Ejecutar y verificar
```sql
-- Ejecutar el script completo
-- Si hay errores, la transacción hace ROLLBACK automático
-- Si todo está OK, hace COMMIT
```

---

## 💻 Integración con Node.js

Si estás usando el script de Node.js para migrar:

### Opción A: Generar SQL desde Node.js
```javascript
// En tu script de Node.js
const fs = require('fs');

// Generar archivo SQL con todos los INSERTs
let sql = `
BEGIN;

ALTER TABLE cuentas_corrientes DISABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes DISABLE TRIGGER ALL;

-- Headers
INSERT INTO cuentas_corrientes (
  idtransaccion, socio_id, tipo_comprobante, numero_comprobante,
  documento_numero, fecha, importe, saldo, observaciones
)
OVERRIDING SYSTEM VALUE
VALUES\n`;

// Agregar registros
cuentasCorrientes.forEach((cc, index) => {
  sql += `  (${cc.idtransaccion}, ${cc.socio_id}, '${cc.tipo_comprobante}', ` +
         `${cc.numero_comprobante}, '${cc.documento_numero}', ` +
         `'${cc.fecha}', ${cc.importe}, ${cc.saldo}, '${cc.observaciones}')`;
  sql += index < cuentasCorrientes.length - 1 ? ',\n' : ';\n\n';
});

// Detalles
sql += `INSERT INTO detalle_cuentas_corrientes (idtransaccion, item, concepto_codigo, importe, observaciones)\nVALUES\n`;

detalles.forEach((det, index) => {
  sql += `  (${det.idtransaccion}, ${det.item}, '${det.concepto_codigo}', ` +
         `${det.importe}, '${det.observaciones}')`;
  sql += index < detalles.length - 1 ? ',\n' : ';\n\n';
});

// Finalizar
sql += `
SELECT setval('cuentas_corrientes_idtransaccion_seq',
  (SELECT COALESCE(MAX(idtransaccion), 0) FROM cuentas_corrientes), true);

ALTER TABLE cuentas_corrientes ENABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes ENABLE TRIGGER ALL;

COMMIT;
`;

fs.writeFileSync('generated_migration.sql', sql);
console.log('✓ SQL generado: generated_migration.sql');
```

### Opción B: Usar Supabase Client directamente
```javascript
// Deshabilitar triggers primero (ejecutar SQL manual)
// Luego insertar en lotes:

const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(URL, KEY);

// Insertar headers en lotes de 1000
for (let i = 0; i < headers.length; i += 1000) {
  const batch = headers.slice(i, i + 1000);

  const { error } = await supabase
    .from('cuentas_corrientes')
    .insert(batch);

  if (error) throw error;
  console.log(`Headers: ${i + batch.length}/${headers.length}`);
}

// Insertar detalles en lotes de 1000
for (let i = 0; i < detalles.length; i += 1000) {
  const batch = detalles.slice(i, i + 1000);

  const { error } = await supabase
    .from('detalle_cuentas_corrientes')
    .insert(batch);

  if (error) throw error;
  console.log(`Detalles: ${i + batch.length}/${detalles.length}`);
}

// Actualizar secuencia (ejecutar SQL manual)
```

---

## ⚠️ Consideraciones Importantes

### 1. Orden de borrado
Siempre borrar en este orden:
1. **Primero**: `detalle_cuentas_corrientes` (tabla hija)
2. **Después**: `cuentas_corrientes` (tabla padre)

O usar `TRUNCATE ... CASCADE` que lo hace automáticamente.

### 2. Triggers
Los triggers están deshabilitados durante la migración para:
- Evitar validaciones que puedan fallar
- Mejorar performance
- Permitir inserción con IDs específicos

**IMPORTANTE**: Siempre reactivarlos al finalizar.

### 3. Secuencias
Después de insertar con IDs específicos, **SIEMPRE** actualizar la secuencia:
```sql
SELECT setval('cuentas_corrientes_idtransaccion_seq',
  (SELECT MAX(idtransaccion) FROM cuentas_corrientes),
  true);
```

Si no lo haces, el próximo INSERT autogenerado puede causar conflicto de clave primaria.

### 4. Transacciones
Todo está dentro de transacciones (`BEGIN`/`COMMIT`):
- Si algo falla, se revierte automáticamente
- Si quieres revertir manualmente: `ROLLBACK;`
- Si está todo OK: `COMMIT;`

### 5. Verificaciones
Los scripts incluyen verificaciones automáticas:
- ✓ Detalles huérfanos (detalles sin header)
- ✓ Headers sin detalles
- ✓ Importes que no cuadran (header vs suma de detalles)

---

## 🔍 Consultas Útiles

### Ver estado de la secuencia
```sql
SELECT last_value, is_called
FROM cuentas_corrientes_idtransaccion_seq;
```

### Ver próximo valor de la secuencia
```sql
SELECT nextval('cuentas_corrientes_idtransaccion_seq');
```

### Verificar integridad referencial
```sql
-- Buscar detalles huérfanos
SELECT COUNT(*)
FROM detalle_cuentas_corrientes d
WHERE NOT EXISTS (
  SELECT 1 FROM cuentas_corrientes c
  WHERE c.idtransaccion = d.idtransaccion
);
```

### Comparar importes
```sql
SELECT
  c.idtransaccion,
  c.importe as header_importe,
  SUM(d.importe) as detalles_suma,
  c.importe - SUM(d.importe) as diferencia
FROM cuentas_corrientes c
LEFT JOIN detalle_cuentas_corrientes d ON c.idtransaccion = d.idtransaccion
GROUP BY c.idtransaccion, c.importe
HAVING ABS(c.importe - SUM(d.importe)) > 0.01;
```

---

## 🆘 Solución de Problemas

### Error: "cannot insert ... violates foreign key constraint"
**Causa**: Intentas insertar detalles antes que headers, o con un idtransaccion que no existe.

**Solución**:
1. Insertar headers primero
2. Luego insertar detalles
3. Verificar que todos los idtransaccion en detalles existen en headers

### Error: "duplicate key value violates unique constraint"
**Causa**: Intentas insertar un ID que ya existe.

**Solución**:
1. Borrar datos existentes primero
2. O usar `ON CONFLICT DO NOTHING` en el INSERT
3. O usar `UPDATE` en lugar de `INSERT`

### Error: "cannot truncate a table referenced in a foreign key constraint"
**Causa**: No puedes hacer TRUNCATE sin CASCADE.

**Solución**: Usar `TRUNCATE TABLE cuentas_corrientes RESTART IDENTITY CASCADE;`

### La secuencia genera IDs duplicados
**Causa**: No actualizaste la secuencia después de insertar con IDs específicos.

**Solución**: Ejecutar:
```sql
SELECT setval('cuentas_corrientes_idtransaccion_seq',
  (SELECT MAX(idtransaccion) FROM cuentas_corrientes), true);
```

---

## ✅ Checklist Final

Después de la migración, verificar:

- [ ] Tablas tienen la cantidad correcta de registros
- [ ] No hay detalles huérfanos
- [ ] Todos los headers tienen al menos un detalle
- [ ] Los importes cuadran (header = suma de detalles)
- [ ] La secuencia está actualizada al último ID
- [ ] Los triggers están HABILITADOS
- [ ] Hacer un INSERT de prueba para verificar que la secuencia funciona
- [ ] Borrar tablas de backup si todo está OK

```sql
-- Test rápido
INSERT INTO cuentas_corrientes (socio_id, tipo_comprobante, numero_comprobante,
  documento_numero, fecha, importe, saldo)
VALUES (999, 'TEST', 9999, '999999', CURRENT_DATE, 0, 0)
RETURNING idtransaccion;
-- Debe devolver el siguiente ID después del máximo migrado

-- Si el test es exitoso, borrar el registro de prueba
DELETE FROM cuentas_corrientes WHERE tipo_comprobante = 'TEST';
```
