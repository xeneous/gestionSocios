-- Índices para mejorar performance de búsqueda en asientos_header
-- El patrón de query es: WHERE tipo_asiento = X AND fecha BETWEEN a AND b
-- ORDER BY fecha DESC, asiento DESC

-- Índice compuesto principal: tipo_asiento + fecha
-- Cubre el caso más común: filtrar por tipo y rango de fechas
CREATE INDEX IF NOT EXISTS idx_asientos_header_tipo_fecha
  ON public.asientos_header (tipo_asiento, fecha DESC);

-- Índice solo en fecha: cubre búsqueda por rango de fechas sin filtro de tipo
CREATE INDEX IF NOT EXISTS idx_asientos_header_fecha
  ON public.asientos_header (fecha DESC);

-- Índice compuesto tipo + asiento: cubre el filtro por rango de número de asiento
CREATE INDEX IF NOT EXISTS idx_asientos_header_tipo_asiento_num
  ON public.asientos_header (tipo_asiento, asiento DESC);

-- Índice en asientos_items para la query batch (inFilter asiento + eq tipo_asiento)
CREATE INDEX IF NOT EXISTS idx_asientos_items_tipo_asiento
  ON public.asientos_items (tipo_asiento, asiento);

-- Verificar índices creados
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename IN ('asientos_header', 'asientos_items')
ORDER BY tablename, indexname;
