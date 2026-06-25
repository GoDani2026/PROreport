-- ============================================================
-- PROreport - ESQUEMA CONSOLIDADO FINAL
-- Normalización: Estados VIGENTE/VENCIDO/N/A
-- Relación perfiles ↔ trabajadores directa (sin tabla puente)
-- incidentes con FK consistentes (usuario_reportante_id → perfiles.id)
-- sin JSONB duplicado de acciones en incidentes
-- ============================================================
-- INSTRUCCIONES:
-- 1. Ir a: https://supabase.com/dashboard/project/inleckebqssizgeovgov
-- 2. SQL Editor → New Query
-- 3. Pegar TODO este archivo y ejecutar
-- 4. Luego ejecutar: SELECT public.sincronizar_trabajador_actual();
-- ============================================================

-- ============================================================
-- PASO 0: LIMPIEZA TOTAL (DROP de esquemas parciales antiguos)
-- ============================================================
DROP TABLE IF EXISTS public.usuarios_trabajadores CASCADE;
DROP TABLE IF EXISTS public.auditoria_cumplimiento CASCADE;
DROP TABLE IF EXISTS public.acciones_correctivas CASCADE;
DROP TABLE IF EXISTS public.incidentes CASCADE;
DROP TABLE IF EXISTS public.cumplimiento_trabajadores CASCADE;
DROP TABLE IF EXISTS public.trabajadores CASCADE;
DROP TABLE IF EXISTS public.requisitos_hse CASCADE;
DROP TABLE IF EXISTS public.perfiles CASCADE;
DROP TABLE IF EXISTS public.tipos_incidente CASCADE;
DROP TABLE IF EXISTS public.areas CASCADE;

-- ============================================================
-- PASO 1/5: AUTENTICACIÓN Y PERFILES
-- perfiles ahora incluye trabajador_id (relación 1:1 con trabajadores)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.perfiles (
  id uuid REFERENCES auth.users PRIMARY KEY,
  nombre_completo text,
  rol text DEFAULT 'colaborador' CHECK (rol IN ('colaborador', 'supervisor', 'admin')),
  avatar_url text,
  trabajador_id integer UNIQUE,
  created_at timestamp DEFAULT now()
);

-- ============================================================
-- POLÍTICAS DE SEGURIDAD (Row Level Security)
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;

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

-- ============================================================
-- PASO 2/5: GESTIÓN DE PERSONAL Y CUMPLIMIENTO HSE
-- ============================================================

-- Tabla: trabajadores (personas en el contrato minero)
CREATE TABLE IF NOT EXISTS public.trabajadores (
  id SERIAL PRIMARY KEY,
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
  contrato_codigo text DEFAULT 'SC-9500014891',
  estado_trabajador text DEFAULT 'ACTIVO' CHECK (estado_trabajador IN ('ACTIVO', 'DESVINCULADO', 'LICENCIA')),
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp DEFAULT NULL
);

-- ============================================================
-- Tabla: requisitos_hse (catálogo maestro de requisitos HSE)
CREATE TABLE IF NOT EXISTS public.requisitos_hse (
  id SERIAL PRIMARY KEY,
  nombre_requisito text NOT NULL,
  requiere_vencimiento boolean DEFAULT false,
  created_at timestamp DEFAULT now()
);

-- ============================================================
-- Ahora sí creamos la FK de perfiles hacia trabajadores (después de crear la tabla)
ALTER TABLE public.perfiles
  ADD CONSTRAINT fk_perfiles_trabajador
  FOREIGN KEY (trabajador_id) REFERENCES trabajadores(id) ON DELETE SET NULL;

-- ============================================================
-- Tabla: cumplimiento_trabajadores (relación N:M con estados normalizados)
CREATE TABLE IF NOT EXISTS public.cumplimiento_trabajadores (
  id SERIAL PRIMARY KEY,
  trabajador_id integer NOT NULL REFERENCES trabajadores(id) ON DELETE CASCADE,
  requisito_id integer NOT NULL REFERENCES requisitos_hse(id),
  valor_estado text NOT NULL DEFAULT 'N/A' CHECK (valor_estado IN ('VIGENTE', 'VENCIDO', 'N/A')),
  fecha_vencimiento date,
  documento_url text,
  usuario_registra_id uuid REFERENCES perfiles(id),
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp DEFAULT NULL,
  UNIQUE (trabajador_id, requisito_id)
);

