-- ============================================================================
-- MIGRACIÓN COMPLETA DE CUENTAS CORRIENTES CON IDs ESPECÍFICOS
-- ============================================================================
-- Este script permite migrar datos desde otra fuente manteniendo los IDs
-- originales, manejando foreign keys y secuencias correctamente
-- ============================================================================

BEGIN;

-- ============================================================================
-- FASE 1: PREPARACIÓN - Deshabilitar constraints y triggers
-- ============================================================================

RAISE NOTICE 'Fase 1: Deshabilitando triggers...';

-- Deshabilitar triggers temporalmente
ALTER TABLE cuentas_corrientes DISABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes DISABLE TRIGGER ALL;

RAISE NOTICE 'OK: Triggers deshabilitados';


-- ============================================================================
-- FASE 2: LIMPIEZA (OPCIONAL) - Solo si quieres empezar desde cero
-- ============================================================================

-- Descomentar si necesitas borrar datos existentes
/*
RAISE NOTICE 'Fase 2: Borrando datos existentes...';

TRUNCATE TABLE cuentas_corrientes RESTART IDENTITY CASCADE;

RAISE NOTICE 'OK: Datos borrados y secuencia reiniciada';
*/


-- ============================================================================
-- FASE 3: INSERCIÓN DE HEADERS - Con IDs específicos
-- ============================================================================

RAISE NOTICE 'Fase 3: Insertando headers de cuentas corrientes...';

-- IMPORTANTE: Reemplaza este bloque con tus datos reales
-- El OVERRIDING SYSTEM VALUE permite insertar con IDs específicos

INSERT INTO cuentas_corrientes (
  idtransaccion,
  socio_id,
  tipo_comprobante,
  numero_comprobante,
  documento_numero,
  fecha,
  importe,
  saldo,
  observaciones
)
OVERRIDING SYSTEM VALUE
VALUES
  -- Ejemplo de registros - REEMPLAZAR CON TUS DATOS
  (1, 1, 'CS ', 1, '202601', '2026-01-15', 5000.00, 0, 'Cuota Social Enero 2026'),
  (2, 2, 'CS ', 2, '202601', '2026-01-15', 5000.00, 0, 'Cuota Social Enero 2026'),
  (3, 3, 'CS ', 3, '202601', '2026-01-15', 5000.00, 0, 'Cuota Social Enero 2026')
-- Continuar con más registros...
ON CONFLICT (idtransaccion) DO NOTHING; -- Ignorar duplicados

RAISE NOTICE 'OK: Headers insertados';


-- ============================================================================
-- FASE 4: INSERCIÓN DE DETALLES
-- ============================================================================

RAISE NOTICE 'Fase 4: Insertando detalles de cuentas corrientes...';

INSERT INTO detalle_cuentas_corrientes (
  idtransaccion,
  item,
  concepto_codigo,
  importe,
  observaciones
)
VALUES
  -- Ejemplo de detalles - REEMPLAZAR CON TUS DATOS
  (1, 1, 'CS', 5000.00, 'Cuota Social'),
  (2, 1, 'CS', 5000.00, 'Cuota Social'),
  (3, 1, 'CS', 5000.00, 'Cuota Social')
-- Continuar con más detalles...
ON CONFLICT DO NOTHING; -- Por si hay constraint único

RAISE NOTICE 'OK: Detalles insertados';


-- ============================================================================
-- FASE 5: ACTUALIZAR SECUENCIA
-- ============================================================================

RAISE NOTICE 'Fase 5: Actualizando secuencia...';

-- Actualizar la secuencia al siguiente valor disponible
SELECT setval(
  'cuentas_corrientes_idtransaccion_seq',
  (SELECT COALESCE(MAX(idtransaccion), 0) FROM cuentas_corrientes),
  true -- true = el valor ya fue usado, el siguiente será +1
);

RAISE NOTICE 'OK: Secuencia actualizada';


-- ============================================================================
-- FASE 6: REACTIVAR TRIGGERS
-- ============================================================================

RAISE NOTICE 'Fase 6: Reactivando triggers...';

ALTER TABLE cuentas_corrientes ENABLE TRIGGER ALL;
ALTER TABLE detalle_cuentas_corrientes ENABLE TRIGGER ALL;

RAISE NOTICE 'OK: Triggers reactivados';


-- ============================================================================
-- FASE 7: VERIFICACIONES
-- ============================================================================

RAISE NOTICE 'Fase 7: Ejecutando verificaciones...';

-- Verificar integridad referencial
DO $$
DECLARE
  huerfanos_detalles INTEGER;
  headers_sin_detalles INTEGER;
  inconsistencias_importes INTEGER;
BEGIN
  -- 1. Verificar detalles huérfanos
  SELECT COUNT(*) INTO huerfanos_detalles
  FROM detalle_cuentas_corrientes d
  WHERE NOT EXISTS (
    SELECT 1 FROM cuentas_corrientes c
    WHERE c.idtransaccion = d.idtransaccion
  );

  IF huerfanos_detalles > 0 THEN
    RAISE EXCEPTION 'ERROR: % detalles huérfanos encontrados', huerfanos_detalles;
  END IF;

  -- 2. Verificar headers sin detalles
  SELECT COUNT(*) INTO headers_sin_detalles
  FROM cuentas_corrientes c
  WHERE NOT EXISTS (
    SELECT 1 FROM detalle_cuentas_corrientes d
    WHERE d.idtransaccion = c.idtransaccion
  );

  IF headers_sin_detalles > 0 THEN
    RAISE WARNING 'ADVERTENCIA: % headers sin detalles', headers_sin_detalles;
  END IF;

  -- 3. Verificar que los importes cuadren
  SELECT COUNT(*) INTO inconsistencias_importes
  FROM cuentas_corrientes c
  LEFT JOIN (
    SELECT idtransaccion, SUM(importe) as total_detalles
    FROM detalle_cuentas_corrientes
    GROUP BY idtransaccion
  ) d ON c.idtransaccion = d.idtransaccion
  WHERE ABS(c.importe - COALESCE(d.total_detalles, 0)) > 0.01;

  IF inconsistencias_importes > 0 THEN
    RAISE WARNING 'ADVERTENCIA: % registros con diferencias en importes', inconsistencias_importes;
  END IF;

  RAISE NOTICE 'Verificaciones completadas:';
  RAISE NOTICE '  - Detalles huérfanos: %', huerfanos_detalles;
  RAISE NOTICE '  - Headers sin detalles: %', headers_sin_detalles;
  RAISE NOTICE '  - Inconsistencias de importes: %', inconsistencias_importes;
END $$;


-- ============================================================================
-- ESTADÍSTICAS FINALES
-- ============================================================================

SELECT
  'MIGRACIÓN COMPLETADA' as status,
  (SELECT COUNT(*) FROM cuentas_corrientes) as total_headers,
  (SELECT COUNT(*) FROM detalle_cuentas_corrientes) as total_detalles,
  (SELECT COALESCE(MAX(idtransaccion), 0) FROM cuentas_corrientes) as max_idtransaccion,
  (SELECT last_value FROM cuentas_corrientes_idtransaccion_seq) as secuencia_actual;


-- ============================================================================
-- COMMIT O ROLLBACK
-- ============================================================================

-- Si todo está correcto, hacer COMMIT
COMMIT;

RAISE NOTICE '✓ MIGRACIÓN EXITOSA - Cambios confirmados';

-- Si algo salió mal, ejecutar ROLLBACK manualmente:
-- ROLLBACK;
-- RAISE NOTICE '✗ MIGRACIÓN CANCELADA - Cambios revertidos';
