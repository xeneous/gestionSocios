-- ============================================================================
-- Asiento de diario: REVERSIÓN de saldos acumulados al 01/08/2025
-- ----------------------------------------------------------------------------
-- Toma el saldo neto por cuenta (SUM(debe) - SUM(haber)) de todo lo
-- registrado ANTES del 02/08/2025 y lo contabiliza INVERTIDO en un único
-- asiento con fecha 01/08/2025, de modo que el saldo de APERTURA al
-- 02/08/2025 quede en CERO para cada cuenta:
--   saldo neto deudor  (debe-haber > 0)  -> se acredita (haber)
--   saldo neto acreedor (debe-haber < 0) -> se debita  (debe)
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_anio_mes     INTEGER := 202508;         -- período YYYYMM del nuevo asiento
  v_tipo_asiento INTEGER := 0;              -- 0 = Diario
  v_fecha        DATE    := DATE '2025-08-01';
  v_detalle      TEXT    := 'Ajuste de sistema anterior';
  v_asiento      INTEGER;
BEGIN
  -- Número de asiento siguiente para ese período y tipo
  SELECT COALESCE(MAX(asiento), 0) + 1
    INTO v_asiento
    FROM asientos_header
   WHERE anio_mes = v_anio_mes
     AND tipo_asiento = v_tipo_asiento;

  -- Cabecera
  INSERT INTO asientos_header (asiento, anio_mes, tipo_asiento, fecha, detalle)
  VALUES (v_asiento, v_anio_mes, v_tipo_asiento, v_fecha, v_detalle);

  -- Ítems: revierte el saldo NETO por cuenta para dejar apertura en cero
  INSERT INTO asientos_items
    (asiento, anio_mes, tipo_asiento, item, cuenta_id, debe, haber, observacion)
  SELECT
    v_asiento,
    v_anio_mes,
    v_tipo_asiento,
    ROW_NUMBER() OVER (ORDER BY s.cuenta_id)        AS item,
    s.cuenta_id,
    CASE WHEN s.saldo < 0 THEN -s.saldo ELSE 0 END  AS debe,   -- revierte saldo acreedor
    CASE WHEN s.saldo > 0 THEN  s.saldo ELSE 0 END  AS haber,  -- revierte saldo deudor
    v_detalle
  FROM (
      SELECT
        ai.cuenta_id,
        SUM(ai.debe) - SUM(ai.haber) AS saldo
      FROM asientos_header ah
      JOIN asientos_items ai
        ON ah.anio_mes     = ai.anio_mes
       AND ah.tipo_asiento = ai.tipo_asiento
       AND ah.asiento      = ai.asiento
      WHERE ah.fecha < DATE '2025-08-02'
      GROUP BY ai.cuenta_id
      HAVING SUM(ai.debe) - SUM(ai.haber) <> 0   -- solo cuentas con saldo
  ) s;

  RAISE NOTICE 'Asiento creado: tipo=% periodo=% nro=%',
    v_tipo_asiento, v_anio_mes, v_asiento;
END $$;

-- Revisá el resultado antes de confirmar:
-- COMMIT;  -- descomentar para guardar
-- ROLLBACK; -- o descomentar para descartar

COMMIT;
