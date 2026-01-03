-- ============================================================================
-- FIX RLS PARA VALORES_TESORERIA
-- Agregar políticas de INSERT y UPDATE para usuarios autenticados
-- ============================================================================

-- Política para INSERT
DROP POLICY IF EXISTS "Permitir insert a usuarios autenticados" ON public.valores_tesoreria;
CREATE POLICY "Permitir insert a usuarios autenticados"
  ON public.valores_tesoreria
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Política para UPDATE
DROP POLICY IF EXISTS "Permitir update a usuarios autenticados" ON public.valores_tesoreria;
CREATE POLICY "Permitir update a usuarios autenticados"
  ON public.valores_tesoreria
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Política para DELETE (opcional, por si acaso)
DROP POLICY IF EXISTS "Permitir delete a usuarios autenticados" ON public.valores_tesoreria;
CREATE POLICY "Permitir delete a usuarios autenticados"
  ON public.valores_tesoreria
  FOR DELETE
  TO authenticated
  USING (true);
