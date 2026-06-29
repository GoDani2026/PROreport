-- ============================================================
-- FIX RLS: Permitir lectura de contratos a usuarios autenticados
-- ============================================================

-- Eliminar política anterior restrictiva
DROP POLICY IF EXISTS "Contratos visibles para usuarios autenticados" ON public.contratos;

-- Crear política permisiva para SELECT (lectura)
CREATE POLICY "Contratos visibles para usuarios autenticados"
  ON public.contratos FOR SELECT
  TO authenticated
  USING (true);

-- Verificar políticas activas
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'contratos';