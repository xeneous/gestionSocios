-- ============================================================================
-- Agregar campo ACTIVO a tablas de conceptos
-- ============================================================================
-- Permite activar/desactivar conceptos sin eliminarlos
-- ============================================================================

-- Agregar campo activo a conceptos_tesoreria
ALTER TABLE public.conceptos_tesoreria
ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT true;

COMMENT ON COLUMN public.conceptos_tesoreria.activo IS 'Indica si el concepto está activo (true) o inactivo (false)';

-- Índice para búsquedas por activo
CREATE INDEX IF NOT EXISTS idx_conceptos_tesoreria_activo ON public.conceptos_tesoreria(activo);

-- Agregar campo activo a conceptos (si no existe ya)
ALTER TABLE public.conceptos
ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT true;

COMMENT ON COLUMN public.conceptos.activo IS 'Indica si el concepto está activo (true) o inactivo (false)';

-- Índice para búsquedas por activo
CREATE INDEX IF NOT EXISTS idx_conceptos_activo ON public.conceptos(activo);

-- Verificar
SELECT 'conceptos_tesoreria' as tabla, COUNT(*) as total, SUM(CASE WHEN activo THEN 1 ELSE 0 END) as activos
FROM public.conceptos_tesoreria
UNION ALL
SELECT 'conceptos' as tabla, COUNT(*) as total, SUM(CASE WHEN activo THEN 1 ELSE 0 END) as activos
FROM public.conceptos;
