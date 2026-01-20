#!/bin/bash
# ============================================================================
# MIGRACION COMPLETA DE SQL SERVER A SUPABASE
# ============================================================================
# Este script ejecuta todos los pasos necesarios para migrar datos
# desde SQL Server a Supabase/PostgreSQL
# ============================================================================

set -e  # Salir si hay error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "============================================================================"
echo -e "${BLUE}MIGRACION COMPLETA - SAO 2026${NC}"
echo "============================================================================"
echo ""

# ============================================================================
# PASO 0: Verificar que estamos en el directorio correcto
# ============================================================================
if [ ! -f "migrate_socios_only.js" ]; then
    echo -e "${RED}ERROR: Este script debe ejecutarse desde la carpeta scripts/migration${NC}"
    echo "Directorio actual: $(pwd)"
    exit 1
fi

# ============================================================================
# PASO 1: PREPARACION - Limpiar tablas y preparar base de datos
# ============================================================================
echo ""
echo "============================================================================"
echo -e "${YELLOW}PASO 1: PREPARACION (AUTOMATICO)${NC}"
echo "============================================================================"
echo ""
echo "Limpiando tablas y preparando base de datos..."
echo ""

if ! node ejecutar_sql_preparacion.js; then
    echo ""
    echo -e "${RED}ERROR: Fallo la preparacion de la base de datos${NC}"
    exit 1
fi

# ============================================================================
# PASO 1b: RLS - Solo si es necesario
# ============================================================================
echo ""
echo -e "${YELLOW}NOTA: Si es la primera vez o tienes problemas de permisos,${NC}"
echo -e "${YELLOW}ejecuta en Supabase SQL Editor: database/migrations/deshabilitar_rls.sql${NC}"
echo ""
read -p "Presiona ENTER para continuar con la migracion..."

# ============================================================================
# PASO 2: MIGRACION DE DATOS - Scripts Node.js
# ============================================================================
echo ""
echo "============================================================================"
echo -e "${BLUE}PASO 2: MIGRACION DE DATOS (AUTOMATICO)${NC}"
echo "============================================================================"
echo ""
echo "Iniciando migracion automatica de datos..."
echo ""

# ----------------------------------------------------------------------------
# 2.1 - Migrar Socios
# ----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}[1/6] Migrando socios...${NC}"
echo "============================================================================"
if ! node migrate_socios_only.js; then
    echo ""
    echo -e "${RED}ERROR: Fallo la migracion de socios${NC}"
    exit 1
fi

# ----------------------------------------------------------------------------
# 2.2 - Migrar Conceptos y Observaciones
# ----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}[2/6] Migrando conceptos y observaciones...${NC}"
echo "============================================================================"
if ! node migrate_conceptos_observaciones.js; then
    echo ""
    echo -e "${RED}ERROR: Fallo la migracion de conceptos${NC}"
    exit 1
fi

# ----------------------------------------------------------------------------
# 2.3 - Migrar Cuentas Contables
# ----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}[3/6] Migrando cuentas contables...${NC}"
echo "============================================================================"
if ! node migrate_cuentas.js; then
    echo ""
    echo -e "${RED}ERROR: Fallo la migracion de cuentas${NC}"
    exit 1
fi

# ----------------------------------------------------------------------------
# 2.4 - Migrar Cuentas Corrientes
# ----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}[4/6] Migrando cuentas corrientes...${NC}"
echo "============================================================================"
if ! node migrate_cuentas_corrientes.js; then
    echo ""
    echo -e "${RED}ERROR: Fallo la migracion de cuentas corrientes${NC}"
    exit 1
fi

# ----------------------------------------------------------------------------
# 2.5 - Migrar Valores de Tesoreria
# ----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}[5/6] Migrando valores de tesoreria...${NC}"
echo "============================================================================"
if ! node migrate_valores_tesoreria.js; then
    echo ""
    echo -e "${RED}ERROR: Fallo la migracion de valores de tesoreria${NC}"
    exit 1
fi

# ----------------------------------------------------------------------------
# 2.6 - Migrar Asientos de Diario
# ----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}[6/6] Migrando asientos de diario...${NC}"
echo "============================================================================"
if ! node migrate_asientos_diario.js; then
    echo ""
    echo -e "${RED}ERROR: Fallo la migracion de asientos de diario${NC}"
    exit 1
fi

# ============================================================================
# PASO 3: POST-MIGRACION - Resetear secuencias
# ============================================================================
echo ""
echo "============================================================================"
echo -e "${YELLOW}PASO 3: POST-MIGRACION (AUTOMATICO)${NC}"
echo "============================================================================"
echo ""
echo "Reseteando secuencias..."

if ! node reset_sequences.js; then
    echo ""
    echo -e "${YELLOW}ADVERTENCIA: No se pudieron resetear las secuencias automaticamente${NC}"
    echo ""
    echo "Ejecuta manualmente en Supabase SQL Editor:"
    echo ""
    echo "  SELECT setval('valores_tesoreria_id_seq', COALESCE((SELECT MAX(id) FROM valores_tesoreria), 0) + 1, false);"
    echo "  SELECT setval('cuentas_corrientes_idtransaccion_seq', COALESCE((SELECT MAX(idtransaccion) FROM cuentas_corrientes), 0) + 1, false);"
    echo "  SELECT setval('detalle_cuentas_corrientes_id_seq', COALESCE((SELECT MAX(id) FROM detalle_cuentas_corrientes), 0) + 1, false);"
    echo ""
fi

# ============================================================================
# FINALIZACION
# ============================================================================
echo ""
echo "============================================================================"
echo -e "${GREEN}MIGRACION COMPLETADA EXITOSAMENTE${NC}"
echo "============================================================================"
echo ""
echo "Todas las tablas han sido migradas correctamente."
echo ""
echo "PROXIMO PASO:"
echo "  - Reinicia la aplicacion Flutter (hot restart)"
echo "  - Verifica que todo funcione correctamente"
echo ""
