-- ============================================================
-- PROreport - Esquema de Base de Datos Supabase
-- Sistema de Reporte de Incidentes de Seguridad
-- ============================================================

-- 1. Tabla: tipos_incidente
CREATE TABLE IF NOT EXISTS tipos_incidente (
  id serial PRIMARY KEY,
  nombre text NOT NULL
);

-- Insertar tipos de incidente por defecto
INSERT INTO tipos_incidente (nombre) VALUES
  ('Acto Inseguro'),
  ('Condición Insegura'),
  ('Casi Accidente')
ON CONFLICT DO NOTHING;

-- 2. Tabla: areas
CREATE TABLE IF NOT EXISTS areas (
  id serial PRIMARY KEY,
  nombre text NOT NULL
);

-- Insertar áreas por defecto
INSERT INTO areas (nombre) VALUES
  ('Mina - Tajo Abierto'),
  ('Planta de Procesos'),
  ('Mantenimiento'),
  ('Oficinas Administrativas'),
  ('Almacén'),
  ('Laboratorio')
ON CONFLICT DO NOTHING;

-- 3. Tabla: perfiles (extensión de auth.users)
CREATE TABLE IF NOT EXISTS perfiles (
  id uuid REFERENCES auth.users PRIMARY KEY,
  nombre_completo text,
  rol text DEFAULT 'colaborador' CHECK (rol IN ('colaborador', 'supervisor', 'admin')),
  avatar_url text,
  created_at timestamp DEFAULT now()
);

-- 4. Tabla: incidentes (tabla principal)
CREATE TABLE IF NOT EXISTS incidentes (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  fecha date DEFAULT current_date NOT NULL,
  descripcion text NOT NULL,
  tipo_incidente_id int REFERENCES tipos_incidente(id),
  area_id int REFERENCES areas(id),
  supervisor_id uuid REFERENCES perfiles(id),
  fotos_urls text[] DEFAULT '{}',
  usuario_id uuid REFERENCES auth.users(id),
  created_at timestamp DEFAULT now()
);

-- 5. Bucket de Storage para fotos de incidentes
-- Ejecutar desde el panel de Supabase Storage:
-- Crear bucket 'incidentes_storage' (público o privado según requieras)

-- ============================================================
-- POLÍTICAS DE SEGURIDAD (Row Level Security)

-- Habilitar RLS en todas las tablas
ALTER TABLE incidentes ENABLE ROW LEVEL SECURITY;
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_incidente ENABLE ROW LEVEL SECURITY;
ALTER TABLE areas ENABLE ROW LEVEL SECURITY;

-- Política para permitir acceso a la tabla incidentes (SOLUCIÓN ERROR PGRST205)
-- IMPORTANTE: Si la app falla con "Could not find the table 'public.incidentes'",
-- descomenta y ejecuta esta política para que anon también pueda ver la tabla:
CREATE POLICY "Permitir todo a usuarios anonimos"
ON public.incidentes
FOR ALL
TO anon
USING (true)
WITH CHECK (true);

-- Políticas para incidentes (usuarios autenticados)
CREATE POLICY "Usuarios autenticados pueden insertar incidentes"
  ON incidentes FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Usuarios pueden ver sus propios incidentes"
  ON incidentes FOR SELECT
  TO authenticated
  USING (usuario_id = auth.uid());

CREATE POLICY "Usuarios autenticados pueden ver todos los incidentes"
  ON incidentes FOR SELECT
  TO authenticated
  USING (true);

-- Políticas para perfiles
CREATE POLICY "Perfiles visibles para todos los usuarios autenticados"
  ON perfiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios pueden modificar su propio perfil"
  ON perfiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid());

-- Políticas para tablas de catálogo (lectura pública para autenticados)
CREATE POLICY "Catálogos visibles para usuarios autenticados"
  ON tipos_incidente FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Catálogos visibles para usuarios autenticados"
  ON areas FOR SELECT
  TO authenticated
  USING (true);

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
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- ÍNDICES para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_incidentes_fecha ON incidentes(fecha DESC);
CREATE INDEX IF NOT EXISTS idx_incidentes_usuario ON incidentes(usuario_id);
CREATE INDEX IF NOT EXISTS idx_incidentes_tipo ON incidentes(tipo_incidente_id);
CREATE INDEX IF NOT EXISTS idx_incidentes_area ON incidentes(area_id);
CREATE INDEX IF NOT EXISTS idx_incidentes_supervisor ON incidentes(supervisor_id);