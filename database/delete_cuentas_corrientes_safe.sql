-- ============================================================================
-- BORRADO SEGURO DE CUENTAS CORRIENTES CON FOREIGN KEYS
-- ============================================================================
-- Este script permite borrar datos de cuentas_corrientes manejando
-- correctamente las foreign keys y constraints
-- ============================================================================

BEGIN;

-- Paso 1: Mostrar estadísticas antes del borrado
SELECT
  'ANTES DEL BORRADO' as momento,
  (SELECT COUNT(*) FROM cuentas_corrientes) as total_headers,
  (SELECT COUNT(*) FROM detalle_cuentas_corrientes) as total_detalles,
  (SELECT COALESCE(MAX(idtransaccion), 0) FROM cuentas_corrientes) as max_idtransaccion;


-- ============================================================================
-- OPCIÓN 1: BORRAR REGISTROS ESPECÍFICOS (por condición)
-- ============================================================================

-- Ejemplo: Borrar todas las cuotas sociales de enero 2026
/*
-- Primero borrar los detalles
DELETE FROM detalle_cuentas_corrientes
WHERE idtransaccion IN (
  SELECT idtransaccion
  FROM cuentas_corrientes
  WHERE tipo_comprobante = 'CS '
    AND documento_numero = '202601'
);

-- Luego borrar los headers
DELETE FROM cuentas_corrientes
WHERE tipo_comprobante = 'CS '
  AND documento_numero = '202601';
*/


-- ============================================================================
-- OPCIÓN 2: BORRAR TODO Y REINICIAR SECUENCIAS (TABLA VACÍA)
-- ============================================================================

-- ADVERTENCIA: Esto borra TODOS los datos
-- Descomenta solo si necesitas empezar desde cero

-- Deshabilitar triggers temporalmente
ALTER TABLE cuentas_corrientes DISABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes DISABLE TRIGGER ALL;

-- Borrar todo con CASCADE (elimina detalles automáticamente)
TRUNCATE TABLE cuentas_corrientes RESTART IDENTITY CASCADE;

-- Verificación: Las tablas deben estar vacías
DO $$
DECLARE
  headers_count INTEGER;
  detalles_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO headers_count FROM cuentas_corrientes;
  SELECT COUNT(*) INTO detalles_count FROM detalle_cuentas_corrientes;

  IF headers_count > 0 OR detalles_count > 0 THEN
    RAISE EXCEPTION 'ERROR: Las tablas no están vacías después del TRUNCATE';
  END IF;

  RAISE NOTICE 'OK: Tablas vaciadas correctamente';
END $$;

-- Reactivar triggers
ALTER TABLE cuentas_corrientes ENABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes ENABLE TRIGGER ALL;


-- ============================================================================
-- OPCIÓN 3: BORRAR TODO SIN REINICIAR SECUENCIA (preservar numeración)
-- ============================================================================

-- Útil si quieres seguir con la numeración actual después de borrar
/*
-- Deshabilitar triggers
ALTER TABLE cuentas_corrientes DISABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes DISABLE TRIGGER ALL;

-- Borrar detalles primero
DELETE FROM detalle_cuentas_corrientes;

-- Borrar headers
DELETE FROM cuentas_corrientes;

-- Reactivar triggers
ALTER TABLE cuentas_corrientes ENABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes ENABLE TRIGGER ALL;

-- La secuencia mantiene su valor actual
*/


-- Paso 2: Mostrar estadísticas después del borrado
SELECT
  'DESPUÉS DEL BORRADO' as momento,
  (SELECT COUNT(*) FROM cuentas_corrientes) as total_headers,
  (SELECT COUNT(*) FROM detalle_cuentas_corrientes) as total_detalles,
  (SELECT currval('cuentas_corrientes_idtransaccion_seq')) as secuencia_actual;


-- Si todo está OK, hacer commit
COMMIT;

-- Si algo salió mal, descomentar para deshacer:
-- ROLLBACK;


-- ============================================================================
-- VERIFICACIONES FINALES
-- ============================================================================

-- Verificar que no haya registros huérfanos
SELECT
  'Detalles huérfanos' as tipo,
  COUNT(*) as cantidad
FROM detalle_cuentas_corrientes d
WHERE NOT EXISTS (
  SELECT 1 FROM cuentas_corrientes c
  WHERE c.idtransaccion = d.idtransaccion
);

-- Verificar estado de la secuencia
SELECT
  'Estado de secuencia' as info,
  last_value as ultimo_valor,
  is_called
FROM cuentas_corrientes_idtransaccion_seq;
