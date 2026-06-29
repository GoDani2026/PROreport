-- ============================================================
-- PROreport - Configurar un usuario como Super Administrador
-- Incluye corrección automática del CHECK constraint
-- ============================================================

-- ============================================================
-- PASO 0 (NUEVO): Corregir CHECK constraint si existe
-- Esto soluciona el error "violates check constraint"
-- ============================================================
ALTER TABLE public.perfiles 
DROP CONSTRAINT IF EXISTS perfiles_rol_check;

ALTER TABLE public.perfiles 
ADD CONSTRAINT perfiles_rol_check 
CHECK (rol IN ('colaborador', 'supervisor', 'admin', 'superadmin'));

-- ============================================================
-- PASO 1: Ejecuta esto para ver tus usuarios
-- ============================================================
SELECT id, email FROM auth.users;

-- ============================================================
-- PASO 2: Copia TU EMAIL exacto y ejecuta esto para asignar superadmin
-- Reemplaza TU_EMAIL@CORREO.COM con tu correo real entre comillas simples
-- ============================================================
DO $$
DECLARE
  v_user_id uuid;
BEGIN
  -- Buscar el usuario por email (sin distinguir mayúsculas/minúsculas)
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE LOWER(email) = LOWER('TU_EMAIL@CORREO.COM');

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario con email TU_EMAIL@CORREO.COM no encontrado en auth.users';
  END IF;

  -- Actualizar o crear el perfil
  UPDATE public.perfiles
  SET rol = 'superadmin'
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    INSERT INTO public.perfiles (id, rol)
    VALUES (v_user_id, 'superadmin');
  END IF;

  RAISE NOTICE 'Usuario % configurado como superadmin', v_user_id;
END $$;

-- ============================================================
-- PASO 3: Verificar el resultado (email viene de auth.users)
-- ============================================================
SELECT p.id, u.email, p.rol
FROM public.perfiles p
JOIN auth.users u ON u.id = p.id
WHERE p.rol = 'superadmin';