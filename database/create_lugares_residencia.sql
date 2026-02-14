-- Tabla para almacenar los lugares de residencia disponibles
CREATE TABLE IF NOT EXISTS public.lugares_residencia (
  id SERIAL PRIMARY KEY,
  nombre TEXT NOT NULL UNIQUE,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.lugares_residencia ENABLE ROW LEVEL SECURITY;

-- Política: todos los autenticados pueden leer
CREATE POLICY "Lectura lugares_residencia" ON public.lugares_residencia
  FOR SELECT TO authenticated USING (true);

-- Política: todos los autenticados pueden insertar
CREATE POLICY "Insertar lugares_residencia" ON public.lugares_residencia
  FOR INSERT TO authenticated WITH CHECK (true);

-- Popular con valores existentes de la tabla socios
INSERT INTO public.lugares_residencia (nombre)
SELECT DISTINCT trim(lugar_residencia)
FROM public.socios
WHERE lugar_residencia IS NOT NULL
  AND trim(lugar_residencia) != ''
ORDER BY trim(lugar_residencia)
ON CONFLICT (nombre) DO NOTHING;
