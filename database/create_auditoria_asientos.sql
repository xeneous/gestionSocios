-- =============================================================================
-- AUDITORÍA de asientos contables: quién cambió qué y cuándo.
-- Registra INSERT / UPDATE / DELETE de asientos_header y asientos_items,
-- con el valor anterior y el nuevo, el usuario (auth.uid + email) y la fecha.
--
-- Ejecutar los pasos DE A UNO en el SQL Editor (a veces da timeout).
-- No modifica datos existentes ni cambia el comportamiento de la app.
-- =============================================================================

-- PASO 1: tabla de auditoría ---------------------------------------------------
CREATE TABLE IF NOT EXISTS public.auditoria_asientos (
  id            BIGSERIAL PRIMARY KEY,
  fecha_hora    TIMESTAMPTZ NOT NULL DEFAULT now(),
  tabla         TEXT        NOT NULL,           -- asientos_header | asientos_items
  operacion     TEXT        NOT NULL,           -- INSERT | UPDATE | DELETE
  asiento       INTEGER,
  anio_mes      INTEGER,
  tipo_asiento  INTEGER,
  usuario_id    UUID,                           -- auth.uid() (NULL si fue SQL Editor / service role)
  usuario_email TEXT,
  db_role       TEXT,                           -- current_user (authenticated, postgres, service_role...)
  txid          BIGINT,                         -- agrupa todo lo hecho en una misma transacción
  datos_antes   JSONB,
  datos_despues JSONB
);

CREATE INDEX IF NOT EXISTS idx_aud_asientos_clave
  ON public.auditoria_asientos (anio_mes, asiento, tipo_asiento);
CREATE INDEX IF NOT EXISTS idx_aud_asientos_fecha
  ON public.auditoria_asientos (fecha_hora DESC);


-- PASO 2: función del trigger --------------------------------------------------
-- SECURITY DEFINER: escribe en la auditoría aunque el usuario no tenga permiso directo.
CREATE OR REPLACE FUNCTION public.fn_auditar_asientos()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ref  RECORD;
  v_uid  UUID;
  v_mail TEXT;
BEGIN
  BEGIN
    v_uid  := auth.uid();
    v_mail := auth.jwt() ->> 'email';
  EXCEPTION WHEN OTHERS THEN
    v_uid := NULL; v_mail := NULL;
  END;

  IF TG_OP = 'DELETE' THEN v_ref := OLD; ELSE v_ref := NEW; END IF;

  INSERT INTO public.auditoria_asientos
    (tabla, operacion, asiento, anio_mes, tipo_asiento,
     usuario_id, usuario_email, db_role, txid, datos_antes, datos_despues)
  VALUES
    (TG_TABLE_NAME, TG_OP, v_ref.asiento, v_ref.anio_mes, v_ref.tipo_asiento,
     v_uid, v_mail, current_user, txid_current(),
     CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
     CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END);

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;


-- PASO 3: triggers -------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_auditar_asientos_header ON public.asientos_header;
CREATE TRIGGER trg_auditar_asientos_header
  AFTER INSERT OR UPDATE OR DELETE ON public.asientos_header
  FOR EACH ROW EXECUTE FUNCTION public.fn_auditar_asientos();

DROP TRIGGER IF EXISTS trg_auditar_asientos_items ON public.asientos_items;
CREATE TRIGGER trg_auditar_asientos_items
  AFTER INSERT OR UPDATE OR DELETE ON public.asientos_items
  FOR EACH ROW EXECUTE FUNCTION public.fn_auditar_asientos();


-- PASO 4: permisos -------------------------------------------------------------
-- La app no lee esta tabla; solo la consultan administradores desde el SQL Editor.
-- RLS activado sin policy para anon/authenticated = nadie la ve por la API;
-- el trigger escribe igual por ser SECURITY DEFINER.
ALTER TABLE public.auditoria_asientos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.auditoria_asientos FROM anon, authenticated;


-- =============================================================================
-- CONSULTAS DE USO
-- =============================================================================

-- Historial de un asiento (cambiar los valores)
-- SELECT fecha_hora, tabla, operacion, usuario_email, db_role,
--        datos_antes ->> 'cuenta_id' AS cuenta_antes, datos_despues ->> 'cuenta_id' AS cuenta_despues,
--        datos_antes ->> 'debe' AS debe_antes, datos_despues ->> 'debe' AS debe_despues,
--        datos_antes ->> 'haber' AS haber_antes, datos_despues ->> 'haber' AS haber_despues
-- FROM auditoria_asientos
-- WHERE anio_mes = 202606 AND asiento = 52 AND tipo_asiento = 3
-- ORDER BY id;

-- Últimos cambios de cualquier asiento, por usuario
-- SELECT fecha_hora, usuario_email, tabla, operacion, anio_mes, asiento, tipo_asiento
-- FROM auditoria_asientos ORDER BY id DESC LIMIT 100;
