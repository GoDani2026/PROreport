-- ============================================================
-- PROreport - 03. Esquema de Solicitud de Levantamiento
-- Consolidado: FK consistentes (usuario_reportante_id → perfiles.id)
-- Supervisor → trabajadores.id
-- Sin columna JSONB acciones_correctivas duplicada
-- ============================================================

-- 1. Tabla: tipos_incidente
CREATE TABLE IF NOT EXISTS tipos_incidente (
  id serial PRIMARY KEY,
  nombre text NOT NULL,
  descripcion text DEFAULT ''
);

-- Insertar tipos de incidente por defecto
INSERT INTO tipos_incidente (id, nombre, descripcion) VALUES
  (1, 'Incidente de Seguridad', 'Lesiones, cuasi accidentes, condiciones inseguras'),
  (2, 'Emergencia Médica', 'Emergencias de salud en el lugar de trabajo'),
  (3, 'Incidente Ambiental', 'Derrames, emisiones, manejo inadecuado de residuos'),
  (4, 'No Conformidad', 'Incumplimiento de procedimientos o normativa'),
  (5, 'Hallazgo de Mejora', 'Oportunidad de mejora identificada')
ON CONFLICT DO NOTHING;

-- 2. Tabla: areas
CREATE TABLE IF NOT EXISTS areas (
  id serial PRIMARY KEY,
  nombre text NOT NULL,
  descripcion text DEFAULT ''
);

-- Insertar áreas por defecto
INSERT INTO areas (id, nombre, descripcion) VALUES
  (1, 'Mina', 'Área de operación minera'),
  (2, 'Planta', 'Área de procesamiento'),
  (3, 'Mantenimiento', 'Talleres y mantenimiento general'),
  (4, 'Administración', 'Oficinas y área administrativa'),
  (5, 'Bodega', 'Almacenes y bodegas')
ON CONFLICT DO NOTHING;

-- 3. Tabla: incidentes (tabla principal de reportes)
-- usuario_reportante_id → perfiles.id (UUID)
-- supervisor_trabajador_id → trabajadores.id (INTEGER)
-- Sin columna JSONB acciones_correctivas (se usa tabla independiente)
CREATE TABLE IF NOT EXISTS incidentes (
  id serial PRIMARY KEY,
  usuario_reportante_id uuid NOT NULL REFERENCES perfiles(id),
  tipo_incidente_id int NOT NULL REFERENCES tipos_incidente(id),
  area_id int NOT NULL REFERENCES areas(id),
  supervisor_trabajador_id int REFERENCES trabajadores(id),
  titulo text NOT NULL,
  descripcion text,
  fecha_reporte timestamp DEFAULT now(),
  fecha_incidente date NOT NULL,
  estado text DEFAULT 'abierto' CHECK (estado IN ('abierto', 'en_investigacion', 'cerrado', 'archivado')),
  severidad text DEFAULT 'baja' CHECK (severidad IN ('baja', 'media', 'alta', 'critica')),
  fotos text[] DEFAULT '{}',
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp DEFAULT NULL
);

-- ============================================================
-- RLS: Row Level Security
ALTER TABLE incidentes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_incidente ENABLE ROW LEVEL SECURITY;
ALTER TABLE areas ENABLE ROW LEVEL SECURITY;

-- Políticas para incidentes
CREATE POLICY "Incidentes visibles para autenticados"
  ON incidentes FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Usuarios pueden crear incidentes"
  ON incidentes FOR INSERT
  TO authenticated
  WITH CHECK (
    usuario_reportante_id = auth.uid()
  );

CREATE POLICY "Usuarios pueden actualizar sus propios incidentes o admin/supervisor"
  ON incidentes FOR UPDATE
  TO authenticated
  USING (
    usuario_reportante_id = auth.uid() OR
    EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor'))
  );

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
-- ÍNDICES para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_incidentes_fecha ON incidentes(fecha_incidente DESC);
CREATE INDEX IF NOT EXISTS idx_incidentes_usuario ON incidentes(usuario_reportante_id);
CREATE INDEX IF NOT EXISTS idx_incidentes_tipo ON incidentes(tipo_incidente_id);
CREATE INDEX IF NOT EXISTS idx_incidentes_area ON incidentes(area_id);
CREATE INDEX IF NOT EXISTS idx_incidentes_supervisor ON incidentes(supervisor_trabajador_id);
CREATE INDEX IF NOT EXISTS idx_incidentes_estado ON incidentes(estado);

-- Tabla: acciones_correctivas (estructura relacional independiente)
CREATE TABLE IF NOT EXISTS acciones_correctivas (
  id serial PRIMARY KEY,
  incidente_id integer NOT NULL REFERENCES incidentes(id) ON DELETE CASCADE,
  trabajador_asignado_id integer REFERENCES trabajadores(id),
  usuario_asignado_id uuid REFERENCES perfiles(id),
  descripcion text NOT NULL,
  fecha_asignacion timestamp DEFAULT now(),
  fecha_limite date NOT NULL,
  fecha_cierre timestamp,
  estado text NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'en_curso', 'completada', 'vencida')),
  prioridad text DEFAULT 'media' CHECK (prioridad IN ('baja', 'media', 'alta')),
  evidencia_url text,
  notas_cierre text,
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp DEFAULT NULL
);

-- RLS: acciones_correctivas
ALTER TABLE acciones_correctivas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Acciones visibles para autenticados"
  ON acciones_correctivas FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admin/supervisor gestiona acciones"
  ON acciones_correctivas FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor'))
  );

-- Índices
CREATE INDEX IF NOT EXISTS idx_acciones_incidente ON acciones_correctivas(incidente_id);
CREATE INDEX IF NOT EXISTS idx_acciones_estado ON acciones_correctivas(estado);

-- ============================================================
-- Bucket de Storage para fotos de incidentes
-- Crear desde el panel de Supabase Storage:
--   Bucket: 'incidentes_storage'
--   Política: Público (SELECT para anon, INSERT para authenticated)
-- ============================================================