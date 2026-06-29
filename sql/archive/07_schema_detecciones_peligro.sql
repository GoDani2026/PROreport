-- ============================================================
-- PROreport - Módulo: Detecciones de Peligro
-- Versión: 1.0
-- ============================================================
-- INSTRUCCIONES:
-- 1. Ir a: https://supabase.com/dashboard/project/inleckebqssizgeovgov
-- 2. SQL Editor → New Query
-- 3. Pegar TODO este archivo y ejecutar
-- ============================================================
-- NOTA: Las tablas `areas`, `perfiles` y `trabajadores` YA EXISTEN.
-- Este script crea SOLO la tabla transaccional `detecciones_peligro`.
-- ============================================================

-- ============================================================
-- PASO 1/5: TABLA PRINCIPAL - detecciones_peligro
-- ============================================================
CREATE TABLE IF NOT EXISTS public.detecciones_peligro (
  id SERIAL PRIMARY KEY,

  -- ════════════════════════════════════════════════════════════
  -- IDENTIFICACIÓN
  -- ════════════════════════════════════════════════════════════
  usuario_reportante_id UUID NOT NULL REFERENCES perfiles(id),
  area_id INTEGER NOT NULL REFERENCES areas(id),
  turno TEXT NOT NULL,                   -- Se copia automáticamente del trabajador reportante
  lugar_exacto TEXT NOT NULL,

  -- ════════════════════════════════════════════════════════════
  -- HALLAZGO (El "Antes")
  -- ════════════════════════════════════════════════════════════
  foto_evidencia_url TEXT,
  descripcion_hallazgo TEXT,
  nivel_atencion_lgf TEXT NOT NULL CHECK (nivel_atencion_lgf IN ('BAJO', 'MEDIO', 'SIGNIFICATIVO')),
  accion_inmediata TEXT,

  -- ════════════════════════════════════════════════════════════
  -- SEGUIMIENTO Y COMPROMISO
  -- ════════════════════════════════════════════════════════════
  estatus_seguimiento TEXT NOT NULL DEFAULT 'Pendiente'
      CHECK (estatus_seguimiento IN ('Pendiente', 'En Ejecución', 'Eliminada')),
  supervisor_responsable_id INTEGER REFERENCES trabajadores(id),
  plan_accion TEXT,                      -- Acciones tomadas o planeadas al iniciar ejecución
  fecha_compromiso_eliminacion DATE,     -- Ingresada manualmente por el supervisor

  -- ════════════════════════════════════════════════════════════
  -- CIERRE (El "Después")
  -- ════════════════════════════════════════════════════════════
  resumen_cierre TEXT,
  foto_cierre_url TEXT,

  -- ════════════════════════════════════════════════════════════
  -- NOTARIO DIGITAL
  -- ════════════════════════════════════════════════════════════
  created_at TIMESTAMP DEFAULT now(),    -- Fecha de inicio automática
  updated_at TIMESTAMP DEFAULT now(),
  fecha_cierre TIMESTAMP,                -- Nulo hasta que pase a 'Eliminada'

  -- ════════════════════════════════════════════════════════════
  -- SISTEMA
  -- ════════════════════════════════════════════════════════════
  url_pdf_evolutivo TEXT
);

-- ============================================================
-- PASO 2/5: POLÍTICAS RLS (Row Level Security)
-- ============================================================
ALTER TABLE detecciones_peligro ENABLE ROW LEVEL SECURITY;

-- Política: SELECT - visible para todos los usuarios autenticados
CREATE POLICY "Detecciones visibles para usuarios autenticados"
  ON detecciones_peligro FOR SELECT
  TO authenticated
  USING (true);

-- Política: INSERT - cualquier autenticado puede crear
CREATE POLICY "Usuarios pueden crear detecciones"
  ON detecciones_peligro FOR INSERT
  TO authenticated
  WITH CHECK (usuario_reportante_id = auth.uid());

-- Política: UPDATE - el reportante o admin/supervisor pueden actualizar
CREATE POLICY "Reportante o admin/supervisor puede actualizar"
  ON detecciones_peligro FOR UPDATE
  TO authenticated
  USING (
    usuario_reportante_id = auth.uid() OR
    EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor'))
  );

-- ============================================================
-- PASO 3/5: ÍNDICES PARA OPTIMIZACIÓN
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_detecciones_estatus ON detecciones_peligro(estatus_seguimiento);
CREATE INDEX IF NOT EXISTS idx_detecciones_usuario ON detecciones_peligro(usuario_reportante_id);
CREATE INDEX IF NOT EXISTS idx_detecciones_supervisor ON detecciones_peligro(supervisor_responsable_id);
CREATE INDEX IF NOT EXISTS idx_detecciones_area ON detecciones_peligro(area_id);
CREATE INDEX IF NOT EXISTS idx_detecciones_fecha_compromiso ON detecciones_peligro(fecha_compromiso_eliminacion);

-- ============================================================
-- PASO 4/5: FUNCIONES RPC (Remote Procedure Calls)
-- ============================================================

-- ------------------------------------------------------------
-- RPC 1: iniciar_ejecucion_peligro
-- Actualiza estatus a 'En Ejecución', asigna supervisor,
-- guarda plan_accion y fecha_compromiso_eliminacion.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.iniciar_ejecucion_peligro(
  p_deteccion_id INTEGER,
  p_supervisor_id INTEGER,
  p_plan_accion TEXT,
  p_fecha_compromiso DATE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.detecciones_peligro
  SET
    estatus_seguimiento = 'En Ejecución',
    supervisor_responsable_id = p_supervisor_id,
    plan_accion = p_plan_accion,
    fecha_compromiso_eliminacion = p_fecha_compromiso,
    updated_at = now()
  WHERE id = p_deteccion_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Detección con id % no encontrada', p_deteccion_id;
  END IF;
END;
$$;

-- ------------------------------------------------------------
-- RPC 2: cerrar_peligro
-- Actualiza estatus a 'Eliminada', guarda resumen_cierre y
-- foto_cierre_url, y estampa atómicamente fecha_cierre con NOW().
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cerrar_peligro(
  p_deteccion_id INTEGER,
  p_resumen_cierre TEXT,
  p_foto_cierre_url TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.detecciones_peligro
  SET
    estatus_seguimiento = 'Eliminada',
    resumen_cierre = p_resumen_cierre,
    foto_cierre_url = p_foto_cierre_url,
    fecha_cierre = now(),
    updated_at = now()
  WHERE id = p_deteccion_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Detección con id % no encontrada', p_deteccion_id;
  END IF;
END;
$$;

-- ============================================================
-- PASO 5/5: TRIGGER PARA ACTUALIZAR updated_at
-- Reutiliza la función existente `actualizar_timestamp()` del
-- esquema base, o la crea si no existe.
-- ============================================================
CREATE OR REPLACE FUNCTION public.actualizar_timestamp()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_actualizar_timestamp_detecciones'
  ) THEN
    CREATE TRIGGER trg_actualizar_timestamp_detecciones
      BEFORE UPDATE ON detecciones_peligro
      FOR EACH ROW
      EXECUTE FUNCTION public.actualizar_timestamp();
  END IF;
END $$;