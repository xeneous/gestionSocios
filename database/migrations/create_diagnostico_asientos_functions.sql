-- Funciones de diagnóstico contable
-- Ejecutar en Supabase SQL Editor

-- 1. Asientos desbalanceados (debe ≠ haber) en un período
CREATE OR REPLACE FUNCTION get_asientos_desbalanceados(
  p_fecha_desde DATE,
  p_fecha_hasta DATE
) RETURNS TABLE (
  asiento      INT,
  anio_mes     INT,
  fecha        DATE,
  tipo_asiento INT,
  detalle      TEXT,
  total_debe   NUMERIC,
  total_haber  NUMERIC,
  diferencia   NUMERIC
) LANGUAGE sql STABLE AS $$
  SELECT
    h.asiento,
    h.anio_mes,
    h.fecha,
    h.tipo_asiento,
    h.detalle,
    COALESCE(SUM(i.debe),  0) AS total_debe,
    COALESCE(SUM(i.haber), 0) AS total_haber,
    ABS(COALESCE(SUM(i.debe), 0) - COALESCE(SUM(i.haber), 0)) AS diferencia
  FROM asientos_header h
  LEFT JOIN asientos_items i
    ON i.asiento  = h.asiento
   AND i.anio_mes = h.anio_mes
  WHERE h.fecha BETWEEN p_fecha_desde AND p_fecha_hasta
  GROUP BY h.id, h.asiento, h.anio_mes, h.fecha, h.tipo_asiento, h.detalle
  HAVING ABS(COALESCE(SUM(i.debe), 0) - COALESCE(SUM(i.haber), 0)) >= 0.01
  ORDER BY h.fecha, h.asiento;
$$;

-- 2. Cuenta_id usados en asientos_items que no existen en la tabla cuentas
CREATE OR REPLACE FUNCTION get_cuentas_inexistentes_en_asientos(
  p_fecha_desde DATE DEFAULT NULL,
  p_fecha_hasta DATE DEFAULT NULL
) RETURNS TABLE (
  cuenta_id      INT,
  cantidad_usos  BIGINT,
  primer_asiento INT,
  ultima_fecha   DATE
) LANGUAGE sql STABLE AS $$
  SELECT
    i.cuenta_id,
    COUNT(*)           AS cantidad_usos,
    MIN(i.asiento)     AS primer_asiento,
    MAX(h.fecha)       AS ultima_fecha
  FROM asientos_items i
  JOIN asientos_header h
    ON h.asiento  = i.asiento
   AND h.anio_mes = i.anio_mes
  LEFT JOIN cuentas c ON c.cuenta = i.cuenta_id
  WHERE c.cuenta IS NULL
    AND (p_fecha_desde IS NULL OR h.fecha >= p_fecha_desde)
    AND (p_fecha_hasta IS NULL OR h.fecha <= p_fecha_hasta)
  GROUP BY i.cuenta_id
  ORDER BY i.cuenta_id;
$$;



