-- Función: Mayor de Cuenta Contable
-- Devuelve JSON para evitar el límite de 1000 filas de PostgREST.
-- Retorna: { saldo_inicial: number, movimientos: [{fecha, asiento, detalle, debe, haber}] }

CREATE OR REPLACE FUNCTION get_mayor_cuenta(
  p_cuenta       INTEGER,
  p_fecha_desde  DATE,
  p_fecha_hasta  DATE,
  p_con_apertura BOOLEAN DEFAULT TRUE
)
RETURNS JSON
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT json_build_object(
    'saldo_inicial',
    CASE WHEN p_con_apertura THEN
      COALESCE(SUM(i.debe) FILTER (WHERE h.fecha < p_fecha_desde), 0)
      - COALESCE(SUM(i.haber) FILTER (WHERE h.fecha < p_fecha_desde), 0)
    ELSE 0 END,
    'movimientos',
    COALESCE(
      (
        SELECT json_agg(
          json_build_object(
            'fecha',    m.fecha,
            'asiento',  m.asiento,
            'detalle',  m.detalle,
            'debe',     m.debe,
            'haber',    m.haber
          )
          ORDER BY m.fecha, m.asiento
        )
        FROM (
          SELECT
            h2.fecha,
            h2.asiento,
            COALESCE(h2.detalle, '') AS detalle,
            COALESCE(i2.debe, 0)    AS debe,
            COALESCE(i2.haber, 0)   AS haber
          FROM asientos_items i2
          JOIN asientos_header h2
            ON h2.asiento     = i2.asiento
           AND h2.anio_mes    = i2.anio_mes
           AND h2.tipo_asiento = i2.tipo_asiento
          WHERE i2.cuenta_id = p_cuenta
            AND h2.fecha BETWEEN p_fecha_desde AND p_fecha_hasta
        ) m
      ),
      '[]'::json
    )
  )
  FROM asientos_items i
  JOIN asientos_header h
    ON h.asiento      = i.asiento
   AND h.anio_mes     = i.anio_mes
   AND h.tipo_asiento = i.tipo_asiento
  WHERE i.cuenta_id = p_cuenta
$$;

-- Permisos
GRANT EXECUTE ON FUNCTION get_mayor_cuenta(INTEGER, DATE, DATE, BOOLEAN) TO authenticated;
