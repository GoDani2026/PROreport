-- ================================================================
-- PROreport - Diagnóstico de Notificaciones
-- ================================================================
-- Ejecutar TODO este script en el SQL Editor de Supabase.
-- Copia y pega los resultados para que podamos identificar el problema.
-- ================================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. Verificar extensión pg_net
-- ═══════════════════════════════════════════════════════════════
SELECT '1. pg_net' as check_name,
       CASE WHEN extname IS NOT NULL THEN '✅ Instalada' ELSE '❌ NO INSTALADA' END as status
FROM pg_extension WHERE extname = 'pg_net';

-- ═══════════════════════════════════════════════════════════════
-- 2. Verificar configuración de URL de Edge Function
-- ═══════════════════════════════════════════════════════════════
SELECT '2. Config app.edge_function_url' as check_name,
       CASE
         WHEN current_setting('app.edge_function_url', true) IS NOT NULL
           AND current_setting('app.edge_function_url', true) != ''
         THEN '✅ Configurada: ' || current_setting('app.edge_function_url', true)
         ELSE '❌ NO CONFIGURADA'
       END as status;

-- ═══════════════════════════════════════════════════════════════
-- 3. Verificar que la función invocar_notification_edge existe
-- ═══════════════════════════════════════════════════════════════
SELECT '3. Función invocar_notification_edge' as check_name,
       CASE
         WHEN COUNT(*) > 0 THEN '✅ Existe'
         ELSE '❌ NO EXISTE'
       END as status
FROM pg_proc WHERE proname = 'invocar_notification_edge';

-- ═══════════════════════════════════════════════════════════════
-- 4. Verificar triggers en detecciones_peligro
-- ═══════════════════════════════════════════════════════════════
SELECT '4. Trigger en detecciones_peligro' as check_name,
       CASE
         WHEN COUNT(*) > 0 THEN '✅ Existe: ' || string_agg(tgname, ', ')
         ELSE '❌ NO EXISTE'
       END as status
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'detecciones_peligro'
  AND t.tgname = 'trg_notify_deteccion_peligro_insert';

-- ═══════════════════════════════════════════════════════════════
-- 5. Verificar triggers en incidentes
-- ═══════════════════════════════════════════════════════════════
SELECT '5. Trigger en incidentes' as check_name,
       CASE
         WHEN COUNT(*) > 0 THEN '✅ Existe'
         ELSE '❌ NO EXISTE'
       END as status
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'incidentes'
  AND t.tgname = 'trg_notify_incidente_insert';

-- ═══════════════════════════════════════════════════════════════
-- 6. PRUEBA MANUAL: Invocar la edge function directamente
--    (Esto prueba si la función SQL funciona sin depender de triggers)
-- ═══════════════════════════════════════════════════════════════
SELECT '6. Prueba manual de invocación' as check_name,
       'Ejecutando...' as status;

-- Descomenta la siguiente línea para probar:
-- SELECT public.invocar_notification_edge('deteccion_peligro', 'INSERT', '{"id": 999, "usuario_reportante_id": "00000000-0000-0000-0000-000000000000", "area_id": 1, "turno": "Diurno", "lugar_exacto": "TEST", "descripcion_hallazgo": "Test diagnóstico", "nivel_atencion_lgf": "MEDIO", "estatus_seguimiento": "Pendiente"}'::jsonb);

-- ═══════════════════════════════════════════════════════════════
-- 7. Ver permisos de la función
-- ═══════════════════════════════════════════════════════════════
SELECT '7. Permisos función' as check_name,
       'Verificar que GRANT EXECUTE se haya ejecutado' as status;

-- ═══════════════════════════════════════════════════════════════
-- 8. Últimos registros en detecciones_peligro (para ver IDs)
-- ═══════════════════════════════════════════════════════════════
SELECT '8. Últimas detecciones' as check_name,
       COUNT(*)::text || ' registros en la tabla' as status
FROM detecciones_peligro;

-- ═══════════════════════════════════════════════════════════════
-- RESUMEN
-- ═══════════════════════════════════════════════════════════════
-- Si los checks 1-5 están todos en ✅, el problema está en la Edge Function.
-- Ve al Dashboard → Edge Functions → send-notification-email → Logs
-- y dime qué errores aparecen.