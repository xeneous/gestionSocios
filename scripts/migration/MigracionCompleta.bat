@echo off
REM ============================================================================
REM MIGRACION COMPLETA DE SQL SERVER A SUPABASE
REM ============================================================================
REM Este script ejecuta todos los pasos necesarios para migrar datos
REM desde SQL Server a Supabase/PostgreSQL
REM ============================================================================

echo.
echo ============================================================================
echo MIGRACION COMPLETA - SAO 2026
echo ============================================================================
echo.

REM ============================================================================
REM PASO 0: Verificar que estamos en el directorio correcto
REM ============================================================================
if not exist "migrate_socios_only.js" (
    echo ERROR: Este script debe ejecutarse desde la carpeta scripts/migration
    echo Directorio actual: %CD%
    pause
    exit /b 1
)

REM ============================================================================
REM PASO 1: PREPARACION - Limpiar tablas y preparar base de datos
REM ============================================================================
echo.
echo ============================================================================
echo PASO 1: PREPARACION ^(AUTOMATICO^)
echo ============================================================================
echo.
echo Limpiando tablas y preparando base de datos...
echo.

node ejecutar_sql_preparacion.js
if errorlevel 1 (
    echo.
    echo ERROR: Fallo la preparacion de la base de datos
    pause
    exit /b 1
)

REM ============================================================================
REM PASO 1b: RLS - Solo si es necesario
REM ============================================================================
echo.
echo NOTA: Si es la primera vez o tienes problemas de permisos,
echo ejecuta en Supabase SQL Editor: database/migrations/deshabilitar_rls.sql
echo.
pause

REM ============================================================================
REM PASO 2: MIGRACION DE DATOS - Scripts Node.js
REM ============================================================================
echo.
echo ============================================================================
echo PASO 2: MIGRACION DE DATOS ^(AUTOMATICO^)
echo ============================================================================
echo.
echo Iniciando migracion automatica de datos...
echo.

REM ----------------------------------------------------------------------------
REM 2.1 - Migrar Socios
REM ----------------------------------------------------------------------------
echo.
echo [1/6] Migrando socios...
echo ============================================================================
node migrate_socios_only.js
if errorlevel 1 (
    echo.
    echo ERROR: Fallo la migracion de socios
    pause
    exit /b 1
)

REM ----------------------------------------------------------------------------
REM 2.2 - Migrar Conceptos y Observaciones
REM ----------------------------------------------------------------------------
echo.
echo [2/6] Migrando conceptos y observaciones...
echo ============================================================================
node migrate_conceptos_observaciones.js
if errorlevel 1 (
    echo.
    echo ERROR: Fallo la migracion de conceptos
    pause
    exit /b 1
)

REM ----------------------------------------------------------------------------
REM 2.3 - Migrar Cuentas Contables
REM ----------------------------------------------------------------------------
echo.
echo [3/6] Migrando cuentas contables...
echo ============================================================================
node migrate_cuentas.js
if errorlevel 1 (
    echo.
    echo ERROR: Fallo la migracion de cuentas
    pause
    exit /b 1
)

REM ----------------------------------------------------------------------------
REM 2.4 - Migrar Cuentas Corrientes
REM ----------------------------------------------------------------------------
echo.
echo [4/6] Migrando cuentas corrientes...
echo ============================================================================
node migrate_cuentas_corrientes.js
if errorlevel 1 (
    echo.
    echo ERROR: Fallo la migracion de cuentas corrientes
    pause
    exit /b 1
)

REM ----------------------------------------------------------------------------
REM 2.5 - Migrar Valores de Tesoreria
REM ----------------------------------------------------------------------------
echo.
echo [5/6] Migrando valores de tesoreria...
echo ============================================================================
node migrate_valores_tesoreria.js
if errorlevel 1 (
    echo.
    echo ERROR: Fallo la migracion de valores de tesoreria
    pause
    exit /b 1
)

REM ----------------------------------------------------------------------------
REM 2.6 - Migrar Asientos de Diario
REM ----------------------------------------------------------------------------
echo.
echo [6/6] Migrando asientos de diario...
echo ============================================================================
node migrate_asientos_diario.js
if errorlevel 1 (
    echo.
    echo ERROR: Fallo la migracion de asientos de diario
    pause
    exit /b 1
)

REM ============================================================================
REM PASO 3: POST-MIGRACION - Resetear secuencias
REM ============================================================================
echo.
echo ============================================================================
echo PASO 3: POST-MIGRACION ^(AUTOMATICO^)
echo ============================================================================
echo.
echo Reseteando secuencias...

node reset_sequences.js
if errorlevel 1 (
    echo.
    echo ADVERTENCIA: No se pudieron resetear las secuencias automaticamente
    echo.
    echo Ejecuta manualmente en Supabase SQL Editor:
    echo.
    echo   SELECT setval('valores_tesoreria_id_seq', COALESCE((SELECT MAX(id) FROM valores_tesoreria), 0) + 1, false);
    echo   SELECT setval('cuentas_corrientes_idtransaccion_seq', COALESCE((SELECT MAX(idtransaccion) FROM cuentas_corrientes), 0) + 1, false);
    echo   SELECT setval('detalle_cuentas_corrientes_id_seq', COALESCE((SELECT MAX(id) FROM detalle_cuentas_corrientes), 0) + 1, false);
    echo.
)

REM ============================================================================
REM FINALIZACION
REM ============================================================================
echo.
echo ============================================================================
echo MIGRACION COMPLETADA EXITOSAMENTE
echo ============================================================================
echo.
echo Todas las tablas han sido migradas correctamente.
echo.
echo PROXIMO PASO:
echo   - Reinicia la aplicacion Flutter (hot restart)
echo   - Verifica que todo funcione correctamente
echo.
pause
