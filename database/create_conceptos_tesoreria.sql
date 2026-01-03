-- Crear tabla conceptos_tesoreria para formas de pago y conceptos de tesorería
-- Esta tabla se usará en el módulo de cobranzas

CREATE TABLE IF NOT EXISTS public.conceptos_tesoreria (
  id INTEGER PRIMARY KEY,
  descripcion VARCHAR(255),
  imputacion_contable VARCHAR(50),
  modalidad INTEGER DEFAULT 0,
  ci CHAR(1) DEFAULT 'N',
  ce CHAR(1) DEFAULT 'N',
  unificador INTEGER,
  mostrador INTEGER DEFAULT 0,
  moneda_extranjera INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_conceptos_tesoreria_descripcion ON public.conceptos_tesoreria(descripcion);
CREATE INDEX IF NOT EXISTS idx_conceptos_tesoreria_ci ON public.conceptos_tesoreria(ci);
CREATE INDEX IF NOT EXISTS idx_conceptos_tesoreria_ce ON public.conceptos_tesoreria(ce);

-- Comentarios
COMMENT ON TABLE public.conceptos_tesoreria IS 'Conceptos de tesorería - formas de pago para cobranzas';
COMMENT ON COLUMN public.conceptos_tesoreria.id IS 'ID del concepto (idConcepto_Tesoreria)';
COMMENT ON COLUMN public.conceptos_tesoreria.descripcion IS 'Descripción del concepto/forma de pago';
COMMENT ON COLUMN public.conceptos_tesoreria.imputacion_contable IS 'Cuenta contable para imputación';
COMMENT ON COLUMN public.conceptos_tesoreria.modalidad IS 'Modalidad del concepto (0,2,etc.)';
COMMENT ON COLUMN public.conceptos_tesoreria.ci IS 'Cartera de Ingreso (S/N)';
COMMENT ON COLUMN public.conceptos_tesoreria.ce IS 'Cartera de Egreso (S/N)';
COMMENT ON COLUMN public.conceptos_tesoreria.unificador IS 'ID unificador para agrupar conceptos';
COMMENT ON COLUMN public.conceptos_tesoreria.mostrador IS 'Disponible en mostrador (0/1)';
COMMENT ON COLUMN public.conceptos_tesoreria.moneda_extranjera IS 'Acepta moneda extranjera (0/1)';

-- RLS (Row Level Security) - permitir lectura a usuarios autenticados
ALTER TABLE public.conceptos_tesoreria ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir lectura a todos los usuarios autenticados"
  ON public.conceptos_tesoreria
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.conceptos_tesoreria
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
