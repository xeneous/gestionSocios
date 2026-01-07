-- Script de verificación para debugging
-- Ejecutar en Supabase SQL Editor

-- ============================================================================
-- 1. Verificar que las funciones existen
-- ============================================================================

SELECT 
    routine_name,
    routine_type,
    data_type as return_type,
    type_udt_name
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('buscar_socios_con_deuda', 'obtener_resumen_cuentas_corrientes')
ORDER BY routine_name;

-- ============================================================================
-- 2. Ver los parámetros de obtener_resumen_cuentas_corrientes
-- ============================================================================

SELECT 
    p.parameter_name,
    p.data_type,
    p.parameter_default
FROM information_schema.parameters p
WHERE p.specific_schema = 'public'
  AND p.specific_name IN (
      SELECT specific_name 
      FROM information_schema.routines 
      WHERE routine_name = 'obtener_resumen_cuentas_corrientes'
  )
ORDER BY p.ordinal_position;

-- ============================================================================
-- 3. Probar la función obtener_resumen_cuentas_corrientes
-- ============================================================================

-- Test simple: obtener primeros 5 registros
SELECT * FROM obtener_resumen_cuentas_corrientes(
    p_limit := 5,
    p_offset := 0
);

-- ============================================================================
-- 4. Contar socios por grupo
-- ============================================================================

-- Ver qué grupos existen y cuántos socios hay en cada uno
SELECT 
    grupo,
    COUNT(*) as cantidad,
    COUNT(*) FILTER (WHERE activo = TRUE) as activos
FROM socios
GROUP BY grupo
ORDER BY grupo;

-- ============================================================================
-- 5. Verificar que solo se devuelven grupos A, T, H, V
-- ============================================================================

-- Esta consulta debería devolver solo los grupos A, T, H, V
SELECT DISTINCT grupo
FROM obtener_resumen_cuentas_corrientes(p_limit := NULL, p_offset := 0)
ORDER BY grupo;
