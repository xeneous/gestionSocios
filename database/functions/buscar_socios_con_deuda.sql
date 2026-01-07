-- Función RPC optimizada para buscar socios con deudas
-- Procesa todo en el servidor en lugar del cliente
-- Soporta paginación

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

-- Comentario de la función
COMMENT ON FUNCTION buscar_socios_con_deuda IS
'Busca socios con deudas según filtros. Optimizada para procesar en servidor.
Parámetros:
- p_meses_impagos: Cantidad de meses a filtrar
- p_solo_debito_automatico: Si TRUE, solo socios con débito automático
- p_tarjeta_id: ID de tarjeta específica (opcional)
- p_meses_o_mas: Si TRUE busca >= meses, si FALSE busca == meses exactos';
