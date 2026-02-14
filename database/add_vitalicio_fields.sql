-- ============================================================================
-- Agregar campos para socios Vitalicios (grupo V)
-- 1. paga_seguro_mp: si paga seguro de Mala Praxis, se cobra CS a tarifa residente
-- 2. ultima_categoria: qué grupo tenía antes de pasar a Vitalicio
-- ============================================================================

-- Campo booleano: Paga Seguro MP?
ALTER TABLE public.socios
ADD COLUMN IF NOT EXISTS paga_seguro_mp BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN public.socios.paga_seguro_mp
IS 'Indica si el socio vitalicio paga seguro de Mala Praxis. Si true, se le cobra CS a tarifa de residente.';

-- Campo texto: Ultima Categoría (antes de ser Vitalicio)
ALTER TABLE public.socios
ADD COLUMN IF NOT EXISTS ultima_categoria VARCHAR(10);

COMMENT ON COLUMN public.socios.ultima_categoria
IS 'Código del grupo/categoría que tenía el socio antes de pasar a Vitalicio (ej: A, T, H).';
