-- ============================================================================
-- CREACIÓN DE TABLAS PARA MÓDULO DE TESORERÍA/COBRANZAS
-- ============================================================================

-- ============================================================================
-- 1. TABLA CONCEPTOS_TESORERIA (Formas de pago)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.conceptos_tesoreria (
  id INTEGER PRIMARY KEY,
  descripcion VARCHAR(255),
  imputacion_contable VARCHAR(50),
  modalidad INTEGER DEFAULT 0,
  ci VARCHAR(1) DEFAULT 'N',
  ce VARCHAR(1) DEFAULT 'N',
  unificador INTEGER,
  mostrador INTEGER DEFAULT 0,
  moneda_extranjera INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para conceptos_tesoreria
CREATE INDEX IF NOT EXISTS idx_conceptos_tesoreria_descripcion ON public.conceptos_tesoreria(descripcion);
CREATE INDEX IF NOT EXISTS idx_conceptos_tesoreria_ci ON public.conceptos_tesoreria(ci);
CREATE INDEX IF NOT EXISTS idx_conceptos_tesoreria_ce ON public.conceptos_tesoreria(ce);

-- Comentarios para conceptos_tesoreria
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

-- RLS para conceptos_tesoreria
ALTER TABLE public.conceptos_tesoreria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir lectura a todos los usuarios autenticados" ON public.conceptos_tesoreria;
CREATE POLICY "Permitir lectura a todos los usuarios autenticados"
  ON public.conceptos_tesoreria
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.conceptos_tesoreria;
CREATE POLICY "Permitir todo a service_role"
  ON public.conceptos_tesoreria
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 2. TABLA VALORES_TESORERIA (Movimientos de valores/pagos)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.valores_tesoreria (
  id INTEGER PRIMARY KEY,
  idtransaccion_origen INTEGER,
  tipo_movimiento INTEGER,
  idconcepto_tesoreria INTEGER REFERENCES public.conceptos_tesoreria(id),
  fecha_emision TIMESTAMPTZ,
  vencimiento TIMESTAMPTZ,
  banco VARCHAR(255),
  cuenta INTEGER,
  sucursal INTEGER,
  numero BIGINT,
  numero_interno INTEGER,
  firma VARCHAR(60),
  importe NUMERIC(18, 2),
  cancelado NUMERIC(18, 2),
  idoperador INTEGER,
  observaciones VARCHAR(255),
  locked BOOLEAN DEFAULT false,
  cobrador INTEGER,
  idop_cobrador INTEGER,
  corregido VARCHAR(1),
  tipocambio NUMERIC(18, 2),
  base NUMERIC(18, 2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para valores_tesoreria
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_idtransaccion_origen ON public.valores_tesoreria(idtransaccion_origen);
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_idconcepto ON public.valores_tesoreria(idconcepto_tesoreria);
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_fecha_emision ON public.valores_tesoreria(fecha_emision);
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_vencimiento ON public.valores_tesoreria(vencimiento);
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_numero ON public.valores_tesoreria(numero);

-- Comentarios para valores_tesoreria
COMMENT ON TABLE public.valores_tesoreria IS 'Movimientos de valores de tesorería - formas de pago y sus importes';
COMMENT ON COLUMN public.valores_tesoreria.id IS 'ID único del valor (idTransaccion)';
COMMENT ON COLUMN public.valores_tesoreria.idtransaccion_origen IS 'ID de la transacción origen (FK a cuentas_corrientes u otra tabla)';
COMMENT ON COLUMN public.valores_tesoreria.tipo_movimiento IS 'Tipo de movimiento del valor';
COMMENT ON COLUMN public.valores_tesoreria.idconcepto_tesoreria IS 'FK al concepto/forma de pago';
COMMENT ON COLUMN public.valores_tesoreria.fecha_emision IS 'Fecha de emisión del valor';
COMMENT ON COLUMN public.valores_tesoreria.vencimiento IS 'Fecha de vencimiento del valor';
COMMENT ON COLUMN public.valores_tesoreria.banco IS 'Banco (para cheques/transferencias)';
COMMENT ON COLUMN public.valores_tesoreria.cuenta IS 'Número de cuenta';
COMMENT ON COLUMN public.valores_tesoreria.sucursal IS 'Sucursal del banco';
COMMENT ON COLUMN public.valores_tesoreria.numero IS 'Número del cheque/comprobante';
COMMENT ON COLUMN public.valores_tesoreria.numero_interno IS 'Número interno de control';
COMMENT ON COLUMN public.valores_tesoreria.firma IS 'Firma del titular';
COMMENT ON COLUMN public.valores_tesoreria.importe IS 'Importe del valor';
COMMENT ON COLUMN public.valores_tesoreria.cancelado IS 'Monto cancelado del valor';
COMMENT ON COLUMN public.valores_tesoreria.idoperador IS 'ID del operador que registró';
COMMENT ON COLUMN public.valores_tesoreria.observaciones IS 'Observaciones del valor';
COMMENT ON COLUMN public.valores_tesoreria.locked IS 'Indica si el valor está bloqueado';
COMMENT ON COLUMN public.valores_tesoreria.cobrador IS 'ID del cobrador';
COMMENT ON COLUMN public.valores_tesoreria.idop_cobrador IS 'ID operación cobrador';
COMMENT ON COLUMN public.valores_tesoreria.corregido IS 'Marca si fue corregido';
COMMENT ON COLUMN public.valores_tesoreria.tipocambio IS 'Tipo de cambio aplicado';
COMMENT ON COLUMN public.valores_tesoreria.base IS 'Base de cálculo';

-- RLS para valores_tesoreria
ALTER TABLE public.valores_tesoreria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir lectura a todos los usuarios autenticados" ON public.valores_tesoreria;
CREATE POLICY "Permitir lectura a todos los usuarios autenticados"
  ON public.valores_tesoreria
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.valores_tesoreria;
CREATE POLICY "Permitir todo a service_role"
  ON public.valores_tesoreria
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================================
-- 3. TABLA NUMERADORES (Para generar números de recibos secuenciales)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.numeradores (
  id SERIAL PRIMARY KEY,
  tipo VARCHAR(50) NOT NULL UNIQUE,
  ultimo_numero INTEGER NOT NULL DEFAULT 0,
  prefijo VARCHAR(10),
  sufijo VARCHAR(10),
  descripcion VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para numeradores
CREATE INDEX IF NOT EXISTS idx_numeradores_tipo ON public.numeradores(tipo);

-- Comentarios para numeradores
COMMENT ON TABLE public.numeradores IS 'Numeradores secuenciales para recibos y comprobantes';
COMMENT ON COLUMN public.numeradores.tipo IS 'Tipo de numerador (ej: RECIBO, FACTURA, etc.)';
COMMENT ON COLUMN public.numeradores.ultimo_numero IS 'Último número generado';
COMMENT ON COLUMN public.numeradores.prefijo IS 'Prefijo para el número';
COMMENT ON COLUMN public.numeradores.sufijo IS 'Sufijo para el número';

-- RLS para numeradores
ALTER TABLE public.numeradores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir lectura a todos los usuarios autenticados" ON public.numeradores;
CREATE POLICY "Permitir lectura a todos los usuarios autenticados"
  ON public.numeradores
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.numeradores;
CREATE POLICY "Permitir todo a service_role"
  ON public.numeradores
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Insertar numerador inicial para recibos
INSERT INTO public.numeradores (tipo, ultimo_numero, descripcion)
VALUES ('RECIBO', 0, 'Numerador para recibos de cobranzas')
ON CONFLICT (tipo) DO NOTHING;

-- ============================================================================
-- FUNCIÓN PARA OBTENER SIGUIENTE NÚMERO
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_next_numero(p_tipo VARCHAR)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_numero INTEGER;
BEGIN
  UPDATE public.numeradores
  SET ultimo_numero = ultimo_numero + 1,
      updated_at = NOW()
  WHERE tipo = p_tipo
  RETURNING ultimo_numero INTO v_numero;

  RETURN v_numero;
END;
$$;

COMMENT ON FUNCTION public.get_next_numero IS 'Obtiene el siguiente número secuencial para un tipo de numerador';
