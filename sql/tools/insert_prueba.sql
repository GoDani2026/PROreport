-- ================================================================
-- PROreport - Insert de prueba para verificar notificación
-- Usa contrato_codigo (NO area_id, que fue migrada)
-- ================================================================
-- Ejecutar en el SQL Editor del Dashboard de Supabase (NAVEGADOR)
-- ================================================================

-- 1. Ver qué contratos existen
SELECT 'Contratos disponibles:' as info, codigo, nombre FROM contratos;

-- 2. Ver qué perfiles existen (para obtener usuario_reportante_id)
SELECT 'Perfiles:' as info, id, nombre_completo, rol FROM perfiles LIMIT 5;

-- 3. Insertar detección de prueba
INSERT INTO detecciones_peligro (
  usuario_reportante_id,
  contrato_codigo,
  turno,
  lugar_exacto,
  descripcion_hallazgo,
  nivel_atencion_lgf,
  accion_inmediata
) VALUES (
  (SELECT id FROM perfiles LIMIT 1),
  (SELECT codigo FROM contratos LIMIT 1),
  'Diurno',
  'Sector A - Pasillo Principal',
  'PRUEBA: Cable suelto en pasillo - test notificación',
  'MEDIO',
  'Señalizar el área y reportar a mantenimiento'
);

-- 4. Confirmar
SELECT '✅ Inserción exitosa. Revisa los logs de la Edge Function.' as resultado;