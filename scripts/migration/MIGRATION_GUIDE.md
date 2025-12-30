# Guía de Migración Completa

## ⚠️ IMPORTANTE
Este script **BORRARÁ TODOS los datos** en Supabase y los recargará desde SQL Server.

## Requisitos Previos

1. **SQL Server debe estar accesible**
   - Servidor ejecutándose
   - Puerto accesible
   - Credenciales correctas

2. **Archivo `.env` configurado** en `/scripts/migration/`
   ```env
   SQLSERVER_SERVER=tu_servidor
   SQLSERVER_PORT=1433
   SQLSERVER_USER=tu_usuario
   SQLSERVER_PASSWORD=tu_password
   SQLSERVER_DATABASE=SAO

   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key
   ```

3. **Dependencies instaladas**
   ```bash
   cd scripts/migration
   npm install
   ```

## Ejecutar Migración

```bash
cd scripts/migration
node migrate_complete.js
```

## Qué Esperar

El script ejecutará los siguientes pasos EN ORDEN:

1. **🧹 Limpieza de Supabase** (30 seg)
   - Borra todos los datos de todas las tablas
   
2. **📋 Migración de Sexos** (5 seg)
   - Inserta 3 registros fijos (0, 1, 2)

3. **📋 Migración de Provincias** (10 seg)
   - ~27 provincias argentinas

4. **📋 Migración de Países** (30 seg)
   - ~256 países

5. **📋 Migración de Grupos** (10 seg)
   - Grupos agrupados activos/inactivos

6. **📋 Migración de Categorías IVA** (5 seg)
   - Categorías de facturación

7. **📋 Migración de Tarjetas** (5 seg)
   - Tarjetas de débito automático (preservando IDs)

8. **📋 Migración de Socios** (2-5 min)
   - Todos los socios con campos mapeados correctamente
   - Se migra en lotes de 100

**Tiempo total estimado: 3-6 minutos**

## Verificar Migración

### En Supabase SQL Editor

```sql
-- Verificar conteos
SELECT 'sexos' as tabla, COUNT(*) FROM sexos
UNION ALL
SELECT 'provincias', COUNT(*) FROM provincias
UNION ALL
SELECT 'paises', COUNT(*) FROM paises
UNION ALL
SELECT 'grupos_agrupados', COUNT(*) FROM grupos_agrupados
UNION ALL
SELECT 'tarjetas', COUNT(*) FROM tarjetas
UNION ALL
SELECT 'socios', COUNT(*) FROM socios;
```

Resultados esperados:
- sexos: 3
- provincias: ~27
- paises: ~256
- grupos_agrupados: ~10-15
- tarjetas: ~5-10
- socios: (tu cantidad total)

### Verificar Datos

```sql
-- Ver provincias
SELECT * FROM provincias LIMIT 5;

-- Ver países  
SELECT * FROM paises LIMIT 5;

-- Ver socios con referencias
SELECT id, apellido, nombre, provincia_id, pais_id, sexo, tarjeta_id
FROM socios
LIMIT 10;
```

### En Flutter App

1. Hot restart (`R`)
2. Ir a "Socios" → Buscar → Editar un socio
3. Verificar que todos los dropdowns cargan:
   - ✅ Sexo (mostrando Masculino/Femenino/No informado)
   - ✅ Grupo (mostrando códigos y descripciones)
   - ✅ Provincia (mostrando nombres de provincias)
   - ✅ País (mostrando nombres de países)
4. Verificar que datos del socio se ven correctos
5. Hacer un cambio y guardar
6. Verificar que se guarda correctamente

## Problemas Comunes

### "Cannot connect to SQL Server"
- Verificar que SQL Server está corriendo
- Verificar IP/puerto en `.env`
- Verificar firewall permite conexión

### "Unauthorized" en Supabase
- Verificar `SUPABASE_SERVICE_ROLE_KEY` en `.env`
- Usar la SERVICE ROLE key, NO la anon key

### "Column does not exist"
- Ejecutar `database/add_missing_columns_socios.sql` en Supabase primero
- Asegurarse que todas las tablas existen

### Tiempo de ejecución muy largo
- Normal si tienes miles de socios
- El script migra en lotes de 100
- No interrumpir el proceso

## Repetir Migración

Este script es **idempotente** - puedes ejecutarlo múltiples veces:

```bash
# Ejecutar nuevamente limpiará y recargará todo
node migrate_complete.js
```

Úsalo antes de pasar a producción para asegurar datos frescos.

## Soporte

Si encuentras errores:
1. Revisa los mensajes en consola (empiezan con ❌ o 💥)
2. Verifica que el archivo `.env` tenga credenciales correctas
3. Asegúrate que todas las tablas existen en Supabase 
