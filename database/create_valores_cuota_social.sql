-- ============================================================================
-- TABLA: valores_cuota_social
-- ============================================================================
-- Almacena los valores históricos de la cuota social para residentes y titulares
-- Los períodos se definen con inicio y cierre en formato YYYYMM
-- Ejemplo trimestre: anio_mes_inicio=202601, anio_mes_cierre=202603 (Ene-Mar 2026)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.valores_cuota_social (
  id SERIAL PRIMARY KEY,

  -- Período de vigencia (formato YYYYMM)
  anio_mes_inicio INTEGER NOT NULL,
  anio_mes_cierre INTEGER NOT NULL,

  -- Valores según tipo de socio
  valor_residente NUMERIC(10,2) NOT NULL,
  valor_titular NUMERIC(10,2) NOT NULL,

  -- Auditoría
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valores_cuota_anio_mes_valido CHECK (
    anio_mes_inicio >= 190001 AND anio_mes_inicio <= 999912 AND
    anio_mes_cierre >= 190001 AND anio_mes_cierre <= 999912
  ),
  CONSTRAINT valores_cuota_valores_positivos CHECK (
    valor_residente > 0 AND valor_titular > 0
  ),
  CONSTRAINT valores_cuota_rango_valido CHECK (anio_mes_cierre >= anio_mes_inicio)
);

-- Índice por período
CREATE INDEX IF NOT EXISTS idx_valores_cuota_periodo
  ON public.valores_cuota_social(anio_mes_inicio, anio_mes_cierre);

-- Comentarios
COMMENT ON TABLE public.valores_cuota_social IS
'Valores de cuota social por período. Típicamente se usan trimestres.';

COMMENT ON COLUMN public.valores_cuota_social.anio_mes_inicio IS
'Mes de inicio del período en formato YYYYMM (ej: 202601 = Enero 2026)';

COMMENT ON COLUMN public.valores_cuota_social.anio_mes_cierre IS
'Mes de cierre del período en formato YYYYMM (ej: 202603 = Marzo 2026)';

-- ============================================================================
-- FUNCIÓN: Obtener valor de cuota para un mes específico
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_valor_cuota_social(
  p_anio_mes INTEGER,
  p_es_residente BOOLEAN
)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_valor NUMERIC;
BEGIN
  -- Buscar el valor vigente para el mes solicitado
  SELECT
    CASE WHEN p_es_residente THEN valor_residente ELSE valor_titular END
  INTO v_valor
  FROM public.valores_cuota_social
  WHERE anio_mes_inicio <= p_anio_mes
    AND anio_mes_cierre >= p_anio_mes
  LIMIT 1;

  -- Si no hay valor configurado, lanzar error
  IF v_valor IS NULL THEN
    RAISE EXCEPTION 'No hay valor de cuota social configurado para el período %',
      p_anio_mes;
  END IF;

  RETURN v_valor;
END;
$$;

COMMENT ON FUNCTION public.get_valor_cuota_social IS
'Obtiene el valor de cuota social vigente para un mes (YYYYMM) y tipo de socio.';

-- ============================================================================
-- NOTA IMPORTANTE: VALORES DE CUOTA SOCIAL
-- ============================================================================
-- Los valores de cuota social NO se cargan automáticamente.
-- Deben ser configurados manualmente por el administrador según las
-- resoluciones de la SAO, ya que afectan a TODOS los socios.
--
-- Ejemplo de carga por trimestres (2026):
--
-- INSERT INTO public.valores_cuota_social (anio_mes_inicio, anio_mes_cierre, valor_residente, valor_titular)
-- VALUES
--   (202601, 202603, 15000.00, 25000.00),  -- Ene-Mar 2026
--   (202604, 202606, 16000.00, 26000.00),  -- Abr-Jun 2026
--   (202607, 202609, 17000.00, 27000.00),  -- Jul-Sep 2026
--   (202610, 202612, 18000.00, 28000.00);  -- Oct-Dic 2026
--
-- Para probar la función:
-- SELECT public.get_valor_cuota_social(202601, true);   -- Residente Enero 2026
-- SELECT public.get_valor_cuota_social(202605, false);  -- Titular Mayo 2026
