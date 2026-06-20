"""
Script para generar el SQL de migración de IDs UUID → SERIAL.

Uso:
  python scripts/migrar_ids_sql.py > scripts/migrar_ids_supabase.sql

El SQL generado:
  1. Crea tablas temporales con los datos actuales.
  2. Recrea trabajadores e IDs secuenciales manteniendo el RUT como clave única.
  3. Recrea cumplimiento_trabajadores usando los nuevos IDs.
  4. Restaura RLS, triggers, índices y políticas.
  5. Deja una tabla temporal para auditoría del mapeo de IDs antiguos a nuevos.

IMPORTANTE:
  - Ejecutar con rol con permisos de administrador/owner.
  - Hacer backup antes de ejecutar.
  - En Supabase, ejecutar en SQL Editor.
"""

from datetime import datetime

SQL = f"""
-- ============================================================
-- MIGRACIÓN: IDs UUID → SERIAL
-- Generado: {datetime.now().isoformat(timespec='seconds')}
-- ============================================================

BEGIN;

-- 0) Seguridad: solo migrar si las tablas existen y tienen el esquema actual UUID.
DO $$
BEGIN
  IF to_regclass('public.trabajadores') IS NULL THEN
    RAISE EXCEPTION 'La tabla public.trabajadores no existe.';
  END IF;

  IF to_regclass('public.cumplimiento_trabajadores') IS NULL THEN
    RAISE EXCEPTION 'La tabla public.cumplimiento_trabajadores no existe.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'trabajadores'
      AND column_name = 'id'
      AND data_type <> 'integer'
  ) THEN
    RAISE NOTICE 'Migrando trabajadores.id desde tipo no entero.';
  END IF;
END $$;

-- 1) Guardar datos actuales en tablas temporales.
DROP TABLE IF EXISTS tmp_trabajadores_old;
CREATE TEMP TABLE tmp_trabajadores_old AS
SELECT * FROM public.trabajadores;

DROP TABLE IF EXISTS tmp_cumplimiento_old;
CREATE TEMP TABLE tmp_cumplimiento_old AS
SELECT * FROM public.cumplimiento_trabajadores;

DROP TABLE IF EXISTS tmp_requisitos_old;
CREATE TEMP TABLE tmp_requisitos_old AS
SELECT * FROM public.requisitos_hse;

-- 2) Crear mapeo de IDs antiguos a nuevos IDs secuenciales.
DROP TABLE IF EXISTS tmp_trabajadores_id_map;
CREATE TEMP TABLE tmp_trabajadores_id_map AS
SELECT
  row_number() OVER (ORDER BY id) AS nuevo_id,
  id AS id_antiguo_uuid,
  rut
FROM tmp_trabajadores_old;

-- 3) Eliminar dependencias FK existentes.
ALTER TABLE IF EXISTS public.cumplimiento_trabajadores
  DROP CONSTRAINT IF EXISTS cumplimiento_trabajadores_trabajador_id_fkey;

ALTER TABLE IF EXISTS public.cumplimiento_trabajadores
  DROP CONSTRAINT IF EXISTS cumplimiento_trabajadores_requisito_id_fkey;

ALTER TABLE IF EXISTS public.cumplimiento_trabajadores
  DROP CONSTRAINT IF EXISTS unique_trabajador_requisito;

DROP INDEX IF EXISTS public.idx_cumplimiento_trabajador;
DROP INDEX IF EXISTS public.idx_cumplimiento_requisito;
DROP INDEX IF EXISTS public.idx_cumplimiento_estado;

-- 4) Recrear tabla trabajadores con SERIAL.
DROP TABLE IF EXISTS public.trabajadores CASCADE;

CREATE TABLE public.trabajadores (
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

INSERT INTO public.trabajadores (
  id,
  rut,
  nombre,
  apellido_paterno,
  apellido_materno,
  cargo,
  nacionalidad,
  vencimiento_residencia,
  sexo,
  turno,
  estado_trabajador,
  contrato_codigo,
  created_at,
  updated_at
)
SELECT
  m.nuevo_id,
  o.rut,
  o.nombre,
  o.apellido_paterno,
  o.apellido_materno,
  o.cargo,
  o.nacionalidad,
  o.vencimiento_residencia,
  o.sexo,
  o.turno,
  o.estado_trabajador,
  o.contrato_codigo,
  o.created_at,
  o.updated_at
FROM tmp_trabajadores_old o
JOIN tmp_trabajadores_id_map m ON m.id_antiguo_uuid = o.id
ORDER BY m.nuevo_id;

-- Reiniciar secuencia para que el próximo ID sea mayor al último migrado.
SELECT setval(
  pg_get_serial_sequence('public.trabajadores', 'id'),
  COALESCE((SELECT MAX(id) FROM public.trabajadores), 0) + 1,
  false
);

-- 5) Recrear tabla cumplimiento_trabajadores con SERIAL.
DROP TABLE IF EXISTS public.cumplimiento_trabajadores CASCADE;

CREATE TABLE public.cumplimiento_trabajadores (
  id serial PRIMARY KEY,
  trabajador_id integer NOT NULL REFERENCES public.trabajadores(id) ON DELETE CASCADE,
  requisito_id integer NOT NULL REFERENCES public.requisitos_hse(id) ON DELETE RESTRICT,
  valor_estado text NOT NULL CHECK (valor_estado IN ('VIGENTE', 'SI', 'NO', 'N/A', 'VENCIDO')),
  fecha_vencimiento date,
  documento_url text,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT unique_trabajador_requisito UNIQUE (trabajador_id, requisito_id)
);

INSERT INTO public.cumplimiento_trabajadores (
  id,
  trabajador_id,
  requisito_id,
  valor_estado,
  fecha_vencimiento,
  documento_url,
  updated_at
)
SELECT
  row_number() OVER (ORDER BY o.id) AS id,
  m.nuevo_id AS trabajador_id,
  o.requisito_id,
  o.valor_estado,
  o.fecha_vencimiento,
  o.documento_url,
  o.updated_at
FROM tmp_cumplimiento_old o
JOIN tmp_trabajadores_id_map m ON m.id_antiguo_uuid = o.trabajador_id
ORDER BY o.id;

-- Reiniciar secuencia para cumplimiento.
SELECT setval(
  pg_get_serial_sequence('public.cumplimiento_trabajadores', 'id'),
  COALESCE((SELECT MAX(id) FROM public.cumplimiento_trabajadores), 0) + 1,
  false
);

-- 6) Recrear índices.
CREATE INDEX IF NOT EXISTS idx_trabajadores_rut ON public.trabajadores(rut);
CREATE INDEX IF NOT EXISTS idx_trabajadores_estado ON public.trabajadores(estado_trabajador);
CREATE INDEX IF NOT EXISTS idx_trabajadores_contrato ON public.trabajadores(contrato_codigo);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_trabajador ON public.cumplimiento_trabajadores(trabajador_id);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_requisito ON public.cumplimiento_trabajadores(requisito_id);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_estado ON public.cumplimiento_trabajadores(valor_estado);

-- 7) Recrear triggers de updated_at.
CREATE OR REPLACE FUNCTION public.handle_updated_at_trabajadores()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_trabajadores_updated ON public.trabajadores;
CREATE TRIGGER on_trabajadores_updated
  BEFORE UPDATE ON public.trabajadores
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_trabajadores();

CREATE OR REPLACE FUNCTION public.handle_updated_at_cumplimiento()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_cumplimiento_updated ON public.cumplimiento_trabajadores;
CREATE TRIGGER on_cumplimiento_updated
  BEFORE UPDATE ON public.cumplimiento_trabajadores
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_cumplimiento();

-- 8) Recrear RLS y políticas.
ALTER TABLE public.trabajadores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.requisitos_hse ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cumplimiento_trabajadores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Usuarios autenticados pueden ver trabajadores" ON public.trabajadores;
CREATE POLICY "Usuarios autenticados pueden ver trabajadores"
  ON public.trabajadores FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar trabajadores" ON public.trabajadores;
CREATE POLICY "Usuarios autenticados pueden insertar trabajadores"
  ON public.trabajadores FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar trabajadores" ON public.trabajadores;
CREATE POLICY "Usuarios autenticados pueden actualizar trabajadores"
  ON public.trabajadores FOR UPDATE
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar trabajadores" ON public.trabajadores;
CREATE POLICY "Usuarios autenticados pueden eliminar trabajadores"
  ON public.trabajadores FOR DELETE
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Requisitos HSE visibles para usuarios autenticados" ON public.requisitos_hse;
CREATE POLICY "Requisitos HSE visibles para usuarios autenticados"
  ON public.requisitos_hse FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden ver cumplimiento" ON public.cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden ver cumplimiento"
  ON public.cumplimiento_trabajadores FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar cumplimiento" ON public.cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden insertar cumplimiento"
  ON public.cumplimiento_trabajadores FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar cumplimiento" ON public.cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden actualizar cumplimiento"
  ON public.cumplimiento_trabajadores FOR UPDATE
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar cumplimiento" ON public.cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden eliminar cumplimiento"
  ON public.cumplimiento_trabajadores FOR DELETE
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Acceso anon a trabajadores" ON public.trabajadores;
CREATE POLICY "Acceso anon a trabajadores"
  ON public.trabajadores FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Acceso anon a requisitos_hse" ON public.requisitos_hse;
CREATE POLICY "Acceso anon a requisitos_hse"
  ON public.requisitos_hse FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS "Acceso anon a cumplimiento_trabajadores" ON public.cumplimiento_trabajadores;
CREATE POLICY "Acceso anon a cumplimiento_trabajadores"
  ON public.cumplimiento_trabajadores FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- 9) Recrear función de consulta de cumplimiento completo.
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
    t.id AS trabajador_id,
    t.rut,
    t.nombre,
    t.apellido_paterno,
    t.apellido_materno,
    t.cargo,
    t.estado_trabajador,
    r.id AS requisito_id,
    r.nombre_requisito,
    ct.valor_estado,
    ct.fecha_vencimiento,
    ct.documento_url
  FROM public.trabajadores t
  CROSS JOIN public.requisitos_hse r
  LEFT JOIN public.cumplimiento_trabajadores ct
    ON t.id = ct.trabajador_id
   AND r.id = ct.requisito_id
  WHERE t.id = p_trabajador_id
  ORDER BY r.id;
END;
$$ LANGUAGE plpgsql STABLE;

-- 10) Auditoría temporal: mapeo de IDs antiguos a nuevos.
-- Esta tabla temporal desaparecerá al terminar la sesión SQL.
SELECT
  nuevo_id AS trabajador_id_nuevo,
  id_antiguo_uuid AS trabajador_id_anterior,
  rut
FROM tmp_trabajadores_id_map
ORDER BY nuevo_id;

COMMIT;
"""

if __name__ == "__main__":
    import sys

    sys.stdout.reconfigure(encoding="utf-8")
    print(SQL)