-- ============================================================
-- SEED: Requisitos HSE para contrato SC-9500014891
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

-- ============================================================
-- RLS: trabajadores
ALTER TABLE trabajadores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Trabajadores visibles para autenticados"
  ON trabajadores FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Solo admin/supervisor puede modificar trabajadores"
  ON trabajadores FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor'))
  );

CREATE POLICY "Solo admin/supervisor puede actualizar trabajadores"
  ON trabajadores FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor'))
  );

-- RLS: requisitos_hse
ALTER TABLE requisitos_hse ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Requisitos HSE visibles para autenticados"
  ON requisitos_hse FOR SELECT
  TO authenticated
  USING (true);

-- RLS: cumplimiento_trabajadores
ALTER TABLE cumplimiento_trabajadores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Cumplimiento visible para autenticados"
  ON cumplimiento_trabajadores FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Solo admin/supervisor modifica cumplimiento"
  ON cumplimiento_trabajadores FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor'))
  );

CREATE POLICY "Solo admin/supervisor actualiza cumplimiento"
  ON cumplimiento_trabajadores FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor'))
  );

-- ============================================================
-- ÍNDICES para optimizar consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_trabajadores_rut ON trabajadores(rut);
CREATE INDEX IF NOT EXISTS idx_trabajadores_estado ON trabajadores(estado_trabajador);
CREATE INDEX IF NOT EXISTS idx_trabajadores_contrato ON trabajadores(contrato_codigo);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_trabajador ON cumplimiento_trabajadores(trabajador_id);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_requisito ON cumplimiento_trabajadores(requisito_id);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_estado ON cumplimiento_trabajadores(valor_estado);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_usuario ON cumplimiento_trabajadores(usuario_registra_id);

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

-- ============================================================
-- PASO 3/5: SOLICITUD DE LEVANTAMIENTO DE INCIDENTES
-- incidentes SIN columna jsonb acciones_correctivas (se usa tabla relacional)
-- FK consistentes: usuario_reportante_id → perfiles.id, supervisor_id → trabajadores.id
-- ============================================================

-- Tabla: tipos_incidente (catálogo)
CREATE TABLE IF NOT EXISTS public.tipos_incidente (
  id SERIAL PRIMARY KEY,
  nombre text NOT NULL,
  descripcion text DEFAULT ''
);

INSERT INTO tipos_incidente (id, nombre, descripcion) VALUES
  (1, 'Incidente de Seguridad', 'Lesiones, cuasi accidentes, condiciones inseguras'),
  (2, 'Emergencia Médica', 'Emergencias de salud en el lugar de trabajo'),
  (3, 'Incidente Ambiental', 'Derrames, emisiones, manejo inadecuado de residuos'),
  (4, 'No Conformidad', 'Incumplimiento de procedimientos o normativa'),
  (5, 'Hallazgo de Mejora', 'Oportunidad de mejora identificada')
ON CONFLICT (id) DO NOTHING;

-- Tabla: áreas
CREATE TABLE IF NOT EXISTS public.areas (
  id SERIAL PRIMARY KEY,
  nombre text NOT NULL,
  descripcion text DEFAULT ''
);

INSERT INTO areas (id, nombre, descripcion) VALUES
  (1, 'Mina', 'Área de operación minera'),
  (2, 'Planta', 'Área de procesamiento'),
  (3, 'Mantenimiento', 'Talleres y mantenimiento general'),
  (4, 'Administración', 'Oficinas y área administrativa'),
  (5, 'Bodega', 'Almacenes y bodegas')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- RLS: áreas
