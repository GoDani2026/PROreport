-- ================================================================
-- PROreport - Instalar/Actualizar Triggers de Notificación v2
-- ----------------------------------------------------------------
-- Versión actualizada para la tabla detecciones_peligro con
-- contrato_codigo (en vez de area_id).
-- ================================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. ASEGURAR EXTENSIÓN pg_net
-- ═══════════════════════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ═══════════════════════════════════════════════════════════════
-- 2. CONFIGURAR URL DE LA EDGE FUNCTION
-- ═══════════════════════════════════════════════════════════════
SELECT set_config(
  'app.edge_function_url',
  'https://inleckebqssizgeovgov.supabase.co/functions/v1/send-notification-email',
  false
);

-- ═══════════════════════════════════════════════════════════════
-- 3. FUNCIÓN GENÉRICA PARA INVOCAR EDGE FUNCTION
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
BEGIN
  v_edge_url := current_setting('app.edge_function_url', true);
  v_secret := current_setting('app.function_secret', true);

  IF v_edge_url IS NULL OR v_edge_url = '' THEN
    RAISE NOTICE 'Edge function URL no configurada. Saltando notificación.';
    RETURN;
  END IF;

  v_payload := jsonb_build_object(
    'type', p_type,
    'operation', p_operation,
    'record', p_record
  );

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
-- 4. TRIGGER: detecciones_peligro (INSERT)
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
-- 5. TRIGGER: incidentes (INSERT)
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
-- 7. PERMISOS
-- ═══════════════════════════════════════════════════════════════
GRANT EXECUTE ON FUNCTION public.invocar_notification_edge TO authenticated;
GRANT EXECUTE ON FUNCTION public.invocar_notification_edge TO anon;

-- ═══════════════════════════════════════════════════════════════
-- 8. VERIFICACIÓN
-- ═══════════════════════════════════════════════════════════════
SELECT '✅ Triggers instalados correctamente' as resultado;
SELECT 'pg_net:' as check, CASE WHEN extname IS NOT NULL THEN '✅ Instalada' ELSE '❌ NO' END FROM pg_extension WHERE extname = 'pg_net';
SELECT 'URL config:' as check, COALESCE(current_setting('app.edge_function_url', true), '❌ NO CONFIGURADA');
SELECT 'Trigger detecciones:' as check, CASE WHEN COUNT(*)>0 THEN '✅ SI' ELSE '❌ NO' END FROM pg_trigger t JOIN pg_class c ON t.tgrelid=c.oid WHERE c.relname='detecciones_peligro' AND t.tgname='trg_notify_deteccion_peligro_insert';