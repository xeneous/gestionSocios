-- Función RPC optimizada para obtener resumen de cuentas corrientes
-- Procesa todo en el servidor para máximo rendimiento
-- Soporta paginación y múltiples filtros

DROP FUNCTION IF EXISTS obtener_resumen_cuentas_corrientes(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS obtener_resumen_cuentas_corrientes(INTEGER, INTEGER, BOOLEAN);
DROP FUNCTION IF EXISTS obtener_resumen_cuentas_corrientes(INTEGER, INTEGER, BOOLEAN, INTEGER, BOOLEAN, INTEGER, BOOLEAN);

CREATE OR REPLACE FUNCTION obtener_resumen_cuentas_corrientes(
    p_limit INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0,
    p_solo_activos BOOLEAN DEFAULT TRUE,
    p_meses_minimo INTEGER DEFAULT NULL,
    p_meses_exacto BOOLEAN DEFAULT FALSE,
    p_tarjeta_id INTEGER DEFAULT NULL,
    p_solo_residentes BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    socio_id INTEGER,
    apellido VARCHAR(50),
    nombre VARCHAR(50),
    grupo CHAR(1),
    saldo NUMERIC,
    rda_pendiente NUMERIC,
    meses_impagos BIGINT,
    telefono VARCHAR(50),
    email VARCHAR(100),
    tarjeta_id INTEGER,
    residente BOOLEAN,
    total_count BIGINT
) AS $$
DECLARE
    v_total_count BIGINT;
BEGIN
    -- Primero calcular los meses impagos para cada socio en una CTE
    -- y luego contar los que cumplen el filtro
    WITH socio_meses AS (
        SELECT
            s.id,
            s.apellido as s_apellido,
            s.nombre as s_nombre,
            s.grupo as s_grupo,
            s.telefono as s_telefono,
            s.email as s_email,
            s.tarjeta_id as s_tarjeta_id,
            s.residente as s_residente,
            COALESCE(SUM(cc.importe - COALESCE(cc.cancelado, 0)), 0) as saldo,
            COALESCE(
                SUM(
                    CASE
                        WHEN cc.tipo_comprobante = 'RDA' THEN cc.importe - COALESCE(cc.cancelado, 0)
                        ELSE 0
                    END
                ),
                0
            ) as rda_pendiente,
            COUNT(CASE WHEN cc.importe > COALESCE(cc.cancelado, 0) THEN 1 END) as meses_impagos
        FROM socios s
        INNER JOIN grupos_agrupados ga ON ga.codigo = s.grupo
        LEFT JOIN cuentas_corrientes cc ON cc.socio_id = s.id
        WHERE s.activo = TRUE
          AND (p_solo_activos = FALSE OR ga.activo = TRUE)
          AND (p_tarjeta_id IS NULL OR s.tarjeta_id = p_tarjeta_id)
          AND (p_solo_residentes = FALSE OR s.residente = TRUE)
        GROUP BY s.id, s.apellido, s.nombre, s.grupo, s.telefono, s.email, s.tarjeta_id, s.residente
    )
    SELECT COUNT(*) INTO v_total_count
    FROM socio_meses sm
    WHERE (p_meses_minimo IS NULL
           OR (p_meses_exacto = TRUE AND sm.meses_impagos = p_meses_minimo)
           OR (p_meses_exacto = FALSE AND sm.meses_impagos >= p_meses_minimo));

    RETURN QUERY
    WITH socio_meses AS (
        SELECT
            s.id,
            s.apellido as s_apellido,
            s.nombre as s_nombre,
            s.grupo as s_grupo,
            s.telefono as s_telefono,
            s.email as s_email,
            s.tarjeta_id as s_tarjeta_id,
            s.residente as s_residente,
            COALESCE(SUM(cc.importe - COALESCE(cc.cancelado, 0)), 0) as saldo,
            COALESCE(
                SUM(
                    CASE
                        WHEN cc.tipo_comprobante = 'RDA' THEN cc.importe - COALESCE(cc.cancelado, 0)
                        ELSE 0
                    END
                ),
                0
            ) as rda_pendiente,
            COUNT(CASE WHEN cc.importe > COALESCE(cc.cancelado, 0) THEN 1 END) as meses_impagos
        FROM socios s
        INNER JOIN grupos_agrupados ga ON ga.codigo = s.grupo
        LEFT JOIN cuentas_corrientes cc ON cc.socio_id = s.id
        WHERE s.activo = TRUE
          AND (p_solo_activos = FALSE OR ga.activo = TRUE)
          AND (p_tarjeta_id IS NULL OR s.tarjeta_id = p_tarjeta_id)
          AND (p_solo_residentes = FALSE OR s.residente = TRUE)
        GROUP BY s.id, s.apellido, s.nombre, s.grupo, s.telefono, s.email, s.tarjeta_id, s.residente
    )
    SELECT
        sm.id::INTEGER as socio_id,
        sm.s_apellido::VARCHAR(50) as apellido,
        sm.s_nombre::VARCHAR(50) as nombre,
        sm.s_grupo::CHAR(1) as grupo,
        sm.saldo::NUMERIC as saldo,
        sm.rda_pendiente::NUMERIC as rda_pendiente,
        sm.meses_impagos::BIGINT as meses_impagos,
        sm.s_telefono::VARCHAR(50) as telefono,
        sm.s_email::VARCHAR(100) as email,
        sm.s_tarjeta_id::INTEGER as tarjeta_id,
        sm.s_residente::BOOLEAN as residente,
        v_total_count as total_count
    FROM socio_meses sm
    WHERE (p_meses_minimo IS NULL
           OR (p_meses_exacto = TRUE AND sm.meses_impagos = p_meses_minimo)
           OR (p_meses_exacto = FALSE AND sm.meses_impagos >= p_meses_minimo))
    ORDER BY sm.s_apellido, sm.s_nombre
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE;

-- Comentario de la función
COMMENT ON FUNCTION obtener_resumen_cuentas_corrientes IS
'Obtiene un resumen de las cuentas corrientes de los socios.
Parámetros:
  - p_limit: límite de registros (NULL = todos)
  - p_offset: offset para paginación
  - p_solo_activos: si TRUE filtra solo grupos con activo=true en grupos_agrupados
  - p_meses_minimo: filtrar por cantidad de meses impagos (NULL = sin filtro)
  - p_meses_exacto: si TRUE busca exactamente p_meses_minimo, si FALSE busca >= p_meses_minimo
  - p_tarjeta_id: filtrar por tarjeta de débito automático (NULL = todas)
  - p_solo_residentes: si TRUE filtra solo socios residentes
Retorna: socio_id, apellido, nombre, grupo, saldo, rda_pendiente, meses_impagos, teléfono, email, tarjeta_id, residente.
Optimizada para procesar en el servidor.';