ALTER TABLE areas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Catálogos visibles para usuarios autenticados"
  ON areas FOR SELECT
  TO authenticated
  USING (true);

-- RLS: tipos_incidente
ALTER TABLE tipos_incidente ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Catálogos visibles para usuarios autenticados"
  ON tipos_incidente FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================
-- Tabla principal: incidentes (sin campo JSONB acciones_correctivas)
CREATE TABLE IF NOT EXISTS public.incidentes (
  id SERIAL PRIMARY KEY,
  -- Reportante: siempre un perfil de usuario (UUID)
  usuario_reportante_id uuid NOT NULL REFERENCES perfiles(id),
  -- Supervisor asignado: siempre un trabajador del contrato (INTEGER)
  supervisor_trabajador_id integer REFERENCES trabajadores(id),
  tipo_incidente_id integer NOT NULL REFERENCES tipos_incidente(id),
  area_id integer NOT NULL REFERENCES areas(id),
  titulo text NOT NULL,
  descripcion text,
  -- Fechas con control de consistencia
  fecha_reporte timestamp DEFAULT now(),
  fecha_incidente date NOT NULL,
  -- Estados con validación PHVA
  estado text DEFAULT 'abierto' CHECK (estado IN ('abierto', 'en_investigacion', 'cerrado', 'archivado')),
  severidad text DEFAULT 'baja' CHECK (severidad IN ('baja', 'media', 'alta', 'critica')),
  -- Archivos adjuntos (fotos)
  fotos text[] DEFAULT '{}',
  -- Soft delete (inmutabilidad)
  created_at timestamp DEFAULT now(),
  updated_at timestamp DEFAULT now(),
  deleted_at timestamp DEFAULT NULL
);

-- ============================================================
-- RLS: incidentes
ALTER TABLE incidentes ENABLE ROW LEVEL SECURITY;

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

-- Índices
CREATE INDEX IF NOT EXISTS idx_incidentes_estado ON incidentes(estado);
CREATE INDEX IF NOT EXISTS idx_incidentes_usuario ON incidentes(usuario_reportante_id);
CREATE INDEX IF NOT EXISTS idx_incidentes_supervisor ON incidentes(supervisor_trabajador_id);
CREATE INDEX IF NOT EXISTS idx_incidentes_fecha ON incidentes(fecha_incidente);

-- ============================================================
-- PASO 4/5: TABLAS AUXILIARES
-- ============================================================

-- 4.1 TABLA: acciones_correctivas (estructura relacional, sin duplicado JSONB en incidentes)
CREATE TABLE IF NOT EXISTS public.acciones_correctivas (
  id SERIAL PRIMARY KEY,
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
-- 4.2 TABLA: auditoria_cumplimiento (Audit Trail - inmutable)
CREATE TABLE IF NOT EXISTS public.auditoria_cumplimiento (
  id SERIAL PRIMARY KEY,
  tabla_afectada text NOT NULL,
  registro_id integer NOT NULL,
  operacion text NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
  usuario_id uuid,
  usuario_nombre text,
  valor_anterior jsonb,
  valor_nuevo jsonb,
  ip_address text,
  created_at timestamp DEFAULT now()
);

-- RLS: auditoria (solo lectura para admin)
ALTER TABLE auditoria_cumplimiento ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Auditoría visible solo para admin"
  ON auditoria_cumplimiento FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin')
  );

-- ============================================================
-- 4.3 TRIGGER: actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION public.actualizar_timestamp()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_actualizar_timestamp_trabajadores') THEN
    CREATE TRIGGER trg_actualizar_timestamp_trabajadores
      BEFORE UPDATE ON trabajadores
      FOR EACH ROW EXECUTE FUNCTION public.actualizar_timestamp();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_actualizar_timestamp_cumplimiento') THEN
    CREATE TRIGGER trg_actualizar_timestamp_cumplimiento
      BEFORE UPDATE ON cumplimiento_trabajadores
      FOR EACH ROW EXECUTE FUNCTION public.actualizar_timestamp();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_actualizar_timestamp_incidentes') THEN
    CREATE TRIGGER trg_actualizar_timestamp_incidentes
      BEFORE UPDATE ON incidentes
      FOR EACH ROW EXECUTE FUNCTION public.actualizar_timestamp();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_actualizar_timestamp_acciones') THEN
    CREATE TRIGGER trg_actualizar_timestamp_acciones
      BEFORE UPDATE ON acciones_correctivas
      FOR EACH ROW EXECUTE FUNCTION public.actualizar_timestamp();
  END IF;
