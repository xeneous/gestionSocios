# Refresca los datos del Supabase LOCAL (Docker) con el backup más reciente.
# Requiere que "supabase start" ya esté corriendo (ver docs/BACKUPS_Y_ENTORNO_LOCAL.md).
# Solo escribe en el Postgres local (127.0.0.1:54322) - nunca toca el proyecto remoto.

$ErrorActionPreference = "Stop"
$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;$env:PATH"

$dailyDir = "C:\Backups\SAO2026\daily"
$latest = Get-ChildItem -Path $dailyDir -Filter "sao2026_*.sql" | Sort-Object CreationTime -Descending | Select-Object -First 1

if (-not $latest) {
    throw "No hay backups en $dailyDir. Corré backup_db.ps1 primero."
}

$dbContainer = (docker ps --format "{{.Names}}" | Select-String "supabase_db_").ToString()
if (-not $dbContainer) {
    throw "No encuentro el contenedor de Postgres local. ¿Corriste 'supabase start'?"
}

Write-Host "Restaurando $($latest.Name) en el contenedor $dbContainer ..."
Get-Content $latest.FullName -Raw | docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=0 | Out-Null
Write-Host "Listo. Datos locales actualizados desde $($latest.Name)."
