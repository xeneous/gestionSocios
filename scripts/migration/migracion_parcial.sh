#!/bin/bash
# ============================================================================
# MIGRACIÓN PARCIAL - SAO 2026
# Proveedores, Clientes, Comprobantes Compras/Ventas,
# Valores Tesorería asociados, Asientos de Diario
#
# IMPORTANTE: Este script SOLO carga datos en tablas _new.
# NO modifica, trunca ni toca tablas productivas.
#
# PREREQUISITO: Ejecutar primero en Supabase SQL Editor:
#   - FASE 0 (crear _bak_0703)
#   - FASE 1 (crear tablas _new vacías)
#   del archivo: sql/migracion_parcial_proveedores.sql
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "============================================================================"
echo -e "${BLUE}MIGRACIÓN PARCIAL - SAO 2026${NC}"
echo -e "${YELLOW}Destino: tablas _new (NO toca producción)${NC}"
echo "============================================================================"
echo ""

# Verificar directorio
if [ ! -f "migrate_clipro_parcial.js" ]; then
    echo -e "${RED}ERROR: Ejecutar desde la carpeta scripts/migration${NC}"
    echo "Directorio actual: $(pwd)"
    exit 1
fi

echo -e "${YELLOW}PREREQUISITO: ¿Ya ejecutaste FASE 0 y FASE 1 en Supabase SQL Editor?${NC}"
echo "  (migracion_parcial_proveedores.sql — Fase 0: _bak_0703, Fase 1: _new vacías)"
echo ""
read -p "Presiona ENTER para continuar o Ctrl+C para cancelar..."

# ── PASO 1: Clientes, Proveedores, Comprobantes ────────────────────────────────
echo ""
echo "============================================================================"
echo -e "${GREEN}[1/3] Migrando Clientes, Proveedores y Comprobantes → _new${NC}"
echo "============================================================================"
if ! node migrate_clipro_parcial.js; then
    echo -e "${RED}ERROR: Falló migrate_clipro_parcial.js${NC}"
    exit 1
fi

# ── PASO 2: Valores Tesorería ──────────────────────────────────────────────────
echo ""
echo "============================================================================"
echo -e "${GREEN}[2/3] Migrando Valores Tesorería → valores_tesoreria_new${NC}"
echo "      (solo los vinculados a comp_prov_new y ven_cli_new)${NC}"
echo "============================================================================"
if ! node migrate_valores_tesoreria_parcial.js; then
    echo -e "${RED}ERROR: Falló migrate_valores_tesoreria_parcial.js${NC}"
    exit 1
fi

# ── PASO 3: Asientos de Diario ─────────────────────────────────────────────────
echo ""
echo "============================================================================"
echo -e "${GREEN}[3/3] Migrando Asientos de Diario → asientos_header/items_new${NC}"
echo "============================================================================"
if ! node migrate_asientos_parcial.js; then
    echo -e "${RED}ERROR: Falló migrate_asientos_parcial.js${NC}"
    exit 1
fi

# ── FINALIZACIÓN ───────────────────────────────────────────────────────────────
echo ""
echo "============================================================================"
echo -e "${GREEN}✅ MIGRACIÓN PARCIAL COMPLETADA${NC}"
echo "============================================================================"
echo ""
echo "PRÓXIMO PASO:"
echo "  Verificar en Supabase que las tablas _new tienen datos:"
echo "  → Ejecutar FASE 2 (validaciones) del archivo:"
echo "    sql/migracion_parcial_proveedores.sql"
echo ""
echo "  Cuando Fase 2 dé 0 errores, se puede proceder con FASE 3 (swap)."
echo "  FASE 3 está comentada en el SQL y requiere autorización explícita."
echo ""
