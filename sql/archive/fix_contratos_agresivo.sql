-- ============================================================
-- FIX AGRESIVO: Diagnóstico y acceso total a tabla contratos
-- ============================================================

-- PASO 1: Desactivar RLS temporalmente para probar
ALTER TABLE public.contratos DISABLE ROW LEVEL SECURITY;

-- PASO 2: Eliminar cualquier política existente
DROP POLICY IF EXISTS "Contratos visibles para usuarios autenticados" ON public.contratos;
DROP POLICY IF EXISTS "Solo admin/supervisor puede modificar contratos" ON public.contratos;
DROP POLICY IF EXISTS "Solo admin/supervisor puede actualizar contratos" ON public.contratos;
DROP POLICY IF EXISTS "Contratos: select para authenticated" ON public.contratos;

-- PASO 3: Verificar que hay datos
SELECT COUNT(*) as total, 
       STRING_AGG(codigo, ', ' ORDER BY codigo) as contratos
FROM public.contratos;

-- PASO 4: Si hay datos, reactivar RLS con política ultra-permisiva
-- (descomenta las líneas abajo después de probar)

-- ALTER TABLE public.contratos ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Contratos: select para authenticated"
--   ON public.contratos FOR SELECT
--   TO authenticated
--   USING (true);