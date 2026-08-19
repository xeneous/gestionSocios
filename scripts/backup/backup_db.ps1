# Backup diario de la base de Supabase (SAO 2026).
# Usa "supabase db dump" (pg_dump embebido en el CLI, corre en un contenedor Docker).
# Solo LEE datos de Supabase; no escribe ni modifica nada en el proyecto remoto.

$ErrorActionPreference = "Stop"

# Asegura que docker.exe encuentre sus credential helpers (docker-credential-desktop.exe, etc.)
# sin depender de que el proceso que lanzó este script tenga el PATH actualizado.
$env:PATH = "C:\Program Files\Docker\Docker\resources\bin;$env:PATH"

$envFile = Join-Path $PSScriptRoot ".env.local"
if (-not (Test-Path $envFile)) {
    throw "Falta $envFile. Copiá .env.local.example y completá SUPABASE_DB_URL."
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $key, $value = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim(), "Process")
}

if (-not $env:SUPABASE_DB_URL) {
    throw "SUPABASE_DB_URL no está definida en $envFile"
}

$backupRoot = "C:\Backups\SAO2026"
$dailyDir = Join-Path $backupRoot "daily"
$monthlyDir = Join-Path $backupRoot "monthly"
New-Item -ItemType Directory -Force -Path $dailyDir, $monthlyDir | Out-Null

$dockerCli = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
$supabaseCli = "C:\Users\Daniel\bin\supabase.exe"

function Wait-ForDocker {
    $dockerExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    $maxWaitSeconds = 120
    $elapsed = 0
    while ($true) {
        & $dockerCli info > $null 2>&1
        if ($LASTEXITCODE -eq 0) { return }
        if ($elapsed -eq 0 -and (Test-Path $dockerExe)) {
            Start-Process -FilePath $dockerExe | Out-Null
        }
        if ($elapsed -ge $maxWaitSeconds) {
            throw "Docker Desktop no respondió después de $maxWaitSeconds segundos."
        }
        Start-Sleep -Seconds 5
        $elapsed += 5
    }
}

Write-Host "Verificando que Docker esté disponible..."
Wait-ForDocker

$timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$schemaFile = Join-Path $dailyDir "sao2026_${timestamp}_schema.sql"
$dataFile = Join-Path $dailyDir "sao2026_${timestamp}_data.sql"
$dumpFile = Join-Path $dailyDir "sao2026_$timestamp.sql"

# "supabase db dump" sin --data-only trae SOLO el schema. Para un backup completo
# hacen falta los dos dumps (schema + data), concatenados en un solo archivo restaurable.
Write-Host "Generando dump de schema..."
& $supabaseCli db dump --db-url $env:SUPABASE_DB_URL -f $schemaFile
if ($LASTEXITCODE -ne 0) {
    throw "supabase db dump (schema) falló con código $LASTEXITCODE"
}

Write-Host "Generando dump de datos..."
& $supabaseCli db dump --db-url $env:SUPABASE_DB_URL --data-only --use-copy -f $dataFile
if ($LASTEXITCODE -ne 0) {
    throw "supabase db dump (data) falló con código $LASTEXITCODE"
}

Get-Content $schemaFile, $dataFile | Set-Content $dumpFile
Remove-Item $schemaFile, $dataFile
Write-Host "Backup generado correctamente: $dumpFile"

# Rotación: conserva los últimos 14 dumps diarios. Los más viejos se archivan
# como mensual (1 por mes) antes de borrarse, o se borran si ya hay uno de ese mes.
$cutoff = (Get-Date).AddDays(-14)
$oldDumps = Get-ChildItem -Path $dailyDir -Filter "sao2026_*.sql" | Where-Object { $_.CreationTime -lt $cutoff } | Sort-Object CreationTime

foreach ($dump in $oldDumps) {
    $monthKey = $dump.CreationTime.ToString("yyyy-MM")
    $monthlyTarget = Join-Path $monthlyDir "sao2026_$monthKey.sql"
    if (-not (Test-Path $monthlyTarget)) {
        Move-Item -Path $dump.FullName -Destination $monthlyTarget
        Write-Host "Archivado como mensual: $monthlyTarget"
    } else {
        Remove-Item -Path $dump.FullName
        Write-Host "Eliminado dump diario viejo: $($dump.Name)"
    }
}

Write-Host "Listo."
