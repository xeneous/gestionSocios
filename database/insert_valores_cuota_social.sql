-- ============================================================================
-- INSERTAR VALORES DE CUOTA SOCIAL (2024-2026)
-- ============================================================================
-- IMPORTANTE: Ajustar los valores según las resoluciones reales de SAO
-- Estos son valores de ejemplo que deben ser configurados por el administrador
-- ============================================================================

-- Limpiar valores existentes (CUIDADO: solo para testing inicial)
-- TRUNCATE public.valores_cuota_social RESTART IDENTITY CASCADE;

-- ============================================================================
-- AÑO 2024 - Valores por trimestre
-- ============================================================================

INSERT INTO public.valores_cuota_social
  (anio_mes_inicio, anio_mes_cierre, valor_residente, valor_titular)
VALUES
  -- Trimestre 1: Enero-Marzo 2024
  (202401, 202403, 15000.00, 25000.00),

  -- Trimestre 2: Abril-Junio 2024
  (202404, 202406, 15500.00, 25500.00),

  -- Trimestre 3: Julio-Septiembre 2024
  (202407, 202409, 16000.00, 26000.00),

  -- Trimestre 4: Octubre-Diciembre 2024
  (202410, 202412, 16500.00, 26500.00);

-- ============================================================================
-- AÑO 2025 - Valores por trimestre
-- ============================================================================

INSERT INTO public.valores_cuota_social
  (anio_mes_inicio, anio_mes_cierre, valor_residente, valor_titular)
VALUES
  -- Trimestre 1: Enero-Marzo 2025
  (202501, 202503, 17000.00, 27000.00),

  -- Trimestre 2: Abril-Junio 2025
  (202504, 202506, 17500.00, 27500.00),

  -- Trimestre 3: Julio-Septiembre 2025
  (202507, 202509, 18000.00, 28000.00),

  -- Trimestre 4: Octubre-Diciembre 2025
  (202510, 202512, 18500.00, 28500.00);

-- ============================================================================
-- AÑO 2026 - Valores por trimestre
-- ============================================================================

INSERT INTO public.valores_cuota_social
  (anio_mes_inicio, anio_mes_cierre, valor_residente, valor_titular)
VALUES
  -- Trimestre 1: Enero-Marzo 2026
  (202601, 202603, 19000.00, 29000.00),

  -- Trimestre 2: Abril-Junio 2026
  (202604, 202606, 19500.00, 29500.00),

  -- Trimestre 3: Julio-Septiembre 2026
  (202607, 202609, 20000.00, 30000.00),

  -- Trimestre 4: Octubre-Diciembre 2026
  (202610, 202612, 20500.00, 30500.00);

-- ============================================================================
-- VERIFICACIÓN
-- ============================================================================

-- Ver todos los valores cargados
SELECT
  id,
  anio_mes_inicio,
  anio_mes_cierre,
  valor_residente,
  valor_titular,
  created_at
FROM public.valores_cuota_social
ORDER BY anio_mes_inicio;

-- Probar la función con algunos meses
SELECT
  202401 as periodo,
  public.get_valor_cuota_social(202401, true) as residente,
  public.get_valor_cuota_social(202401, false) as titular;

SELECT
  202605 as periodo,
  public.get_valor_cuota_social(202605, true) as residente,
  public.get_valor_cuota_social(202605, false) as titular;

-- ============================================================================
-- NOTAS IMPORTANTES
-- ============================================================================
-- 1. Los valores están organizados por TRIMESTRES (3 meses)
-- 2. Un mes puede estar en UN SOLO período (no puede haber solapamiento)
-- 3. Para agregar nuevos valores, usar INSERT con fechas posteriores
-- 4. Para modificar valores existentes, usar UPDATE por id
-- 5. NUNCA eliminar valores históricos que ya fueron usados para facturar
-- ============================================================================
