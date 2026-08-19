# Backups automáticos y entorno de prueba local

## Resumen

- **Backups**: todos los días a las 03:00 una tarea programada de Windows
  (`SAO2026_BackupSupabase`) vuelca el schema + los datos de la base de
  Supabase a `C:\Backups\SAO2026\daily\`. Se conservan los últimos 14 días;
  los más viejos se archivan como 1 dump por mes en `C:\Backups\SAO2026\monthly\`.
- **Entorno de prueba**: Supabase corriendo localmente con Docker
  (`supabase start`), con una copia de los datos reales, para probar la app
  sin tocar producción. Perfiles de VS Code: **"SAO - Desarrollo (local)"**
  y **"SAO - Web Desarrollo (local)"**.

Todo lo que toca el proyecto remoto es **solo lectura** (`supabase db dump`).
Nunca se ejecuta `db push` ni nada que escriba en producción.

## Requisitos ya instalados en este equipo

- Docker Desktop (con WSL2).
- Supabase CLI en `C:\Users\Daniel\bin\supabase.exe` (en el PATH del usuario).
- `scripts\backup\.env.local` con la cadena de conexión (no se versiona en git).
  Usa el **Session pooler** de Supabase, no la conexión directa, porque el
  host directo (`db.<ref>.supabase.co`) solo resuelve por IPv6 y los
  contenedores de Docker Desktop en Windows no tienen salida IPv6.

## Backups

### Correr un backup manualmente
```powershell
powershell -ExecutionPolicy Bypass -File "scripts\backup\backup_db.ps1"
```
Genera `C:\Backups\SAO2026\daily\sao2026_<fecha>.sql` (schema + datos en un
solo archivo, formato SQL plano).

### Ver/modificar la tarea programada
```powershell
schtasks /Query /TN "SAO2026_BackupSupabase" /V /FO LIST
schtasks /Change /TN "SAO2026_BackupSupabase" /ST 04:00   # cambiar horario
```

### Restaurar un backup a mano (a cualquier Postgres)
```powershell
psql "<connection-string-destino>" -f "C:\Backups\SAO2026\daily\sao2026_<fecha>.sql"
```

## Entorno de prueba local

### Levantar el stack
```powershell
cd "C:\Users\Daniel\StudioProjects\SAO 2026"
supabase start
```
Esto levanta Postgres, Auth, Storage, Studio, etc. en contenedores Docker.
La primera vez tarda varios minutos (descarga las imágenes).

- Studio (panel admin local): http://127.0.0.1:54323
- API: http://127.0.0.1:54321
- Postgres directo: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`

### Cargar/refrescar datos reales
```powershell
powershell -ExecutionPolicy Bypass -File "scripts\backup\restore_local.ps1"
```
Toma el backup más reciente de `C:\Backups\SAO2026\daily\` y lo restaura en
el Postgres local. Podés correrlo cada vez que quieras refrescar el entorno
de prueba con datos más actuales.

### Correr la app contra el entorno local
En VS Code, elegir el perfil **"SAO - Desarrollo (local)"** (o la versión Web)
al iniciar debug — ya están configurados en `.vscode/launch.json` con la URL
y anon key del stack local. Podés loguearte con los mismos usuarios reales
(la tabla `auth.users` también se restaura).

### Apagar el stack
```powershell
supabase stop
```
(`supabase stop --no-backup` si además querés borrar los datos locales).

## Troubleshooting

- **"Docker Desktop no respondió"**: abrí Docker Desktop manualmente y
  esperá a que el ícono de la ballena quede estable antes de reintentar.
- **Contenedores que no inician / quedan en estado "Created" sin arrancar**:
  reiniciar el backend con `wsl --shutdown` y volver a abrir Docker Desktop
  suele resolverlo (pasó una vez durante la instalación inicial).
- **`pg_dump: error: could not translate host name ...supabase.co`**: la
  cadena de conexión en `.env.local` está usando el host directo en vez del
  pooler. Revisar `scripts\backup\.env.local.example` para el formato correcto.
- **El backup falla con "SSL connection has been closed unexpectedly"** en
  medio de una tabla grande: suele ser un corte transitorio de red contra el
  pooler. Reintentar (`backup_db.ps1` de nuevo) normalmente alcanza.
