# Migración CLIPRO (Clientes/Proveedores)

## Descripción
Scripts para crear las tablas de Clientes/Proveedores (CLIPRO) en Supabase y migrar datos desde SQL Server.

## Tablas incluidas
- **categorias_iva**: Categorías de IVA para facturación (versión completa)
- **clientes**: Maestro de clientes/sponsors
- **contactos_clientes**: Contactos de clientes
- **proveedores**: Maestro de proveedores
- **contactos_proveedores**: Contactos de proveedores
- **tip_vent_mod_header/items**: Tipos de comprobante de ventas
- **tip_comp_mod_header/items**: Tipos de comprobante de compras
- **ven_cli_header/items**: Cuenta corriente de clientes
- **comp_prov_header/items**: Cuenta corriente de proveedores

## Archivos

| Archivo | Descripción |
|---------|-------------|
| `001_create_clipro_tables.sql` | Script SQL para crear las tablas en Supabase |
| `../migrate_clipro.js` | Script Node.js para migrar datos de SQL Server |
| `Sponsors Proveedores.sql` | Estructura original de SQL Server (referencia) |

## Proceso de Migración

### Paso 1: Crear tablas en Supabase
Ejecutar en Supabase SQL Editor:
```sql
-- Copiar contenido de 001_create_clipro_tables.sql
```

### Paso 2: Ejecutar migración de datos
Desde la carpeta `scripts/migration`:
```bash
node migrate_clipro.js
```

### Opciones de migración
```bash
# Migración completa (todos los datos)
node migrate_clipro.js

# Solo maestros (sin cuentas corrientes)
node migrate_clipro.js --skip-ctacte
```

## Orden de migración interna
El script migra en el siguiente orden (respetando foreign keys):

1. Categorías IVA
2. Clientes (sponsors)
3. Contactos de clientes
4. Proveedores
5. Contactos de proveedores
6. Tipos de comprobante de ventas (header + items)
7. Tipos de comprobante de compras (header + items)
8. Cuenta corriente clientes (header + items)
9. Cuenta corriente proveedores (header + items)
10. Reset de secuencias

## Integración con migración completa
Este módulo se ejecuta de forma independiente después de la migración principal:

```bash
# 1. Migración principal (socios, cuentas, etc.)
node migrate_complete.js

# 2. Migración CLIPRO
node migrate_clipro.js
```

## Notas
- Las tablas usan snake_case según convención de Supabase
- Se incluyen índices para optimizar consultas frecuentes
- RLS está habilitado con acceso completo para usuarios autenticados
- Los IDs originales de SQL Server se preservan
