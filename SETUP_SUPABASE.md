# Configuración de Supabase para SAO 2026

## Paso 1: Crear Proyecto Supabase

1. Ve a https://supabase.com y crea una cuenta (si no tienes)
2. Click en "New Project"
3. Completa:
   - **Name**: SAO-2026
   - **Database Password**: (guarda esta contraseña en un lugar seguro)
   - **Region**: South America (São Paulo) - la más cercana a Argentina
   - **Pricing Plan**: Free (suficiente para empezar)
4. Click "Create new project" y espera 2-3 minutos

## Paso 2: Ejecutar Schema de Base de Datos

1. Una vez creado el proyecto, ve a **SQL Editor** (ícono de base de datos en el menú lateral)
2. Click en "New query"
3. Abre el archivo `database/schema_postgresql.sql` de este proyecto
4. Copia TODO el contenido y pégalo en el editor SQL
5. Click en "Run" (esquina inferior derecha)
6. Verifica que salga "Success. No rows returned" o similar
7. Ve a **Table Editor** para ver las 31 tablas creadas

## Paso 3: Obtener Credenciales

1. Ve a **Settings** (engranaje en el menú lateral)
2. Click en **API**
3. Encontrarás:
   - **Project URL**: algo como `https://xxxxx.supabase.co`
   - **anon/public key**: una clave larga que empieza con `eyJ...`
4. COPIA estos valores

## Paso 4: Configurar el Proyecto Flutter

1. Abre `lib/main.dart`
2. Busca las líneas:
   ```dart
   url: 'YOUR_SUPABASE_URL',
   anonKey: 'YOUR_SUPABASE_ANON_KEY',
   ```
3. Reemplaza con tus valores:
   ```dart
   url: 'https://xxxxx.supabase.co',  // Tu Project URL
   anonKey: 'eyJ...',                  // Tu anon key
   ```

## Paso 5: Crear Primer Usuario

1. En Supabase, ve a **Authentication** > **Users**
2. Click en "Add user" > "Create new user"
3. Completa:
   - **Email**: tu@email.com
   - **Password**: (mínimo 6 caracteres)
   - **Auto Confirm User**: ✅ (marcar esto)
4. Click "Create user"
 
## Paso 6: Probar la Aplicación

```bash
cd "C:\Users\Daniel\StudioProjects\SAO 2026"
flutter run -d chrome
```

Usa el email y contraseña que creaste para hacer login.

## Solución de Problemas

### Error: "Invalid API key"
- Verifica que copiaste correctamente el Project URL y anon key
- Asegúrate de no haber agregado espacios al inicio o final

### Error: "Invalid login credentials"
- Verifica que marcaste "Auto Confirm User" al crear el usuario
- Si no lo hiciste, ve a Authentication > Users > Click en el usuario > Click "Confirm user"

### No aparecen las tablas
- Ejecuta nuevamente el script SQL completo
- Verifica que no haya errores en la consola SQL

## Próximos Pasos

Una vez que puedas hacer login, comenzaremos con:
1. Módulo de Plan de Cuentas
2. Módulo de Asientos Contables
3. Dashboard con estadísticas

¡Todo listo para comenzar el desarrollo! 🚀
