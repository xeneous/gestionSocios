-- ============================================================================
-- SISTEMA DE TRAZABILIDAD CONTABLE
-- ============================================================================
-- Estas tablas permiten trackear todas las operaciones contables y sus
-- relaciones con transacciones, valores de tesorería y asientos.
-- Soporta: cobranzas, facturas, débitos automáticos, y cualquier operación futura.
-- ============================================================================

-- ============================================================================
-- TABLA MAESTRA: operaciones_contables
-- ============================================================================
-- Registra todas las operaciones que generan movimientos contables
CREATE TABLE IF NOT EXISTS public.operaciones_contables (
  id BIGSERIAL PRIMARY KEY,

  -- Tipo de operación
  tipo_operacion VARCHAR(50) NOT NULL,
  -- Valores posibles:
  --   'COBRANZA_SOCIO'        - Recibo de cobranza a socio
  --   'COBRANZA_SPONSOR'      - Recibo de cobranza a sponsor
  --   'COBRANZA_PROFESIONAL'  - Recibo de cobranza a profesional
  --   'FACTURA_COMPRA'        - Factura de compra (proveedor)
  --   'FACTURA_VENTA'         - Factura de venta (cliente)
  --   'DEBITO_AUTOMATICO'     - Presentación de débito automático
  --   'NOTA_CREDITO'          - Nota de crédito
  --   'NOTA_DEBITO'           - Nota de débito
  --   (extensible a futuro)

  -- Comprobante
  numero_comprobante INTEGER, -- Número de recibo, factura, etc.
  fecha DATE NOT NULL,

  -- Entidad relacionada
  entidad_tipo VARCHAR(20), -- 'SOCIO', 'SPONSOR', 'PROFESIONAL', 'PROVEEDOR', 'CLIENTE'
  entidad_id INTEGER,       -- ID de la entidad

  -- Montos
  total NUMERIC(10,2) NOT NULL,

  -- Vinculación con asiento contable
  asiento_numero INTEGER,   -- Número del asiento generado
  asiento_anio_mes INTEGER, -- YYYYMM del asiento
  asiento_tipo INTEGER,     -- Tipo de asiento (0-4)

  -- Metadatos
  observaciones TEXT,
  operador_id INTEGER,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  -- Constraints
  CONSTRAINT operaciones_contables_total_positivo CHECK (total > 0)
);

-- Índices para búsquedas frecuentes
CREATE INDEX IF NOT EXISTS idx_operaciones_tipo
  ON public.operaciones_contables(tipo_operacion);

CREATE INDEX IF NOT EXISTS idx_operaciones_entidad
  ON public.operaciones_contables(entidad_tipo, entidad_id);

CREATE INDEX IF NOT EXISTS idx_operaciones_fecha
  ON public.operaciones_contables(fecha);

CREATE INDEX IF NOT EXISTS idx_operaciones_comprobante
  ON public.operaciones_contables(tipo_operacion, numero_comprobante);

CREATE INDEX IF NOT EXISTS idx_operaciones_asiento
  ON public.operaciones_contables(asiento_numero, asiento_anio_mes, asiento_tipo);

-- Comentario
COMMENT ON TABLE public.operaciones_contables IS
'Tabla maestra de trazabilidad contable. Registra todas las operaciones que generan movimientos contables (cobranzas, facturas, débitos, etc.)';

-- ============================================================================
-- TABLA DETALLE: operaciones_detalle_cuentas_corrientes
-- ============================================================================
-- Vincula una operación con las transacciones de cuenta corriente que afecta
-- CRÍTICO: Permite trackear pagos parciales y múltiples pagos a una misma factura
CREATE TABLE IF NOT EXISTS public.operaciones_detalle_cuentas_corrientes (
  id BIGSERIAL PRIMARY KEY,

  operacion_id BIGINT NOT NULL REFERENCES public.operaciones_contables(id) ON DELETE CASCADE,
  idtransaccion BIGINT NOT NULL REFERENCES public.cuentas_corrientes(idtransaccion),
  monto NUMERIC(10,2) NOT NULL, -- Monto específico pagado/aplicado a esta transacción

  created_at TIMESTAMP DEFAULT NOW(),

  -- Constraints
  CONSTRAINT operaciones_detalle_cc_monto_positivo CHECK (monto > 0)
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_operaciones_detalle_cc_operacion
  ON public.operaciones_detalle_cuentas_corrientes(operacion_id);

CREATE INDEX IF NOT EXISTS idx_operaciones_detalle_cc_transaccion
  ON public.operaciones_detalle_cuentas_corrientes(idtransaccion);

-- Comentario
COMMENT ON TABLE public.operaciones_detalle_cuentas_corrientes IS
'Detalle de transacciones de cuenta corriente afectadas por cada operación. Permite trackear pagos parciales y múltiples pagos.';

-- ============================================================================
-- TABLA DETALLE: operaciones_detalle_valores_tesoreria
-- ============================================================================
-- Vincula una operación con los valores de tesorería (formas de pago) utilizados
CREATE TABLE IF NOT EXISTS public.operaciones_detalle_valores_tesoreria (
  id BIGSERIAL PRIMARY KEY,

  operacion_id BIGINT NOT NULL REFERENCES public.operaciones_contables(id) ON DELETE CASCADE,
  valor_tesoreria_id INTEGER NOT NULL REFERENCES public.valores_tesoreria(id),

  created_at TIMESTAMP DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_operaciones_detalle_vt_operacion
  ON public.operaciones_detalle_valores_tesoreria(operacion_id);

CREATE INDEX IF NOT EXISTS idx_operaciones_detalle_vt_valor
  ON public.operaciones_detalle_valores_tesoreria(valor_tesoreria_id);

-- Comentario
COMMENT ON TABLE public.operaciones_detalle_valores_tesoreria IS
'Vincula operaciones con valores de tesorería (formas de pago: efectivo, cheques, transferencias, etc.)';

-- ============================================================================
-- RLS (Row Level Security) - DESHABILITADO POR AHORA
-- ============================================================================
-- Estas tablas heredan la seguridad de las tablas relacionadas
-- Si es necesario, se puede habilitar RLS más adelante

-- ============================================================================
-- CONSULTAS ÚTILES PARA AUDITORÍA Y REPORTES
-- ============================================================================

-- Ver todas las operaciones de un socio
-- SELECT * FROM operaciones_contables
-- WHERE entidad_tipo = 'SOCIO' AND entidad_id = 123
-- ORDER BY fecha DESC;

-- Ver todos los recibos que pagaron una factura específica (pagos parciales)
-- SELECT
--   oc.numero_comprobante AS numero_recibo,
--   oc.fecha,
--   odc.monto AS monto_pagado
-- FROM operaciones_detalle_cuentas_corrientes odc
-- JOIN operaciones_contables oc ON odc.operacion_id = oc.id
-- WHERE odc.idtransaccion = 123
-- ORDER BY oc.fecha;

-- Calcular saldo pendiente de una transacción
-- SELECT
--   cc.importe AS total,
--   COALESCE(SUM(odc.monto), 0) AS pagado,
--   cc.importe - COALESCE(SUM(odc.monto), 0) AS pendiente
-- FROM cuentas_corrientes cc
-- LEFT JOIN operaciones_detalle_cuentas_corrientes odc
--   ON cc.idtransaccion = odc.idtransaccion
-- WHERE cc.idtransaccion = 123
-- GROUP BY cc.idtransaccion, cc.importe;
