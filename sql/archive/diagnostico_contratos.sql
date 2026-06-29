-- ============================================================
-- DIAGNÓSTICO: Verificar contratos y rol superadmin
-- ============================================================

-- 1. Ver cuántos contratos existen
SELECT COUNT(*) as total_contratos FROM public.contratos;

-- 2. Ver todos los contratos activos
SELECT codigo, nombre, estado FROM public.contratos ORDER BY codigo;

-- 3. Ver tu usuario y su rol
SELECT p.id, u.email, p.rol, p.trabajador_id
FROM public.perfiles p
JOIN auth.users u ON u.id = p.id
WHERE u.email = 'TU_EMAIL@CORREO.COM';  -- <-- REEMPLAZA CON TU EMAIL

-- 4. Si no hay contratos, insertar los 3 por defecto
INSERT INTO public.contratos (codigo, nombre, estado) VALUES
  ('SC-14891', 'Apoyo Operacional', 'A'),
  ('SC-16011', 'Planta Nanofiltración', 'A'),
  ('SC-16187', 'Termofusión de HDPE', 'A')
ON CONFLICT (codigo) DO NOTHING;

-- 5. Verificar después de insertar
SELECT * FROM public.contratos ORDER BY codigo;