-- Función RPC optimizada para obtener resumen de cuentas corrientes
-- Procesa todo en el servidor para máximo rendimiento
-- Soporta paginación

CREATE OR REPLACE FUNCTION obtener_resumen_cuentas_corrientes(
    p_limit INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    socio_id INTEGER,
    apellido VARCHAR(50),
    nombre VARCHAR(50),
    grupo CHAR(1),
    saldo NUMERIC,
    rda_pendiente NUMERIC,
    telefono VARCHAR(50),
    email VARCHAR(100),
    total_count BIGINT
) AS $$
DECLARE
    v_total_count BIGINT;
BEGIN
    -- Obtener el total de registros (solo grupos activos: A, T, H, V)
    SELECT COUNT(DISTINCT s.id) INTO v_total_count
    FROM socios s
    WHERE s.activo = TRUE
      AND s.grupo IN ('A', 'T', 'H', 'V');

    RETURN QUERY
    SELECT
        s.id::INTEGER as socio_id,
        s.apellido,
        s.nombre,
        s.grupo,
        -- Saldo total = suma de (importe - cancelado)
        COALESCE(SUM(cc.importe - cc.cancelado), 0)::NUMERIC as saldo,
        -- RDA pendiente = suma de (importe - cancelado) solo para tipo_comprobante = 'RDA'
        COALESCE(
            SUM(
                CASE
                    WHEN cc.tipo_comprobante = 'RDA' THEN cc.importe - cc.cancelado
                    ELSE 0
                END
            ),
            0
        )::NUMERIC as rda_pendiente,
        s.telefono,
        s.email,
        v_total_count as total_count
    FROM socios s
    LEFT JOIN cuentas_corrientes cc ON cc.socio_id = s.id
    WHERE s.activo = TRUE
      AND s.grupo IN ('A', 'T', 'H', 'V')
    GROUP BY
        s.id,
        s.apellido,
        s.nombre,
        s.grupo,
        s.telefono,
        s.email
    ORDER BY s.apellido, s.nombre
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE;

-- Comentario de la función
COMMENT ON FUNCTION obtener_resumen_cuentas_corrientes IS
'Obtiene un resumen de las cuentas corrientes de todos los socios activos.
Retorna: socio_id, apellido, nombre, grupo, saldo total, RDA pendiente, teléfono, email.
Optimizada para procesar en el servidor.';
