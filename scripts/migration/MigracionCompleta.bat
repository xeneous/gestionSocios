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
REM PASO 1: SCRIPTS SQL - Ejecutar manualmente en Supabase SQL Editor
REM ============================================================================
echo.
echo ============================================================================
echo PASO 1: SCRIPTS SQL (EJECUTAR MANUALMENTE EN SUPABASE)
echo ============================================================================
echo.
echo Por favor, ejecuta los siguientes scripts en Supabase SQL Editor:
echo.
echo   1. database/migrations/limpiar_para_remigracion.sql
echo      ^(Limpia todas las tablas transaccionales^)
echo.
echo   2. database/migrations/limpiar_espacios_tipos_comprobante.sql
echo      ^(Elimina espacios de tipos de comprobante^)
echo.
echo   3. database/migrations/deshabilitar_rls.sql
echo      ^(Deshabilita Row Level Security^)
echo.
echo IMPORTANTE: Ejecuta estos scripts EN ORDEN antes de continuar.
echo.
pause

REM ============================================================================
REM PASO 2: MIGRACION DE DATOS - Scripts Node.js
REM ============================================================================
echo.
echo ============================================================================
echo PASO 2: MIGRACION DE DATOS (AUTOMATICO)
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
