-- ============================================================
-- PROreport - Fix RLS: Políticas faltantes para catálogos
-- ============================================================
-- Este script agrega las políticas RLS faltantes para las
-- tablas `areas` y `tipos_incidente`, que permiten a los
-- usuarios autenticados leer los catálogos.
--
-- EJECUTAR EN: SQL Editor de Supabase (https://supabase.com/dashboard/project/inleckebqssizgeovgov)
-- ============================================================

-- TABLA: areas
-- ============================================================

ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Catálogos visibles para usuarios autenticados" ON public.areas;

CREATE POLICY "Catálogos visibles para usuarios autenticados"
  ON public.areas FOR SELECT
  TO authenticated
  USING (true);

-- TABLA: tipos_incidente
-- ============================================================

ALTER TABLE public.tipos_incidente ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Catálogos visibles para usuarios autenticados" ON public.tipos_incidente;

CREATE POLICY "Catálogos visibles para usuarios autenticados"
  ON public.tipos_incidente FOR SELECT
  TO authenticated
  USING (true);

-- VERIFICACIÓN (opcional - puedes ejecutar esto para confirmar)
-- ============================================================
-- SELECT tablename, policyname, permissive, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename IN ('areas', 'tipos_incidente');