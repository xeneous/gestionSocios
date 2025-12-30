# Re-migración Limpia con IDs Preservados

## Pasos a Seguir

### 1. Ejecutar Script de Limpieza en Supabase

Abre el **Supabase SQL Editor** y ejecuta el script [`reset_and_remigrate.sql`](file:///c:/Users/Daniel/StudioProjects/SAO%202026/scripts/migration/reset_and_remigrate.sql)

Esto eliminará los datos existentes y preparará las tablas.

### 2. Re-migrar Tablas de Referencia

```bash
cd scripts/migration
node migrate.js referencias
```

Esto migrará:
- ✅ Provincias
- ✅ Categorías IVA
- ✅ Grupos Agrupados
- ✅ **Tarjetas (con IDs originales preservados)**

### 3. Re-migrar Socios

```bash
node migrate.js socios
```

Esto migrará los 4,380 socios con los `tarjeta_id` correctos matching MS SQL Server.

### 4. Resetear Secuencia de IDs

```bash
# Ejecutar en Supabase SQL Editor (si es necesario)
SELECT setval(pg_get_serial_sequence('socios', 'id'), 
    (SELECT MAX(id) FROM socios), true);

SELECT setval(pg_get_serial_sequence('tarjetas', 'id'), 
    (SELECT MAX(id) FROM tarjetas), true);
```

## Cambios Realizados en migrate.js

- **Línea 303**: Agregado `id: t.IdTarjeta` para preservar el ID original
- **Línea 157**: Ya corregido para usar `row.Tarjeta` en lugar de hardcoded `0`

## Verificación Post-Migración

Verificar en Supabase que:
1. Las tarjetas tienen los mismos IDs que en MS SQL Server
2. Los socios tienen los `tarjeta_id` correctos
3. El socio 3321 muestra VISA (ID 1)
