-- ================================================================
-- PROreport - Migration: Notification Triggers
-- ----------------------------------------------------------------
-- Crea triggers que invocan la Edge Function send-notification-email
-- mediante pg_net (net.http_post) cuando se insertan/actualizan:
--   - incidentes
--   - detecciones_peligro
--   - cumplimiento_trabajadores
--
-- REQUISITOS PREVIOS:
--   1. La extensión pg_net debe estar instalada:
--      CREATE EXTENSION IF NOT EXISTS pg_net;
--   2. La Edge Function debe estar desplegada en Supabase
--   3. Las variables de entorno de la edge function configuradas
--      (SMTP_HOST, SMTP_USERNAME, SMTP_PASSWORD, etc.)
-- ================================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. Crear extensión pg_net (si no existe)
-- ═══════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ═══════════════════════════════════════════════════════════════
-- 2. Variable: URL de la Edge Function
--    Cambiar por la URL real después del deploy
-- ═══════════════════════════════════════════════════════════════
-- NOTA: Esta función debe ser actualizada con la URL real de la edge function
-- después del despliegue. Se puede hacer con:
--   SELECT set_config('app.edge_function_url', 'https://PROJECT_REF.supabase.co/functions/v1/send-notification-email', false);

-- ═══════════════════════════════════════════════════════════════
-- 3. Función genérica para invocar edge function
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.invocar_notification_edge(
  p_type TEXT,
  p_operation TEXT,
  p_record JSONB
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_edge_url TEXT;
  v_secret TEXT;
  v_payload JSONB;
  v_status INTEGER;
  v_response JSONB;
BEGIN
  -- Obtener URL de la edge function desde configuración
  v_edge_url := current_setting('app.edge_function_url', true);
  v_secret := current_setting('app.function_secret', true);

  -- Si no hay URL configurada, saltar
  IF v_edge_url IS NULL OR v_edge_url = '' THEN
    RAISE NOTICE 'Edge function URL no configurada. Saltando notificación.';
    RETURN;
  END IF;

  -- Construir payload
  v_payload := jsonb_build_object(
    'type', p_type,
    'operation', p_operation,
    'record', p_record
  );

  -- Enviar HTTP POST de forma asíncrona (no bloqueante)
  SELECT net.http_post(
    url := v_edge_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', CASE WHEN v_secret IS NOT NULL AND v_secret != ''
                           THEN 'Bearer ' || v_secret
                           ELSE '' END
    ),
    body := v_payload::text
  ) INTO v_status;

  RAISE NOTICE 'Notificación enviada: type=%, operation=%', p_type, p_operation;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'Error al invocar edge function: %', SQLERRM;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- 4. TRIGGER: incidentes (INSERT)
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.notify_incidente_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.invocar_notification_edge(
    'incidente',
    'INSERT',
    row_to_json(NEW)::jsonb
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_incidente_insert ON public.incidentes;
CREATE TRIGGER trg_notify_incidente_insert
  AFTER INSERT ON public.incidentes
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_incidente_insert();

-- ═══════════════════════════════════════════════════════════════
-- 5. TRIGGER: detecciones_peligro (INSERT)
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.notify_deteccion_peligro_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.invocar_notification_edge(
    'deteccion_peligro',
    'INSERT',
    row_to_json(NEW)::jsonb
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_deteccion_peligro_insert ON public.detecciones_peligro;
CREATE TRIGGER trg_notify_deteccion_peligro_insert
  AFTER INSERT ON public.detecciones_peligro
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_deteccion_peligro_insert();

-- ═══════════════════════════════════════════════════════════════
-- 6. TRIGGER: cumplimiento_trabajadores (INSERT + UPDATE)
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.notify_cumplimiento_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.invocar_notification_edge(
    'cumplimiento',
    TG_OP,
    row_to_json(NEW)::jsonb
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_cumplimiento_insert ON public.cumplimiento_trabajadores;
CREATE TRIGGER trg_notify_cumplimiento_insert
  AFTER INSERT ON public.cumplimiento_trabajadores
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_cumplimiento_change();

DROP TRIGGER IF EXISTS trg_notify_cumplimiento_update ON public.cumplimiento_trabajadores;
CREATE TRIGGER trg_notify_cumplimiento_update
  AFTER UPDATE ON public.cumplimiento_trabajadores
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_cumplimiento_change();

-- ═══════════════════════════════════════════════════════════════
-- 7. Conceder permisos
-- ═══════════════════════════════════════════════════════════════
GRANT EXECUTE ON FUNCTION public.invocar_notification_edge TO authenticated;
GRANT EXECUTE ON FUNCTION public.invocar_notification_edge TO anon;

-- ═══════════════════════════════════════════════════════════════
-- NOTAS DE CONFIGURACIÓN POST-DEPLOY:
-- ═══════════════════════════════════════════════════════════════
-- Después de desplegar, ejecutar:
--
--   -- Configurar URL de la edge function
--   SELECT set_config('app.edge_function_url',
--     'https://inleckebqssizgeovgov.supabase.co/functions/v1/send-notification-email',
--     false);
--
--   -- Opcional: configurar secret para autenticación
--   SELECT set_config('app.function_secret', 'tu-secreto-aqui', false);
--
-- Para probar manualmente:
--   SELECT public.invocar_notification_edge(
--     'incidente',
--     'INSERT',
--     '{"id": 1, "titulo": "Test", "descripcion": "Prueba"}'::jsonb
--   );
-- ================================================================