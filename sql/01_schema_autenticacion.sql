-- ============================================================
-- PROreport - 01. Esquema de Autenticación y Perfiles
-- Versión consolidada: perfiles incluye trabajador_id (1:1)
-- Eliminada: tabla puente usuarios_trabajadores
-- ============================================================

-- 1. Tabla: perfiles (extensión de auth.users)
-- Contiene trabajador_id para relación directa con trabajadores
CREATE TABLE IF NOT EXISTS perfiles (
  id uuid REFERENCES auth.users PRIMARY KEY,
  nombre_completo text,
  rol text DEFAULT 'colaborador' CHECK (rol IN ('colaborador', 'supervisor', 'admin')),
  avatar_url text,
  trabajador_id integer UNIQUE REFERENCES trabajadores(id) ON DELETE SET NULL,
  created_at timestamp DEFAULT now()
);

-- ============================================================
-- POLÍTICAS DE SEGURIDAD (Row Level Security)

-- Habilitar RLS
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;

-- Políticas para perfiles
CREATE POLICY "Perfiles visibles para todos los usuarios autenticados"
  ON perfiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios pueden modificar su propio perfil"
  ON perfiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid());

-- ============================================================
-- FUNCIÓN: Crear perfil automáticamente al registrar usuario
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.perfiles (id, nombre_completo, rol)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'nombre_completo', 'Usuario'),
    'colaborador'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para crear perfil tras registro
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();