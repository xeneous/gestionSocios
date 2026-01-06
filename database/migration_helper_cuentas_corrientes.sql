-- ============================================================================
-- SCRIPT DE AYUDA PARA MIGRACIÓN DE CUENTAS CORRIENTES
-- Permite insertar registros con IDs específicos y manejar foreign keys
-- ============================================================================

-- PASO 1: Deshabilitar temporalmente los triggers y constraints
-- ----------------------------------------------------------------------------

-- Deshabilitar triggers en cuentas_corrientes
ALTER TABLE cuentas_corrientes DISABLE TRIGGER ALL;

-- Deshabilitar triggers en detalle_cuentas_corrientes
ALTER TABLE detalle_cuentas_corrientes DISABLE TRIGGER ALL;

-- PASO 2: Si necesitas borrar datos existentes (CUIDADO!)
-- ----------------------------------------------------------------------------
-- Descomentar solo si realmente necesitas borrar todo

-- TRUNCATE TABLE detalle_cuentas_corrientes CASCADE;
-- TRUNCATE TABLE cuentas_corrientes RESTART IDENTITY CASCADE;


-- PASO 3: Preparar para inserción con IDs específicos
-- ----------------------------------------------------------------------------
-- No es necesario hacer nada especial, usaremos OVERRIDING SYSTEM VALUE


-- PASO 4: Insertar datos (EJEMPLO - reemplazar con tus datos reales)
-- ----------------------------------------------------------------------------

-- Ejemplo de inserción con ID específico en cuentas_corrientes
/*
INSERT INTO cuentas_corrientes (
  idtransaccion, socio_id, tipo_comprobante, numero_comprobante,
  documento_numero, fecha, importe, saldo, observaciones
)
OVERRIDING SYSTEM VALUE
VALUES
  (1, 123, 'CS ', 1, '202601', '2026-01-15', 5000.00, 0, 'Cuota Enero 2026'),
  (2, 124, 'CS ', 2, '202601', '2026-01-15', 5000.00, 0, 'Cuota Enero 2026');

-- Ejemplo de inserción en detalle_cuentas_corrientes
INSERT INTO detalle_cuentas_corrientes (
  idtransaccion, item, concepto_codigo, importe, observaciones
)
VALUES
  (1, 1, 'CS', 5000.00, 'Cuota Social Enero'),
  (2, 1, 'CS', 5000.00, 'Cuota Social Enero');
*/


-- PASO 5: Después de la migración - Reactivar triggers y actualizar secuencias
-- ----------------------------------------------------------------------------

-- Reactivar triggers en cuentas_corrientes
ALTER TABLE cuentas_corrientes ENABLE TRIGGER ALL;

-- Reactivar triggers en detalle_cuentas_corrientes
ALTER TABLE detalle_cuentas_corrientes ENABLE TRIGGER ALL;

-- Actualizar la secuencia de idtransaccion al último valor
SELECT setval(
  'cuentas_corrientes_idtransaccion_seq',
  (SELECT COALESCE(MAX(idtransaccion), 0) FROM cuentas_corrientes)
);

-- Verificar que la secuencia esté correcta
SELECT
  currval('cuentas_corrientes_idtransaccion_seq') as valor_actual_secuencia,
  (SELECT MAX(idtransaccion) FROM cuentas_corrientes) as max_id_tabla;


-- ============================================================================
-- SCRIPT ALTERNATIVO: BORRAR DATOS CON FOREIGN KEYS
-- ============================================================================

-- Si solo necesitas borrar datos sin truncar
/*
-- Borrar en orden correcto (hijos primero, padres después)
DELETE FROM detalle_cuentas_corrientes
WHERE idtransaccion IN (
  SELECT idtransaccion FROM cuentas_corrientes WHERE condicion
);

DELETE FROM cuentas_corrientes WHERE condicion;
*/


-- ============================================================================
-- SCRIPT PARA BORRAR COMPLETAMENTE Y REINICIAR
-- ============================================================================

-- ADVERTENCIA: Esto borra TODOS los datos de cuentas corrientes
-- Solo ejecutar si estás 100% seguro

/*
BEGIN;

-- Deshabilitar triggers
ALTER TABLE cuentas_corrientes DISABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes DISABLE TRIGGER ALL;

-- Borrar todo (CASCADE elimina los detalles automáticamente)
TRUNCATE TABLE cuentas_corrientes RESTART IDENTITY CASCADE;

-- Reactivar triggers
ALTER TABLE cuentas_corrientes ENABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes ENABLE TRIGGER ALL;

-- Verificar que las tablas estén vacías
SELECT COUNT(*) as cuentas_corrientes_count FROM cuentas_corrientes;
SELECT COUNT(*) as detalle_count FROM detalle_cuentas_corrientes;

-- Verificar que la secuencia esté en 1
SELECT currval('cuentas_corrientes_idtransaccion_seq') as secuencia_valor;

COMMIT;
-- Si algo sale mal: ROLLBACK;
*/


-- ============================================================================
-- VERIFICACIONES POST-MIGRACIÓN
-- ============================================================================

-- Verificar integridad referencial
DO $$
DECLARE
  huerfanos INTEGER;
BEGIN
  -- Verificar que todos los detalles tengan un header válido
  SELECT COUNT(*) INTO huerfanos
  FROM detalle_cuentas_corrientes d
  WHERE NOT EXISTS (
    SELECT 1 FROM cuentas_corrientes c
    WHERE c.idtransaccion = d.idtransaccion
  );

  IF huerfanos > 0 THEN
    RAISE WARNING 'ATENCIÓN: % registros huérfanos en detalle_cuentas_corrientes', huerfanos;
  ELSE
    RAISE NOTICE 'OK: Todos los detalles tienen su header correspondiente';
  END IF;

  -- Verificar que todos los headers tengan al menos un detalle
  SELECT COUNT(*) INTO huerfanos
  FROM cuentas_corrientes c
  WHERE NOT EXISTS (
    SELECT 1 FROM detalle_cuentas_corrientes d
    WHERE d.idtransaccion = c.idtransaccion
  );

  IF huerfanos > 0 THEN
    RAISE WARNING 'ATENCIÓN: % headers sin detalles en cuentas_corrientes', huerfanos;
  ELSE
    RAISE NOTICE 'OK: Todos los headers tienen al menos un detalle';
  END IF;
END $$;

-- Verificar que los totales cuadren
SELECT
  c.idtransaccion,
  c.importe as importe_header,
  COALESCE(SUM(d.importe), 0) as suma_detalles,
  c.importe - COALESCE(SUM(d.importe), 0) as diferencia
FROM cuentas_corrientes c
LEFT JOIN detalle_cuentas_corrientes d ON c.idtransaccion = d.idtransaccion
GROUP BY c.idtransaccion, c.importe
HAVING ABS(c.importe - COALESCE(SUM(d.importe), 0)) > 0.01
ORDER BY c.idtransaccion;
