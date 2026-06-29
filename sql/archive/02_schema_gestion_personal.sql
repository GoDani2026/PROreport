-- ============================================================
-- PROreport - 02. Esquema de Gestión de Personal HSE
-- Consolidado: estados normalizados VIGENTE/VENCIDO/N/A
-- cumplimiento_trabajadores con usuario_registra_id → perfiles
-- ============================================================

-- 1. Tabla: trabajadores (Datos fijos del personal)
CREATE TABLE IF NOT EXISTS trabajadores (
  id serial PRIMARY KEY,
  rut text UNIQUE NOT NULL,
  nombre text NOT NULL,
  apellido_paterno text NOT NULL,
  apellido_materno text DEFAULT '',
  cargo text DEFAULT '',
  nacionalidad text DEFAULT 'Chilena',
  fecha_vencimiento_residencia text DEFAULT '',
  sexo text DEFAULT '',
  turno text DEFAULT '',
  empresa text DEFAULT '',
  estado_trabajador text NOT NULL DEFAULT 'ACTIVO' CHECK (estado_trabajador IN ('ACTIVO', 'DESVINCULADO', 'LICENCIA')),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp DEFAULT NULL
);

-- 2. Tabla: requisitos_hse (Catálogo dinámico de documentos/exámenes)
CREATE TABLE IF NOT EXISTS requisitos_hse (
  id serial PRIMARY KEY,
  nombre_requisito text NOT NULL,
  requiere_vencimiento boolean NOT NULL DEFAULT false
);

-- Poblar catálogo con los 12 requisitos exactos del Excel
INSERT INTO requisitos_hse (id, nombre_requisito, requiere_vencimiento) VALUES
  (1, 'Exámenes Ocupacionales / Pre-Ocupacionales (AG/AF)', true),
  (2, 'Examen Alcohol y drogas', true),
  (3, 'Examen Psicosensometrico', true),
  (4, 'Fecha Vencimiento Inducción SQM', true),
  (5, 'Protocolo SQM (ODI)', false),
  (6, 'CTTA(ODI)', false),
  (7, 'Certificación (Soldadores, electricos, riggers, op.Maquinaria, etc)', false),
  (8, 'Licencia Interna SQM', false),
  (9, 'Difusión Procedimientos', false),
  (10, 'Difusión Plan y Sub Planes SQM', false),
  (11, 'Difusión Plan y Sub Planes Cttas', false),
  (12, 'Difusión HDS', false)
ON CONFLICT (id) DO NOTHING;

-- 3. Tabla: cumplimiento_trabajadores (Matriz vertical con estados normalizados)
CREATE TABLE IF NOT EXISTS cumplimiento_trabajadores (
  id serial PRIMARY KEY,
  trabajador_id integer NOT NULL REFERENCES trabajadores(id) ON DELETE CASCADE,
  requisito_id integer NOT NULL REFERENCES requisitos_hse(id) ON DELETE RESTRICT,
  valor_estado text NOT NULL DEFAULT 'N/A' CHECK (valor_estado IN ('VIGENTE', 'VENCIDO', 'N/A')),
  fecha_vencimiento date,
  documento_url text,
  usuario_registra_id uuid REFERENCES perfiles(id),
  updated_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp DEFAULT NULL,
  UNIQUE(trabajador_id, requisito_id)
);

-- ============================================================
-- TRIGGERS: Actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION public.handle_updated_at_trabajadores()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_trabajadores_updated
  BEFORE UPDATE ON trabajadores
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_trabajadores();

CREATE OR REPLACE FUNCTION public.handle_updated_at_cumplimiento()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_cumplimiento_updated
  BEFORE UPDATE ON cumplimiento_trabajadores
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_cumplimiento();

-- ============================================================
-- RLS: Row Level Security
ALTER TABLE trabajadores ENABLE ROW LEVEL SECURITY;
ALTER TABLE requisitos_hse ENABLE ROW LEVEL SECURITY;
ALTER TABLE cumplimiento_trabajadores ENABLE ROW LEVEL SECURITY;

-- Políticas para trabajadores
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver trabajadores" ON trabajadores;
CREATE POLICY "Usuarios autenticados pueden ver trabajadores"
  ON trabajadores FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Solo admin/supervisor puede modificar trabajadores" ON trabajadores;
CREATE POLICY "Solo admin/supervisor puede modificar trabajadores"
  ON trabajadores FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));

CREATE POLICY "Solo admin/supervisor puede actualizar trabajadores"
  ON trabajadores FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));

-- Políticas para requisitos_hse (catálogo de solo lectura)
DROP POLICY IF EXISTS "Requisitos HSE visibles para usuarios autenticados" ON requisitos_hse;
CREATE POLICY "Requisitos HSE visibles para usuarios autenticados"
  ON requisitos_hse FOR SELECT TO authenticated USING (true);

-- Políticas para cumplimiento_trabajadores
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden ver cumplimiento"
  ON cumplimiento_trabajadores FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Solo admin/supervisor modifica cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Solo admin/supervisor modifica cumplimiento"
  ON cumplimiento_trabajadores FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));

CREATE POLICY "Solo admin/supervisor actualiza cumplimiento"
  ON cumplimiento_trabajadores FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));

-- ============================================================
-- ÍNDICES para optimizar consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_trabajadores_rut ON trabajadores(rut);
CREATE INDEX IF NOT EXISTS idx_trabajadores_estado ON trabajadores(estado_trabajador);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_trabajador ON cumplimiento_trabajadores(trabajador_id);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_requisito ON cumplimiento_trabajadores(requisito_id);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_estado ON cumplimiento_trabajadores(valor_estado);

-- ============================================================
-- FUNCIÓN: Obtener cumplimiento completo de un trabajador
CREATE OR REPLACE FUNCTION public.obtener_cumplimiento_trabajador(p_trabajador_id integer)
RETURNS TABLE (
  trabajador_id integer,
  rut text,
  nombre text,
  apellido_paterno text,
  apellido_materno text,
  cargo text,
  estado_trabajador text,
  requisito_id integer,
  nombre_requisito text,
  valor_estado text,
  fecha_vencimiento date,
  documento_url text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id as trabajador_id,
    t.rut,
    t.nombre,
    t.apellido_paterno,
    t.apellido_materno,
    t.cargo,
    t.estado_trabajador,
    r.id as requisito_id,
    r.nombre_requisito,
    COALESCE(ct.valor_estado, 'N/A') as valor_estado,
    ct.fecha_vencimiento,
    ct.documento_url
  FROM trabajadores t
  CROSS JOIN requisitos_hse r
  LEFT JOIN cumplimiento_trabajadores ct 
    ON t.id = ct.trabajador_id 
    AND r.id = ct.requisito_id
    AND ct.deleted_at IS NULL
  WHERE t.id = p_trabajador_id
    AND t.deleted_at IS NULL
  ORDER BY r.id;
END;
$$ LANGUAGE plpgsql STABLE;