-- Script para desplegar las funciones RPC optimizadas
-- Ejecutar este script en Supabase SQL Editor

-- ============================================================================
-- 1. Función: buscar_socios_con_deuda
-- ============================================================================

-- Drop existing function if it exists (required when changing return type)
DROP FUNCTION IF EXISTS buscar_socios_con_deuda(integer, boolean, integer, boolean, integer, integer);
DROP FUNCTION IF EXISTS buscar_socios_con_deuda(integer, boolean, integer, boolean);

CREATE OR REPLACE FUNCTION buscar_socios_con_deuda(
    p_meses_impagos INTEGER,
    p_solo_debito_automatico BOOLEAN DEFAULT FALSE,
    p_tarjeta_id INTEGER DEFAULT NULL,
    p_meses_o_mas BOOLEAN DEFAULT TRUE,
    p_limit INTEGER DEFAULT NULL,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE(
    socio_id INTEGER,
    apellido VARCHAR(50),
    nombre VARCHAR(50),
    meses_mora BIGINT,
    importe_total NUMERIC,
    email VARCHAR(100),
    adherido_debito BOOLEAN,
    tarjeta_id INTEGER,
    detalles JSONB,
    total_count BIGINT
) AS $$
DECLARE
    v_total_count BIGINT;
BEGIN
    -- Obtener el total de registros que cumplen los criterios
    WITH deudas_count AS (
        SELECT COUNT(DISTINCT cc.socio_id) as cnt
        FROM cuentas_corrientes cc
        INNER JOIN socios s ON s.id = cc.socio_id
        WHERE
            (cc.importe - cc.cancelado) > 0
            AND (NOT p_solo_debito_automatico OR s.adherido_debito = TRUE)
            AND (p_tarjeta_id IS NULL OR s.tarjeta_id = p_tarjeta_id)
        GROUP BY cc.socio_id
        HAVING
            CASE
                WHEN p_meses_o_mas THEN COUNT(*) >= p_meses_impagos
                ELSE COUNT(*) = p_meses_impagos
            END
    )
    SELECT COALESCE(SUM(cnt), 0) INTO v_total_count FROM deudas_count;

    RETURN QUERY
    WITH deudas_por_socio AS (
        -- Agrupar las deudas por socio
        SELECT
            cc.socio_id,
            s.apellido,
            s.nombre,
            s.email,
            s.adherido_debito,
            s.tarjeta_id,
            COUNT(*) as meses_adeudados,
            SUM(cc.importe - cc.cancelado) as total_adeudado,
            -- Crear array JSON con los detalles de cada deuda
            JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'documento_numero', cc.documento_numero,
                    'importe', cc.importe - cc.cancelado,
                    'vencimiento', cc.vencimiento
                )
                ORDER BY cc.documento_numero
            ) as detalles_json
        FROM cuentas_corrientes cc
        INNER JOIN socios s ON s.id = cc.socio_id
        WHERE
            -- Solo registros con saldo pendiente
            (cc.importe - cc.cancelado) > 0
            -- Filtro de débito automático
            AND (NOT p_solo_debito_automatico OR s.adherido_debito = TRUE)
            -- Filtro de tarjeta
            AND (p_tarjeta_id IS NULL OR s.tarjeta_id = p_tarjeta_id)
        GROUP BY
            cc.socio_id,
            s.apellido,
            s.nombre,
            s.email,
            s.adherido_debito,
            s.tarjeta_id
        HAVING
            -- Aplicar filtro de meses según el flag p_meses_o_mas
            CASE
                WHEN p_meses_o_mas THEN COUNT(*) >= p_meses_impagos
                ELSE COUNT(*) = p_meses_impagos
            END
    )
    SELECT
        dps.socio_id::INTEGER,
        dps.apellido,
        dps.nombre,
        dps.meses_adeudados,
        dps.total_adeudado,
        dps.email,
        dps.adherido_debito,
        dps.tarjeta_id::INTEGER,
        dps.detalles_json as detalles,
        v_total_count as total_count
    FROM deudas_por_socio dps
    ORDER BY dps.meses_adeudados DESC, dps.apellido, dps.nombre
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql STABLE;


COMMENT ON FUNCTION buscar_socios_con_deuda IS
'Busca socios con deudas según filtros. Optimizada para procesar en servidor.
Parámetros:
- p_meses_impagos: Cantidad de meses a filtrar
- p_solo_debito_automatico: Si TRUE, solo socios con débito automático
- p_tarjeta_id: ID de tarjeta específica (opcional)
- p_meses_o_mas: Si TRUE busca >= meses, si FALSE busca == meses exactos';

-- ============================================================================
-- 2. Función: obtener_resumen_cuentas_corrientes
-- ============================================================================

-- Drop existing function if it exists (required when changing return type)
DROP FUNCTION IF EXISTS obtener_resumen_cuentas_corrientes(integer, integer);
DROP FUNCTION IF EXISTS obtener_resumen_cuentas_corrientes();

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


COMMENT ON FUNCTION obtener_resumen_cuentas_corrientes IS
'Obtiene un resumen de las cuentas corrientes de todos los socios activos (grupos A, T, H, V).
Retorna: socio_id, apellido, nombre, grupo, saldo total, RDA pendiente, teléfono, email.
Optimizada para procesar en el servidor.';

-- ============================================================================
-- Verificación de las funciones
-- ============================================================================

-- Verificar que las funciones se crearon correctamente
SELECT
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('buscar_socios_con_deuda', 'obtener_resumen_cuentas_corrientes')
ORDER BY routine_name;

-- ============================================================================
-- Ejemplos de uso
-- ============================================================================

-- Ejemplo 1: Buscar socios con 1 o más meses de deuda
-- SELECT * FROM buscar_socios_con_deuda(1, FALSE, NULL, TRUE);

-- Ejemplo 2: Buscar socios con exactamente 2 meses de deuda
-- SELECT * FROM buscar_socios_con_deuda(2, FALSE, NULL, FALSE);

-- Ejemplo 3: Buscar socios con débito automático y 3 o más meses
-- SELECT * FROM buscar_socios_con_deuda(3, TRUE, NULL, TRUE);

-- Ejemplo 4: Obtener resumen de todas las cuentas corrientes
 SELECT * FROM obtener_resumen_cuentas_corrientes();
