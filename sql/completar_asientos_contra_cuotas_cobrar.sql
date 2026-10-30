-- ============================================================================
-- Completa asientos desbalanceados (haber=0, debe>0) contra cuenta 5100000
-- ----------------------------------------------------------------------------
-- Para cada asiento donde SUM(haber)=0 y SUM(debe)>0,
-- agrega un ítem con el importe faltante en el HABER contra "Cuotas a cobrar"
-- (cuenta 5100000).
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_cuenta_id  INTEGER;
  v_max_item   INTEGER;
  v_diferencia NUMERIC(18,2);
  r            RECORD;
BEGIN
  -- Buscar cuenta_id de la cuenta 5100000
  SELECT id INTO v_cuenta_id FROM cuentas WHERE cuenta = 5100000;

  IF v_cuenta_id IS NULL THEN
    RAISE EXCEPTION 'No se encontró la cuenta 5100000 en la tabla cuentas';
  END IF;

  RAISE NOTICE 'Usando cuenta_id=% para cuenta 5100000', v_cuenta_id;

  -- Iterar sobre asientos con SUM(haber)=0 y SUM(debe)>0
  FOR r IN
    SELECT
      ah.asiento,
      ah.anio_mes,
      ah.tipo_asiento,
      ah.fecha,
      ah.detalle,
      SUM(ai.debe)  AS total_debe,
      SUM(ai.haber) AS total_haber,
      SUM(ai.debe) - SUM(ai.haber) AS diferencia
    FROM asientos_header ah
    JOIN asientos_items ai
      ON ah.asiento      = ai.asiento
     AND ah.anio_mes     = ai.anio_mes
     AND ah.tipo_asiento = ai.tipo_asiento
    GROUP BY ah.asiento, ah.anio_mes, ah.tipo_asiento, ah.fecha, ah.detalle
    HAVING SUM(ai.haber) = 0
       AND SUM(ai.debe)  > 0
  LOOP
    v_diferencia := r.diferencia;

    -- Próximo número de ítem para este asiento
    SELECT COALESCE(MAX(item), 0) + 1
      INTO v_max_item
      FROM asientos_items
     WHERE asiento      = r.asiento
       AND anio_mes     = r.anio_mes
       AND tipo_asiento = r.tipo_asiento;

    INSERT INTO asientos_items
      (asiento, anio_mes, tipo_asiento, item, cuenta_id, debe, haber, observacion)
    VALUES
      (r.asiento, r.anio_mes, r.tipo_asiento, v_max_item,
       v_cuenta_id, 0, v_diferencia, 'Completado automático - Cuotas a cobrar');

    RAISE NOTICE 'Asiento %  (% / tipo %) => haber agregado: %',
      r.asiento, r.fecha, r.tipo_asiento, v_diferencia;
  END LOOP;

END $$;

-- Verificación antes de confirmar:
SELECT
  ah.asiento,
  ah.fecha,
  ah.detalle,
  SUM(ai.debe)            AS total_debe,
  SUM(ai.haber)           AS total_haber,
  SUM(ai.debe - ai.haber) AS diferencia
FROM asientos_header ah
JOIN asientos_items ai
  ON ah.asiento      = ai.asiento
 AND ah.anio_mes     = ai.anio_mes
 AND ah.tipo_asiento = ai.tipo_asiento
WHERE ah.asiento IN (
  -- Los asientos afectados (para control)
  SELECT ai2.asiento
  FROM asientos_items ai2
  WHERE ai2.cuenta_id = (SELECT id FROM cuentas WHERE cuenta = 5100000)
    AND ai2.observacion = 'Completado automático - Cuotas a cobrar'
)
GROUP BY ah.asiento, ah.fecha, ah.detalle
ORDER BY ah.fecha, ah.asiento;

COMMIT;
