-- Crear tabla valores_tesoreria para registrar movimientos de pagos
-- Registra los valores (formas de pago e importes) asociados a transacciones

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
  numero VARCHAR(255),
  numero_interno INTEGER,
  firma CHAR(60),
  importe NUMERIC(18, 2),
  cancelado NUMERIC(18, 2),
  idoperador INTEGER,
  observaciones VARCHAR(255),
  locked BOOLEAN DEFAULT false,
  cobrador INTEGER,
  idop_cobrador INTEGER,
  corregido CHAR(1),
  tipocambio NUMERIC(18, 2),
  base NUMERIC(18, 2),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_idtransaccion_origen ON public.valores_tesoreria(idtransaccion_origen);
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_idconcepto ON public.valores_tesoreria(idconcepto_tesoreria);
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_fecha_emision ON public.valores_tesoreria(fecha_emision);
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_vencimiento ON public.valores_tesoreria(vencimiento);
CREATE INDEX IF NOT EXISTS idx_valores_tesoreria_numero ON public.valores_tesoreria(numero);

-- Comentarios
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

-- RLS (Row Level Security)
ALTER TABLE public.valores_tesoreria ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Permitir lectura a todos los usuarios autenticados"
  ON public.valores_tesoreria
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.valores_tesoreria
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
