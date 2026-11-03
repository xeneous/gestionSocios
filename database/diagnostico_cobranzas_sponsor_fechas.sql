-- Diagnóstico: cobranzas de sponsors - fecha cargada por el usuario vs fecha del asiento de diario.
-- Solo lectura (SELECT). Ejecutar en Supabase SQL Editor (PostgreSQL).
--
-- fecha_recibo  = operaciones_contables.fecha (la que eligió el usuario)
-- fecha_asiento = asientos_header.fecha
-- El asiento se busca de dos formas:
--   1) por el vínculo guardado en operaciones_contables (asiento_numero/anio_mes/tipo)
--   2) si no hay vínculo, por el detalle del asiento ('Recibo Cli Nro. N - ...'), tipo Ingreso (1)

SELECT
  oc.numero_comprobante                       AS nro_recibo,
  c.razon_social                              AS cliente,
  oc.total                                    AS importe,
  oc.fecha                                    AS fecha_recibo,
  a.fecha                                     AS fecha_asiento,
  (a.fecha - oc.fecha)                        AS dias_diferencia,
  a.asiento                                   AS asiento_numero,
  a.anio_mes                                  AS periodo_asiento,
  EXTRACT(YEAR FROM oc.fecha)::INT * 100
    + EXTRACT(MONTH FROM oc.fecha)::INT       AS periodo_recibo,
  a.cant_asientos,
  CASE WHEN oc.asiento_numero IS NOT NULL THEN 'POR VINCULO' ELSE 'POR DETALLE' END AS como_se_encontro,
  CASE
    WHEN a.asiento IS NULL THEN 'SIN ASIENTO'
    WHEN a.cant_asientos > 1 THEN 'VARIOS ASIENTOS (revisar)'
    WHEN a.fecha = oc.fecha THEN 'COINCIDE'
    WHEN a.anio_mes <> EXTRACT(YEAR FROM oc.fecha)::INT * 100 + EXTRACT(MONTH FROM oc.fecha)::INT
      THEN 'DISTINTO PERIODO'
    ELSE 'MISMO PERIODO, DISTINTO DIA'
  END                                         AS situacion
FROM public.operaciones_contables oc
LEFT JOIN public.clientes c
       ON c.codigo = oc.entidad_id
LEFT JOIN LATERAL (
  SELECT h.asiento, h.anio_mes, h.fecha,
         COUNT(*) OVER () AS cant_asientos
  FROM public.asientos_header h
  WHERE (
          oc.asiento_numero IS NOT NULL
          AND h.asiento      = oc.asiento_numero
          AND h.anio_mes     = oc.asiento_anio_mes
          AND h.tipo_asiento = oc.asiento_tipo
        )
     OR (
          oc.asiento_numero IS NULL
          AND h.tipo_asiento = 1
          AND h.detalle LIKE 'Recibo Cli Nro. ' || oc.numero_comprobante || ' -%'
        )
  ORDER BY h.fecha
  LIMIT 1
) a ON TRUE
WHERE oc.tipo_operacion = 'COBRANZA_SPONSOR'
ORDER BY
  CASE WHEN a.asiento IS NULL THEN 0 WHEN a.fecha = oc.fecha THEN 2 ELSE 1 END,
  oc.fecha, oc.numero_comprobante;
