-- ============================================================
-- HSE - Esquema de Base de Datos Supabase
-- Sistema de Gestión HSE para Contratista Minera SQM
-- ============================================================

-- 1. Tabla: trabajadores (Datos fijos del personal)
CREATE TABLE IF NOT EXISTS trabajadores (
  id serial PRIMARY KEY,
  rut text UNIQUE NOT NULL,
  nombre text NOT NULL,
  apellido_paterno text NOT NULL,
  apellido_materno text,
  cargo text NOT NULL,
  nacionalidad text DEFAULT 'Chilena',
  vencimiento_residencia text,
  sexo text CHECK (sexo IN ('M', 'F', 'Otro')),
  turno text NOT NULL,
  estado_trabajador text NOT NULL DEFAULT 'ACTIVO' CHECK (estado_trabajador IN ('ACTIVO', 'DESVINCULADO', 'LICENCIA')),
  contrato_codigo text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 2. Tabla: requisitos_hse (Catálogo dinámico de documentos/exámenes)
CREATE TABLE IF NOT EXISTS requisitos_hse (
  id serial PRIMARY KEY,
  nombre_requisito text NOT NULL,
  requiere_vencimiento boolean NOT NULL DEFAULT false
);

-- Poblar catálogo con los 12 requisitos exactos del Excel
INSERT INTO requisitos_hse (nombre_requisito, requiere_vencimiento) VALUES
  ('Exámenes Ocupacionales / Pre-Ocupacionales (AG/AF)', true),
  ('Examen Alcohol y drogas', true),
  ('Examen Psicosensometrico', true),
  ('Fecha Vencimiento Inducción SQM', true),
  ('Protocolo SQM (ODI)', false),
  ('CTTA(ODI)', false),
  ('Certificación (Soldadores, electricos, riggers, op.Maquinaria, etc)', false),
  ('Licencia Interna SQM', false),
  ('Difusión Procedimientos', false),
  ('Difusión Plan y Sub Planes SQM', false),
  ('Difusión Plan y Sub Planes Cttas', false),
  ('Difusión HDS', false)
ON CONFLICT DO NOTHING;

-- 3. Tabla: cumplimiento_trabajadores (Matriz vertical de estados y fechas)
CREATE TABLE IF NOT EXISTS cumplimiento_trabajadores (
  id serial PRIMARY KEY,
  trabajador_id integer NOT NULL REFERENCES trabajadores(id) ON DELETE CASCADE,
  requisito_id integer NOT NULL REFERENCES requisitos_hse(id) ON DELETE RESTRICT,
  valor_estado text NOT NULL CHECK (valor_estado IN ('VIGENTE', 'SI', 'NO', 'N/A', 'VENCIDO')),
  fecha_vencimiento date,
  documento_url text,
  updated_at timestamp with time zone DEFAULT now(),
  UNIQUE(trabajador_id, requisito_id)
);

-- ============================================================
-- TRIGGER: Actualizar updated_at automáticamente en trabajadores
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

-- Trigger para cumplimiento_trabajadores
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
-- POLÍTICAS DE SEGURIDAD (Row Level Security)
-- Habilitar RLS en las nuevas tablas
ALTER TABLE trabajadores ENABLE ROW LEVEL SECURITY;
ALTER TABLE requisitos_hse ENABLE ROW LEVEL SECURITY;
ALTER TABLE cumplimiento_trabajadores ENABLE ROW LEVEL SECURITY;

-- Políticas para trabajadores
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver trabajadores" ON trabajadores;
CREATE POLICY "Usuarios autenticados pueden ver trabajadores"
  ON trabajadores FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar trabajadores" ON trabajadores;
CREATE POLICY "Usuarios autenticados pueden insertar trabajadores"
  ON trabajadores FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar trabajadores" ON trabajadores;
CREATE POLICY "Usuarios autenticados pueden actualizar trabajadores"
  ON trabajadores FOR UPDATE
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar trabajadores" ON trabajadores;
CREATE POLICY "Usuarios autenticados pueden eliminar trabajadores"
  ON trabajadores FOR DELETE
  TO authenticated
  USING (true);

-- Políticas para requisitos_hse (catálogo de solo lectura)
DROP POLICY IF EXISTS "Requisitos HSE visibles para usuarios autenticados" ON requisitos_hse;
CREATE POLICY "Requisitos HSE visibles para usuarios autenticados"
  ON requisitos_hse FOR SELECT
  TO authenticated
  USING (true);

-- Políticas para cumplimiento_trabajadores
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden ver cumplimiento"
  ON cumplimiento_trabajadores FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden insertar cumplimiento"
  ON cumplimiento_trabajadores FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden actualizar cumplimiento"
  ON cumplimiento_trabajadores FOR UPDATE
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden eliminar cumplimiento"
  ON cumplimiento_trabajadores FOR DELETE
  TO authenticated
  USING (true);

-- Política para acceso público anon (para debugging en desarrollo)
DROP POLICY IF EXISTS "Acceso anon a trabajadores" ON trabajadores;
CREATE POLICY "Acceso anon a trabajadores"
  ON trabajadores FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Acceso anon a requisitos_hse" ON requisitos_hse;
CREATE POLICY "Acceso anon a requisitos_hse"
  ON requisitos_hse FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS "Acceso anon a cumplimiento_trabajadores" ON cumplimiento_trabajadores;
CREATE POLICY "Acceso anon a cumplimiento_trabajadores"
  ON cumplimiento_trabajadores FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- ÍNDICES para optimizar consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_trabajadores_rut ON trabajadores(rut);
CREATE INDEX IF NOT EXISTS idx_trabajadores_estado ON trabajadores(estado_trabajador);
CREATE INDEX IF NOT EXISTS idx_trabajadores_contrato ON trabajadores(contrato_codigo);
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
    ct.valor_estado,
    ct.fecha_vencimiento,
    ct.documento_url
  FROM trabajadores t
  CROSS JOIN requisitos_hse r
  LEFT JOIN cumplimiento_trabajadores ct 
    ON t.id = ct.trabajador_id 
    AND r.id = ct.requisito_id
  WHERE t.id = p_trabajador_id
  ORDER BY r.id;
END;
$$ LANGUAGE plpgsql STABLE;
