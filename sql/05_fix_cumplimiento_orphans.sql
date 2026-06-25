-- ============================================================
-- PROreport - 05. Fix: Corregir IDs huérfanos en cumplimiento_trabajadores
-- Problema: trabajadores.id (serial) inicia en 731, cumplimiento.trabajador_id inicia en 772
-- Esto genera registros huérfanos (FK que no apunta a ningún trabajador)
-- ============================================================

-- 1. DIAGNÓSTICO: Ver cuántos registros de cumplimiento están huérfanos
SELECT 
  COUNT(*) AS total_huerfanos,
  MIN(ct.trabajador_id) AS id_min_huerfano,
  MAX(ct.trabajador_id) AS id_max_huerfano
FROM cumplimiento_trabajadores ct
LEFT JOIN trabajadores t ON ct.trabajador_id = t.id
WHERE t.id IS NULL;

-- 2. DIAGNÓSTICO: Ver los trabajadores existentes (rango de IDs válidos)
SELECT MIN(id) AS id_min_trabajadores, MAX(id) AS id_max_trabajadores, COUNT(*) AS total
FROM trabajadores;

-- 3. ELIMINAR registros huérfanos (sin trabajador asociado)
-- NOTA: Esto NO borra trabajadores, solo los cumplimientos con FK inválida
DELETE FROM cumplimiento_trabajadores
WHERE trabajador_id NOT IN (
  SELECT id FROM trabajadores WHERE deleted_at IS NULL
);

-- 4. Verificar integridad después del fix
SELECT 
  COUNT(*) AS cumplimientos_restantes,
  COUNT(DISTINCT trabajador_id) AS trabajadores_con_cumplimiento
FROM cumplimiento_trabajadores
WHERE deleted_at IS NULL;

-- ============================================================
-- PREVENCIÓN: Para evitar este problema en el futuro,
-- usar SIEMPRE la carga masiva (BulkUploadService) que machea por RUT
-- y recupera los IDs correctos desde la BD, en lugar de SQL directo.
-- ============================================================