END $$;

-- ============================================================
-- 4.4 TRIGGER: Auditoría automática para cumplimiento_trabajadores
CREATE OR REPLACE FUNCTION public.auditar_cumplimiento()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.auditoria_cumplimiento (
    tabla_afectada, registro_id, operacion, usuario_id,
    usuario_nombre, valor_anterior, valor_nuevo
  ) VALUES (
    'cumplimiento_trabajadores',
    COALESCE(NEW.id, OLD.id),
    TG_OP,
    auth.uid(),
    COALESCE((SELECT nombre_completo FROM public.perfiles WHERE id = auth.uid()), 'Sistema'),
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN
      row_to_json(OLD)::jsonb
    ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN
      row_to_json(NEW)::jsonb
    ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_auditar_cumplimiento_insert') THEN
    CREATE TRIGGER trg_auditar_cumplimiento_insert
      AFTER INSERT ON cumplimiento_trabajadores
      FOR EACH ROW EXECUTE FUNCTION public.auditar_cumplimiento();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_auditar_cumplimiento_update') THEN
    CREATE TRIGGER trg_auditar_cumplimiento_update
      AFTER UPDATE ON cumplimiento_trabajadores
      FOR EACH ROW EXECUTE FUNCTION public.auditar_cumplimiento();
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_auditar_cumplimiento_delete') THEN
    CREATE TRIGGER trg_auditar_cumplimiento_delete
      AFTER DELETE ON cumplimiento_trabajadores
      FOR EACH ROW EXECUTE FUNCTION public.auditar_cumplimiento();
  END IF;
END $$;

-- ============================================================
-- 4.5 TRIGGER: Regla de negocio - N/A limpia fecha_vencimiento
CREATE OR REPLACE FUNCTION public.validar_consistencia_cumplimiento()
RETURNS trigger AS $$
BEGIN
  -- Si valor_estado es 'N/A' → limpiar fecha_vencimiento
  IF NEW.valor_estado = 'N/A' THEN
    NEW.fecha_vencimiento := NULL;
  END IF;

  -- Si estado es 'VENCIDO' y fecha_vencimiento es futura → error
  IF NEW.valor_estado = 'VENCIDO' AND NEW.fecha_vencimiento IS NOT NULL AND NEW.fecha_vencimiento > CURRENT_DATE THEN
    RAISE EXCEPTION 'Estado VENCIDO no permitido con fecha_vencimiento futura (%)', NEW.fecha_vencimiento;
  END IF;

  -- Si fecha_vencimiento es pasada y estado ≠ 'VENCIDO' y ≠ 'N/A' → auto-marcar VENCIDO
  IF NEW.fecha_vencimiento IS NOT NULL 
     AND NEW.fecha_vencimiento < CURRENT_DATE 
     AND NEW.valor_estado NOT IN ('VENCIDO', 'N/A') THEN
    NEW.valor_estado := 'VENCIDO';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_validar_consistencia_cumplimiento') THEN
    CREATE TRIGGER trg_validar_consistencia_cumplimiento
      BEFORE INSERT OR UPDATE ON cumplimiento_trabajadores
      FOR EACH ROW EXECUTE FUNCTION public.validar_consistencia_cumplimiento();
  END IF;
END $$;

-- ============================================================
-- 4.6 VISTA SILVER: cumplimiento_limpio (datos limpios y tipados)
CREATE OR REPLACE VIEW public.v_cumplimiento_silver AS
SELECT
  ct.id,
  t.id as trabajador_id,
  t.rut,
  t.nombre,
  t.apellido_paterno,
  t.apellido_materno,
  t.cargo,
  t.empresa,
  t.contrato_codigo,
  t.estado_trabajador,
  r.id as requisito_id,
  r.nombre_requisito,
  ct.valor_estado,
  ct.fecha_vencimiento,
  CASE
    WHEN ct.valor_estado = 'N/A' THEN 'N/A'
    WHEN ct.fecha_vencimiento IS NULL THEN ct.valor_estado
    WHEN ct.fecha_vencimiento < CURRENT_DATE THEN 'VENCIDO'
    WHEN ct.fecha_vencimiento <= CURRENT_DATE + INTERVAL '30 days' THEN 'POR_VENCER'
    ELSE 'VIGENTE'
  END as estado_vencimiento,
  ct.documento_url,
  ct.updated_at as fecha_actualizacion
FROM cumplimiento_trabajadores ct
JOIN trabajadores t ON t.id = ct.trabajador_id
JOIN requisitos_hse r ON r.id = ct.requisito_id
WHERE ct.deleted_at IS NULL
  AND t.deleted_at IS NULL;

-- ============================================================
-- 4.7 VISTA GOLD: dashboard_cumplimiento (agregada para analítica)
CREATE OR REPLACE VIEW public.v_dashboard_cumplimiento_gold AS
SELECT
  t.empresa,
  t.contrato_codigo,
  COUNT(DISTINCT t.id) as total_trabajadores,
  COUNT(DISTINCT ct.trabajador_id) FILTER (WHERE ct.valor_estado = 'VIGENTE') as con_cumplimiento_total,
  COUNT(DISTINCT ct.trabajador_id) FILTER (WHERE ct.valor_estado = 'VENCIDO') as con_brechas,
  ROUND(
    100.0 * COUNT(DISTINCT ct.trabajador_id) FILTER (WHERE ct.valor_estado = 'VIGENTE')
    / NULLIF(COUNT(DISTINCT t.id), 0), 1
  ) as porcentaje_cumplimiento,
  COUNT(*) FILTER (WHERE ct.valor_estado = 'VENCIDO') as total_vencidos,
  COUNT(*) FILTER (WHERE ct.fecha_vencimiento <= CURRENT_DATE + INTERVAL '30 days') as total_por_vencer
FROM trabajadores t
LEFT JOIN cumplimiento_trabajadores ct ON t.id = ct.trabajador_id AND ct.deleted_at IS NULL
WHERE t.deleted_at IS NULL
  AND t.estado_trabajador = 'ACTIVO'
GROUP BY t.empresa, t.contrato_codigo;

-- ============================================================
-- PASO 5/5: RPCs TRANSACCIONALES (ACID)
-- ============================================================

-- 5.1 RPC: sincronizar perfil de usuario con trabajador
DROP FUNCTION IF EXISTS public.sincronizar_trabajador_actual();
CREATE OR REPLACE FUNCTION public.sincronizar_trabajador_actual()
RETURNS jsonb AS $$
DECLARE
  v_user_id uuid;
  v_user_rut text;
  v_trabajador_id integer;
  v_resultado jsonb;
BEGIN
  v_user_id := auth.uid();
  
  -- Obtener RUT del metadata del usuario
  SELECT COALESCE(raw_user_meta_data ->> 'rut', '') INTO v_user_rut
  FROM auth.users WHERE id = v_user_id;
  
  IF v_user_rut = '' THEN
    RETURN jsonb_build_object(
      'exito', false,
      'mensaje', 'El usuario no tiene RUT configurado en sus metadatos'
    );
  END IF;
  
  -- Buscar trabajador por RUT
  SELECT id INTO v_trabajador_id
  FROM trabajadores
  WHERE rut = v_user_rut AND deleted_at IS NULL;
  
  IF v_trabajador_id IS NULL THEN
    RETURN jsonb_build_object(
      'exito', false,
      'mensaje', 'No se encontró trabajador con RUT: ' || v_user_rut
    );
  END IF;
  
  -- Actualizar perfil con el trabajador_id
  UPDATE perfiles
  SET trabajador_id = v_trabajador_id
  WHERE id = v_user_id;
  
  RETURN jsonb_build_object(
    'exito', true,
    'mensaje', 'Perfil vinculado al trabajador correctamente',
    'trabajador_id', v_trabajador_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.2 RPC: actualizar cumplimiento seguro (transacción ACID)
DROP FUNCTION IF EXISTS public.actualizar_cumplimiento_seguro(integer, integer, text, date, text);
CREATE OR REPLACE FUNCTION public.actualizar_cumplimiento_seguro(
  p_trabajador_id integer,
  p_requisito_id integer,
  p_valor_estado text,
  p_fecha_vencimiento date DEFAULT NULL,
  p_documento_url text DEFAULT ''
)
RETURNS jsonb AS $$
DECLARE
  v_existente_id integer;
  v_resultado jsonb;
BEGIN
  -- Validar que el estado sea uno de los normalizados
  IF p_valor_estado NOT IN ('VIGENTE', 'VENCIDO', 'N/A') THEN
    RAISE EXCEPTION 'Estado inválido: %. Solo se permite VIGENTE, VENCIDO, N/A', p_valor_estado;
  END IF;

  -- Validar que el trabajador exista
  IF NOT EXISTS (SELECT 1 FROM trabajadores WHERE id = p_trabajador_id AND deleted_at IS NULL) THEN
    RAISE EXCEPTION 'Trabajador % no encontrado o eliminado', p_trabajador_id;
  END IF;

  -- Validar que el requisito exista
  IF NOT EXISTS (SELECT 1 FROM requisitos_hse WHERE id = p_requisito_id) THEN
    RAISE EXCEPTION 'Requisito HSE % no encontrado', p_requisito_id;
  END IF;

  -- Validar consistencia de fechas
  IF p_valor_estado = 'VENCIDO' AND p_fecha_vencimiento IS NOT NULL AND p_fecha_vencimiento > CURRENT_DATE THEN
    RAISE EXCEPTION 'No se puede marcar como VENCIDO con fecha futura: %', p_fecha_vencimiento;
  END IF;

  -- Si es N/A, limpiar fecha
  IF p_valor_estado = 'N/A' THEN
    p_fecha_vencimiento := NULL;
  END IF;

  -- UPSERT con transacción segura
  INSERT INTO cumplimiento_trabajadores (trabajador_id, requisito_id, valor_estado, fecha_vencimiento, documento_url, usuario_registra_id)
  VALUES (p_trabajador_id, p_requisito_id, p_valor_estado, p_fecha_vencimiento, p_documento_url, auth.uid())
  ON CONFLICT (trabajador_id, requisito_id)
  DO UPDATE SET
    valor_estado = EXCLUDED.valor_estado,
    fecha_vencimiento = EXCLUDED.fecha_vencimiento,
    documento_url = EXCLUDED.documento_url,
    usuario_registra_id = EXCLUDED.usuario_registra_id,
    updated_at = now()
  RETURNING id INTO v_existente_id;

  v_resultado := jsonb_build_object(
    'exito', true,
    'mensaje', 'Cumplimiento actualizado',
    'cumplimiento_id', v_existente_id,
    'trabajador_id', p_trabajador_id,
    'requisito_id', p_requisito_id,
    'nuevo_estado', p_valor_estado
  );

  RETURN v_resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.3 RPC: actualizar cumplimiento masivo
DROP FUNCTION IF EXISTS public.actualizar_cumplimiento_masivo(integer, jsonb);
CREATE OR REPLACE FUNCTION public.actualizar_cumplimiento_masivo(
  p_trabajador_id integer,
  p_estados jsonb
)
RETURNS jsonb AS $$
DECLARE
  v_item jsonb;
  v_exitos integer := 0;
  v_errores integer := 0;
  v_detalle_errores jsonb := '[]'::jsonb;
BEGIN
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_estados)
  LOOP
    BEGIN
      PERFORM public.actualizar_cumplimiento_seguro(
        p_trabajador_id,
        (v_item->>'requisito_id')::integer,
        v_item->>'valor_estado',
        CASE WHEN v_item->>'fecha_vencimiento' IS NOT NULL AND v_item->>'fecha_vencimiento' != ''
             THEN (v_item->>'fecha_vencimiento')::date
             ELSE NULL END,
        COALESCE(v_item->>'documento_url', '')
      );
      v_exitos := v_exitos + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errores := v_errores + 1;
      v_detalle_errores := v_detalle_errores || jsonb_build_object(
        'requisito_id', v_item->>'requisito_id',
        'error', SQLERRM
      );
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'exito', v_errores = 0,
    'total', jsonb_array_length(p_estados),
    'exitosos', v_exitos,
    'errores', v_errores,
    'detalle_errores', v_detalle_errores
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.4 RPC: crear incidente con acciones correctivas
DROP FUNCTION IF EXISTS public.crear_incidente_con_acciones(integer, integer, text, text, date, text, integer, text[], jsonb);
CREATE OR REPLACE FUNCTION public.crear_incidente_con_acciones(
  p_tipo_incidente_id integer,
  p_area_id integer,
  p_titulo text,
  p_descripcion text DEFAULT '',
  p_fecha_incidente date DEFAULT CURRENT_DATE,
  p_severidad text DEFAULT 'baja',
  p_supervisor_trabajador_id integer DEFAULT NULL,
  p_fotos text[] DEFAULT '{}',
  p_acciones jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb AS $$
DECLARE
  v_incidente_id integer;
  v_accion jsonb;
  v_resultado jsonb;
BEGIN
  -- Crear incidente (sin columna JSONB de acciones)
  INSERT INTO incidentes (
    usuario_reportante_id, tipo_incidente_id, area_id,
    titulo, descripcion, fecha_incidente,
    severidad, supervisor_trabajador_id, fotos
  ) VALUES (
    auth.uid(), p_tipo_incidente_id, p_area_id,
    p_titulo, p_descripcion, p_fecha_incidente,
    p_severidad, p_supervisor_trabajador_id, p_fotos
  ) RETURNING id INTO v_incidente_id;

  -- Crear acciones correctivas en tabla independiente
  IF jsonb_array_length(p_acciones) > 0 THEN
    FOR v_accion IN SELECT * FROM jsonb_array_elements(p_acciones)
    LOOP
      INSERT INTO acciones_correctivas (
        incidente_id, descripcion, fecha_limite,
        prioridad, estado, trabajador_asignado_id
      ) VALUES (
        v_incidente_id,
        v_accion->>'descripcion',
        COALESCE((v_accion->>'fecha_limite')::date, CURRENT_DATE + INTERVAL '15 days'),
        COALESCE(v_accion->>'prioridad', 'media'),
        'pendiente',
        (v_accion->>'trabajador_asignado_id')::integer
      );
    END LOOP;
  END IF;

  v_resultado := jsonb_build_object(
    'exito', true,
    'mensaje', 'Incidente y acciones creadas',
    'incidente_id', v_incidente_id,
    'acciones_creadas', jsonb_array_length(p_acciones)
  );

  RETURN v_resultado;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5.5 RPC: obtener dashboard cumplimiento
DROP FUNCTION IF EXISTS public.obtener_dashboard_cumplimiento(text);
CREATE OR REPLACE FUNCTION public.obtener_dashboard_cumplimiento(
  p_empresa text DEFAULT NULL
)
RETURNS TABLE (
  empresa text,
  contrato_codigo text,
  total_trabajadores bigint,
  cumplimiento_total bigint,
  con_brechas bigint,
  porcentaje_cumplimiento numeric,
  total_vencidos bigint,
  total_por_vencer bigint
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM v_dashboard_cumplimiento_gold d
  WHERE (p_empresa IS NULL OR d.empresa = p_empresa)
  ORDER BY d.porcentaje_cumplimiento;
END;
$$ LANGUAGE plpgsql STABLE;