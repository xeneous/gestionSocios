-- ============================================================================
-- AUDITORÍA DE COMPROBANTES ELIMINADOS
-- Incluye: tabla de auditoría + funciones atómicas para sponsors y proveedores
-- ============================================================================

-- ============================================================================
-- TABLA DE AUDITORÍA
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.comprobantes_eliminados (
  id                   SERIAL PRIMARY KEY,
  modulo               VARCHAR(20)   NOT NULL,      -- 'SPONSOR' | 'PROVEEDOR'
  id_transaccion_orig  INTEGER       NOT NULL,
  nro_comprobante      TEXT,
  entidad_id           INTEGER,
  fecha_comprobante    DATE,
  total_importe        NUMERIC(18,2),
  motivo               TEXT          NOT NULL,
  fecha_eliminacion    TIMESTAMPTZ   DEFAULT NOW(),
  header_json          JSONB,
  items_json           JSONB,
  asientos_json        JSONB
);

CREATE INDEX IF NOT EXISTS idx_comp_eliminados_modulo
  ON public.comprobantes_eliminados(modulo);

CREATE INDEX IF NOT EXISTS idx_comp_eliminados_entidad
  ON public.comprobantes_eliminados(modulo, entidad_id);

CREATE INDEX IF NOT EXISTS idx_comp_eliminados_fecha
  ON public.comprobantes_eliminados(fecha_eliminacion DESC);

COMMENT ON TABLE public.comprobantes_eliminados IS
  'Auditoría de comprobantes dados de baja. Snapshot completo de header, items y asientos.';

-- ============================================================================
-- FUNCIÓN: eliminar_comprobante_venta  (Sponsors)
-- ============================================================================
-- Flujo atómico:
--   1. Verifica existencia del comprobante
--   2. Bloquea si tiene cancelado > 0 o notas_imputacion
--   3. Captura snapshot: header + items + asientos
--   4. Inserta en comprobantes_eliminados
--   5. Elimina asiento contable (CASCADE elimina asientos_items)
--   6. Elimina items y header del comprobante
-- ============================================================================
CREATE OR REPLACE FUNCTION public.eliminar_comprobante_venta(
  p_id_transaccion INTEGER,
  p_motivo         TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_header      RECORD;
  v_items_json  JSONB;
  v_asientos_json JSONB;
  v_nro_comp    TEXT;
BEGIN
  -- 1. Verificar existencia
  SELECT * INTO v_header
  FROM public.ven_cli_header
  WHERE id_transaccion = p_id_transaccion;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Comprobante no encontrado (id_transaccion: %)', p_id_transaccion;
  END IF;

  v_nro_comp := TRIM(COALESCE(v_header.nro_comprobante, ''));

  -- 2. Bloquear si tiene pagos aplicados
  IF v_header.cancelado > 0 THEN
    RAISE EXCEPTION 'No se puede dar de baja un comprobante cancelado total o parcialmente';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.notas_imputacion
    WHERE id_transaccion = p_id_transaccion
  ) THEN
    RAISE EXCEPTION 'No se puede dar de baja un comprobante con cobros aplicados';
  END IF;

  -- 3. Snapshot items
  SELECT COALESCE(jsonb_agg(row_to_json(i)::JSONB), '[]'::JSONB)
  INTO v_items_json
  FROM public.ven_cli_items i
  WHERE i.id_transaccion = p_id_transaccion;

  -- 4. Snapshot asientos (tipo_asiento = 4 = ventas)
  IF v_nro_comp != '' THEN
    SELECT jsonb_build_object(
      'headers', COALESCE((
        SELECT jsonb_agg(row_to_json(h)::JSONB)
        FROM public.asientos_header h
        WHERE h.tipo_asiento = 4
          AND h.anio_mes = v_header.anio_mes
          AND h.detalle LIKE '%' || v_nro_comp || '%'
      ), '[]'::JSONB),
      'items', COALESCE((
        SELECT jsonb_agg(row_to_json(ai)::JSONB)
        FROM public.asientos_items ai
        WHERE ai.tipo_asiento = 4
          AND ai.anio_mes = v_header.anio_mes
          AND ai.asiento IN (
            SELECT h2.asiento FROM public.asientos_header h2
            WHERE h2.tipo_asiento = 4
              AND h2.anio_mes = v_header.anio_mes
              AND h2.detalle LIKE '%' || v_nro_comp || '%'
          )
      ), '[]'::JSONB)
    ) INTO v_asientos_json;
  ELSE
    v_asientos_json := '{}'::JSONB;
  END IF;

  -- 5. Guardar en auditoría
  INSERT INTO public.comprobantes_eliminados (
    modulo, id_transaccion_orig, nro_comprobante, entidad_id,
    fecha_comprobante, total_importe, motivo,
    header_json, items_json, asientos_json
  ) VALUES (
    'SPONSOR', p_id_transaccion, v_header.nro_comprobante, v_header.cliente,
    v_header.fecha, v_header.total_importe, p_motivo,
    row_to_json(v_header)::JSONB, v_items_json, v_asientos_json
  );

  -- 6. Eliminar asiento contable (CASCADE elimina asientos_items)
  IF v_nro_comp != '' THEN
    DELETE FROM public.asientos_header
    WHERE tipo_asiento = 4
      AND anio_mes = v_header.anio_mes
      AND detalle LIKE '%' || v_nro_comp || '%';
  END IF;

  -- 7. Eliminar items
  DELETE FROM public.ven_cli_items
  WHERE id_transaccion = p_id_transaccion;

  -- 8. Eliminar header
  DELETE FROM public.ven_cli_header
  WHERE id_transaccion = p_id_transaccion;

