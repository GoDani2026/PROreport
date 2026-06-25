-- ============================================================
-- Parche RLS: Deshabilitar completamente Row Level Security
-- para que cualquier usuario (incluso anónimo) pueda insertar
-- en las tablas de gestión de personal.
-- ============================================================

ALTER TABLE IF EXISTS trabajadores DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS cumplimiento_trabajadores DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS requisitos_hse DISABLE ROW LEVEL SECURITY;