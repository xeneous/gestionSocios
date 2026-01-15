-- ============================================================================
-- LIMPIAR ESPACIOS FINALES EN TIPOS DE COMPROBANTE
-- ============================================================================
-- Este script debe ejecutarse ANTES de cada migración de cuentas_corrientes
-- para asegurar que todos los tipos de comprobante no tengan espacios finales
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
  RAISE NOTICE 'LIMPIANDO ESPACIOS FINALES EN TIPOS DE COMPROBANTE';
  RAISE NOTICE '============================================================';
  RAISE NOTICE '';

  -- ============================================================================
  -- PASO 1: Insertar tipos SIN espacios en tipos_comprobante_socios
  -- ============================================================================
  RAISE NOTICE '1️⃣  Creando tipos de comprobante sin espacios...';

  INSERT INTO tipos_comprobante_socios (comprobante, descripcion, id_tipo_movimiento, signo)
  SELECT
    TRIM(comprobante) as comprobante,
    descripcion,
    id_tipo_movimiento,
    signo
  FROM tipos_comprobante_socios
  WHERE comprobante != TRIM(comprobante)
    AND TRIM(comprobante) NOT IN (SELECT comprobante FROM tipos_comprobante_socios)
  ON CONFLICT (comprobante) DO NOTHING;

  RAISE NOTICE '   ✅ Tipos sin espacios creados';

  -- ============================================================================
  -- PASO 2: Actualizar cuentas_corrientes para usar tipos sin espacios
  -- ============================================================================
  RAISE NOTICE '2️⃣  Actualizando cuentas_corrientes...';

  UPDATE cuentas_corrientes
  SET tipo_comprobante = TRIM(tipo_comprobante)
  WHERE tipo_comprobante != TRIM(tipo_comprobante);

  RAISE NOTICE '   ✅ Cuentas corrientes actualizadas';

  -- ============================================================================
  -- PASO 3: Eliminar tipos CON espacios (ya no están referenciados)
  -- ============================================================================
  RAISE NOTICE '3️⃣  Eliminando tipos con espacios...';

  DELETE FROM tipos_comprobante_socios
  WHERE comprobante != TRIM(comprobante);

  RAISE NOTICE '   ✅ Tipos con espacios eliminados';

  -- ============================================================================
  -- VERIFICACIÓN FINAL
  -- ============================================================================
  RAISE NOTICE '';
  RAISE NOTICE '============================================================';
  RAISE NOTICE 'VERIFICACIÓN FINAL';
  RAISE NOTICE '============================================================';

END $$;

-- Mostrar tipos de comprobante final
SELECT
  comprobante,
  LENGTH(comprobante) as longitud,
  descripcion,
  id_tipo_movimiento,
  signo
FROM tipos_comprobante_socios
ORDER BY comprobante;

-- Mostrar tipos únicos en cuentas_corrientes
SELECT
  tipo_comprobante,
  LENGTH(tipo_comprobante) as longitud,
  COUNT(*) as cantidad
FROM cuentas_corrientes
GROUP BY tipo_comprobante, LENGTH(tipo_comprobante)
ORDER BY tipo_comprobante;

-- ============================================================================
-- FIN
-- ============================================================================
