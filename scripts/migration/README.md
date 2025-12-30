# Migración de Datos: SQL Server → Supabase

Script Node.js para migrar datos de la base SQL Server de producción a Supabase.

## Instalación

```bash
cd scripts/migration
npm install
```

## Configuración

1. Copiar `.env.example` a `.env`:
```bash
cp .env.example .env
```

2. Editar `.env` y agregar las credenciales de Supabase:
```env
SUPABASE_URL=tu_url_de_supabase
SUPABASE_SERVICE_KEY=tu_service_key
```

## Uso

**Migrar solo tablas de referencia:**
```bash
npm run migrate referencias
```

**Migrar solo socios:**
```bash
npm run migrate socios
```

**Migrar todo:**
```bash
npm run migrate all
```

## Orden Recomendado

1. **Referencias** - Tablas pequeñas (provincias, categorías IVA, grupos)
2. **Socios** - Tabla principal

## Mapeo de Columnas

### Tabla: socios

| SQL Server (viejo) | PostgreSQL (nuevo) | Notas |
|---|---|---|
| socio | *(no se migra)* | ID se autogenera |
| Apellido | apellido | |
| nombre | nombre | |
| tipodocto | tipo_documento | Mapeo: 1=DNI, 2=LC, 3=LE, 4=PAS |
| numedocto | numero_documento | |
| Grupo | grupo | |
| Domicilio | domicilio | |
| localidad | localidad | |
| provincia | provincia_id | |
| cpostal | codigo_postal | |
| telefono | telefono | |
| Fax | telefono_secundario | |
| Email | email | |
| EmailAlt1 | email_alternativo | |
| cuil | cuil | |
| FechaBaja | fecha_baja | |
| FechaIngreso | fecha_ingreso | |
| Residente | residente | Convierte 'S'/1 → true |
| Matricula | matricula_provincial | |
| nroMatricula | matricula_nacional | |
| fechanac | fecha_nacimiento | |

## Características

- ✅ Migración en lotes de 100 registros
- ✅ Manejo de errores detallado
- ✅ Logs de progreso
- ✅ Mapeo automático de tipos
- ✅ Limpieza de espacios (.trim())
- ✅ Conversión de booleanos

## Notas

- El script usa el service key de Supabase para poder insertar datos
- Los registros se migran en lotes para mejor performance
- Se registran errores pero continúa con el siguiente lote
