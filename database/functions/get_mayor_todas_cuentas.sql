-- Función: Mayor de TODAS las cuentas contables (para exportar a Excel)
-- Devuelve JSON (evita el límite de 1000 filas de PostgREST):
--   [ { cuenta, descripcion, saldo_inicial,
--       movimientos: [ {fecha, asiento, detalle, debe, haber} ] } , ... ]
-- Incluye solo cuentas con movimientos en el período o, si p_con_apertura,
-- con saldo inicial distinto de cero. Misma lógica que get_mayor_cuenta.

CREATE OR REPLACE FUNCTION get_mayor_todas_cuentas(
  p_fecha_desde  DATE,
  p_fecha_hasta  DATE,
  p_con_apertura BOOLEAN DEFAULT TRUE
)
RETURNS JSON
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
SET statement_timeout = '120s'
AS $$
  WITH base AS (
    SELECT i.cuenta_id AS cuenta,
           h.fecha,
           h.asiento,
           COALESCE(h.detalle, '') AS detalle,
           COALESCE(i.debe, 0)     AS debe,
           COALESCE(i.haber, 0)    AS haber
    FROM asientos_items i
    JOIN asientos_header h
      ON h.asiento      = i.asiento
     AND h.anio_mes     = i.anio_mes
     AND h.tipo_asiento = i.tipo_asiento
    WHERE h.fecha <= p_fecha_hasta
  ),
  ini AS (
    SELECT cuenta, SUM(debe) - SUM(haber) AS saldo
    FROM base
    WHERE p_con_apertura AND fecha < p_fecha_desde
    GROUP BY cuenta
  ),
  mov AS (
    SELECT cuenta,
           json_agg(
             json_build_object(
               'fecha',   fecha,
               'asiento', asiento,
               'detalle', detalle,
               'debe',    debe,
               'haber',   haber
             ) ORDER BY fecha, asiento
           ) AS movs
    FROM base
    WHERE fecha >= p_fecha_desde
    GROUP BY cuenta
  ),
  ctas AS (
    SELECT cuenta FROM ini WHERE saldo <> 0
    UNION
    SELECT cuenta FROM mov
  )
  SELECT COALESCE(
    json_agg(
      json_build_object(
        'cuenta',        c.cuenta,
        'descripcion',   COALESCE(cu.descripcion, ''),
        'saldo_inicial', COALESCE(ini.saldo, 0),
        'movimientos',   COALESCE(mov.movs, '[]'::json)
      ) ORDER BY c.cuenta
    ),
    '[]'::json
  )
  FROM ctas c
  LEFT JOIN cuentas cu ON cu.cuenta = c.cuenta
  LEFT JOIN ini        ON ini.cuenta = c.cuenta
  LEFT JOIN mov        ON mov.cuenta = c.cuenta
$$;

GRANT EXECUTE ON FUNCTION get_mayor_todas_cuentas(DATE, DATE, BOOLEAN) TO authenticated;
