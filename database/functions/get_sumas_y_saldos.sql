-- Función: Sumas y Saldos Contable
-- Retorna todas las cuentas imputables con saldo de apertura (antes de fecha_desde),
-- movimientos del período (fecha_desde..fecha_hasta) y saldo final.
-- Si con_apertura = false, inicio siempre es 0.

CREATE OR REPLACE FUNCTION get_sumas_y_saldos(
  p_fecha_desde DATE,
  p_fecha_hasta DATE,
  p_con_apertura BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
  cuenta         INTEGER,
  descripcion    TEXT,
  inicio         NUMERIC,
  debe           NUMERIC,
  haber          NUMERIC,
  saldo          NUMERIC
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    c.cuenta,
    c.descripcion::TEXT,
    CASE WHEN p_con_apertura THEN
      COALESCE(SUM(i.debe) FILTER (WHERE h.fecha < p_fecha_desde), 0)
      - COALESCE(SUM(i.haber) FILTER (WHERE h.fecha < p_fecha_desde), 0)
    ELSE 0
    END AS inicio,
    COALESCE(SUM(i.debe) FILTER (WHERE h.fecha BETWEEN p_fecha_desde AND p_fecha_hasta), 0) AS debe,
    COALESCE(SUM(i.haber) FILTER (WHERE h.fecha BETWEEN p_fecha_desde AND p_fecha_hasta), 0) AS haber,
    CASE WHEN p_con_apertura THEN
      COALESCE(SUM(i.debe) FILTER (WHERE h.fecha <= p_fecha_hasta), 0)
      - COALESCE(SUM(i.haber) FILTER (WHERE h.fecha <= p_fecha_hasta), 0)
    ELSE
      COALESCE(SUM(i.debe) FILTER (WHERE h.fecha BETWEEN p_fecha_desde AND p_fecha_hasta), 0)
      - COALESCE(SUM(i.haber) FILTER (WHERE h.fecha BETWEEN p_fecha_desde AND p_fecha_hasta), 0)
    END AS saldo
  FROM cuentas c
  LEFT JOIN asientos_items i ON i.cuenta_id = c.cuenta
  LEFT JOIN asientos_header h ON h.asiento = i.asiento
                              AND h.anio_mes = i.anio_mes
                              AND h.tipo_asiento = i.tipo_asiento
  WHERE c.imputable = TRUE
    AND c.activo = TRUE
    AND (
      -- Solo incluir cuentas que tengan movimiento en algún período relevante
      (p_con_apertura AND (h.fecha IS NULL OR h.fecha <= p_fecha_hasta))
      OR (NOT p_con_apertura AND (h.fecha IS NULL OR h.fecha BETWEEN p_fecha_desde AND p_fecha_hasta))
    )
  GROUP BY c.cuenta, c.descripcion
  HAVING
    CASE WHEN p_con_apertura THEN
      COALESCE(SUM(i.debe) FILTER (WHERE h.fecha <= p_fecha_hasta), 0)
      + COALESCE(SUM(i.haber) FILTER (WHERE h.fecha <= p_fecha_hasta), 0)
      > 0
    ELSE
      COALESCE(SUM(i.debe) FILTER (WHERE h.fecha BETWEEN p_fecha_desde AND p_fecha_hasta), 0)
      + COALESCE(SUM(i.haber) FILTER (WHERE h.fecha BETWEEN p_fecha_desde AND p_fecha_hasta), 0)
      > 0
    END
  ORDER BY c.cuenta
$$;

-- Permisos
GRANT EXECUTE ON FUNCTION get_sumas_y_saldos(DATE, DATE, BOOLEAN) TO authenticated;
