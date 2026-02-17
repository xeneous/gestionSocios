-- ============================================================================
-- MÓDULO DE ARCHIVOS POR SOCIO
-- Descripción: Tabla de metadatos de archivos adjuntos a socios.
--              Los archivos se almacenan en Supabase Storage (bucket: socios-archivos)
-- ============================================================================

-- Crear tabla de archivos
CREATE TABLE IF NOT EXISTS public.archivos_socios (
  id              SERIAL PRIMARY KEY,
  socio_id        INTEGER NOT NULL REFERENCES public.socios(id) ON DELETE CASCADE,
  nombre          VARCHAR(255) NOT NULL,     -- Nombre visible del archivo
  storage_path    VARCHAR(500) NOT NULL,     -- Ruta en Supabase Storage
  tipo_contenido  VARCHAR(100),              -- MIME type (image/pdf, application/pdf, etc.)
  tamanio         BIGINT,                    -- Tamaño en bytes
  descripcion     TEXT,                     -- Descripción opcional
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para búsquedas por socio
CREATE INDEX IF NOT EXISTS idx_archivos_socios_socio_id ON public.archivos_socios(socio_id);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_archivos_socios_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS archivos_socios_updated_at ON public.archivos_socios;
CREATE TRIGGER archivos_socios_updated_at
  BEFORE UPDATE ON public.archivos_socios
  FOR EACH ROW EXECUTE FUNCTION update_archivos_socios_updated_at();

-- RLS
ALTER TABLE public.archivos_socios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Denegar acceso a usuarios anónimos" ON public.archivos_socios;
DROP POLICY IF EXISTS "Permitir lectura a usuarios autenticados" ON public.archivos_socios;
DROP POLICY IF EXISTS "Permitir todo a service_role" ON public.archivos_socios;

CREATE POLICY "Denegar acceso a usuarios anónimos"
  ON public.archivos_socios FOR ALL TO anon USING (false);

CREATE POLICY "Permitir lectura a usuarios autenticados"
  ON public.archivos_socios FOR SELECT TO authenticated USING (true);

CREATE POLICY "Permitir todo a service_role"
  ON public.archivos_socios FOR ALL TO service_role USING (true) WITH CHECK (true);

-- También necesita políticas para INSERT/UPDATE/DELETE por usuarios autenticados
CREATE POLICY "Permitir escritura a usuarios autenticados"
  ON public.archivos_socios FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Permitir actualización a usuarios autenticados"
  ON public.archivos_socios FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Permitir eliminación a usuarios autenticados"
  ON public.archivos_socios FOR DELETE TO authenticated USING (true);

-- ============================================================================
-- BUCKET DE SUPABASE STORAGE
-- Crear manualmente en Supabase Dashboard > Storage:
--   Bucket name: socios-archivos
--   Public: false (archivos privados, acceso solo via signed URL)
-- ============================================================================