END;
$$;

COMMENT ON FUNCTION public.eliminar_comprobante_venta IS
  'Elimina un comprobante de sponsor de forma atómica. '
  'Bloquea si tiene cobros aplicados. '
  'Guarda snapshot completo (header + items + asientos) en comprobantes_eliminados.';

-- ============================================================================
-- FUNCIÓN: eliminar_comprobante_compra  (Proveedores)
-- ============================================================================
-- Reemplaza la eliminación directa que hacía Flutter sin trazabilidad.
-- Igual flujo que eliminar_comprobante_venta pero sobre comp_prov_*.
-- tipo_asiento = 3 = compras
-- ============================================================================
CREATE OR REPLACE FUNCTION public.eliminar_comprobante_compra(
  p_id_transaccion INTEGER,
  p_motivo         TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_header        RECORD;
  v_items_json    JSONB;
  v_asientos_json JSONB;
  v_nro_comp      TEXT;
  v_ops           TEXT;
BEGIN
  -- 1. Verificar existencia
  SELECT * INTO v_header
  FROM public.comp_prov_header
  WHERE id_transaccion = p_id_transaccion;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Comprobante no encontrado (id_transaccion: %)', p_id_transaccion;
  END IF;

  v_nro_comp := TRIM(COALESCE(v_header.nro_comprobante, ''));

  -- 2. Bloquear si tiene OPs aplicadas
  IF v_header.cancelado > 0 THEN
    RAISE EXCEPTION 'No se puede dar de baja un comprobante cancelado total o parcialmente';
  END IF;

  SELECT STRING_AGG('OP #' || id_operacion::TEXT, ', ')
  INTO v_ops
  FROM public.notas_imputacion
  WHERE id_transaccion = p_id_transaccion;

  IF v_ops IS NOT NULL THEN
    RAISE EXCEPTION 'La factura tiene pagos aplicados (%). Elimine primero esas Órdenes de Pago.', v_ops;
  END IF;

  -- 3. Snapshot items
  SELECT COALESCE(jsonb_agg(row_to_json(i)::JSONB), '[]'::JSONB)
  INTO v_items_json
  FROM public.comp_prov_items i
  WHERE i.id_transaccion = p_id_transaccion;

  -- 4. Snapshot asientos (tipo_asiento = 3 = compras)
  IF v_nro_comp != '' THEN
    SELECT jsonb_build_object(
      'headers', COALESCE((
        SELECT jsonb_agg(row_to_json(h)::JSONB)
        FROM public.asientos_header h
        WHERE h.tipo_asiento = 3
          AND h.anio_mes = v_header.anio_mes
          AND h.detalle LIKE '%' || v_nro_comp || '%'
      ), '[]'::JSONB),
      'items', COALESCE((
        SELECT jsonb_agg(row_to_json(ai)::JSONB)
        FROM public.asientos_items ai
        WHERE ai.tipo_asiento = 3
          AND ai.anio_mes = v_header.anio_mes
          AND ai.asiento IN (
            SELECT h2.asiento FROM public.asientos_header h2
            WHERE h2.tipo_asiento = 3
              AND h2.anio_mes = v_header.anio_mes
              AND h2.detalle LIKE '%' || v_nro_comp || '%'
          )
      ), '[]'::JSONB)
    ) INTO v_asientos_json;
  ELSE
    v_asientos_json := '{}'::JSONB;
  END IF;

  -- 5. Guardar en auditoría
  INSERT INTO public.comprobantes_eliminados (
    modulo, id_transaccion_orig, nro_comprobante, entidad_id,
    fecha_comprobante, total_importe, motivo,
    header_json, items_json, asientos_json
  ) VALUES (
    'PROVEEDOR', p_id_transaccion, v_header.nro_comprobante, v_header.proveedor,
    v_header.fecha, v_header.total_importe, p_motivo,
    row_to_json(v_header)::JSONB, v_items_json, v_asientos_json
  );

  -- 6. Eliminar asiento contable
  IF v_nro_comp != '' THEN
    DELETE FROM public.asientos_header
    WHERE tipo_asiento = 3
      AND anio_mes = v_header.anio_mes
      AND detalle LIKE '%' || v_nro_comp || '%';
  END IF;

  -- 7. Eliminar items
  DELETE FROM public.comp_prov_items
  WHERE id_transaccion = p_id_transaccion;

  -- 8. Eliminar header
  DELETE FROM public.comp_prov_header
  WHERE id_transaccion = p_id_transaccion;

END;
$$;

COMMENT ON FUNCTION public.eliminar_comprobante_compra IS
  'Elimina un comprobante de proveedor de forma atómica. '
  'Bloquea si tiene OPs aplicadas. '
  'Guarda snapshot completo (header + items + asientos) en comprobantes_eliminados.';
