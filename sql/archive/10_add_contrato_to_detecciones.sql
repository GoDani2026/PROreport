-- ============================================================
-- PROreport - 10. Migración: Área → Código de Contrato
-- ------------------------------------------------------------
-- Reemplaza el campo area_id en detecciones_peligro por
-- contrato_codigo, y actualiza las políticas RLS para
-- soporte multi-contrato + bypass de Súper Administrador.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. ELIMINAR COLUMNA area_id Y AGREGAR contrato_codigo
-- ============================================================

-- 1a. Eliminar el índice anterior de area_id
DROP INDEX IF EXISTS public.idx_detecciones_area;

-- 1b. Eliminar la columna area_id y su restricción
ALTER TABLE public.detecciones_peligro
  DROP COLUMN IF EXISTS area_id;

-- 1c. Agregar la nueva columna contrato_codigo
ALTER TABLE public.detecciones_peligro
  ADD COLUMN contrato_codigo TEXT NOT NULL
  REFERENCES public.contratos(codigo)
  ON DELETE CASCADE;

-- 1d. Crear índice para búsquedas por contrato
CREATE INDEX IF NOT EXISTS idx_detecciones_contrato
  ON public.detecciones_peligro(contrato_codigo);

-- ============================================================
-- 2. ACTUALIZAR POLÍTICAS RLS (Row Level Security)
-- ============================================================

-- 2a. Eliminar políticas anteriores que referenciaban area_id
DROP POLICY IF EXISTS "Detecciones visibles para usuarios autenticados"
  ON public.detecciones_peligro;
DROP POLICY IF EXISTS "Usuarios pueden crear detecciones"
  ON public.detecciones_peligro;
DROP POLICY IF EXISTS "Reportante o admin/supervisor puede actualizar"
  ON public.detecciones_peligro;

-- 2b. Política SELECT:
--     - superadmin: bypass total (ve todos los contratos)
--     - trabajador común: solo sus contratos asignados
CREATE POLICY "Select detecciones por contrato y rol"
  ON public.detecciones_peligro FOR SELECT
  TO authenticated
  USING (
    -- Súper Administrador: bypass total
    EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE id = auth.uid()
        AND rol = 'superadmin'
    )
    OR
    -- Trabajador común: solo contratos asignados
    EXISTS (
      SELECT 1 FROM public.trabajador_contratos tc
      JOIN public.perfiles p ON p.trabajador_id = tc.trabajador_id
      WHERE p.id = auth.uid()
        AND tc.contrato_codigo = detecciones_peligro.contrato_codigo
    )
  );

-- 2c. Política INSERT:
--     - superadmin: puede insertar en cualquier contrato
--     - trabajador: solo en sus contratos asignados
CREATE POLICY "Insert detecciones por contrato y rol"
  ON public.detecciones_peligro FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE id = auth.uid()
        AND rol = 'superadmin'
    )
    OR
    EXISTS (
      SELECT 1 FROM public.trabajador_contratos tc
      JOIN public.perfiles p ON p.trabajador_id = tc.trabajador_id
      WHERE p.id = auth.uid()
        AND tc.contrato_codigo = detecciones_peligro.contrato_codigo
    )
  );

-- 2d. Política UPDATE:
--     - superadmin: puede actualizar cualquier registro
--     - reportante original o trabajador del contrato: solo actualiza si el contrato le pertenece
CREATE POLICY "Update detecciones por contrato y rol"
  ON public.detecciones_peligro FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.perfiles
      WHERE id = auth.uid()
        AND rol = 'superadmin'
    )
    OR
    (
      -- El reportante original puede actualizar
      usuario_reportante_id = auth.uid()
    )
    OR
    (
      -- O cualquier trabajador asignado al mismo contrato
      EXISTS (
        SELECT 1 FROM public.trabajador_contratos tc
        JOIN public.perfiles p ON p.trabajador_id = tc.trabajador_id
        WHERE p.id = auth.uid()
          AND tc.contrato_codigo = detecciones_peligro.contrato_codigo
      )
    )
  );

-- ============================================================
-- 3. ACTUALIZAR LAS RPCs (NO requieren cambios porque no
--    referencian area_id ni contrato_codigo directamente)
-- ============================================================
-- Las funciones RPC iniciar_ejecucion_peligro y cerrar_peligro
-- solo modifican estatus_seguimiento, supervisor_responsable_id,
-- plan_accion, etc. No tocan area_id ni contrato_codigo.
-- ============================================================

-- ============================================================
-- 4. VERIFICACIÓN
-- ============================================================
DO $$
DECLARE
  v_has_contrato_col BOOLEAN;
  v_has_area_col BOOLEAN;
  v_policies INTEGER;
BEGIN
  -- Verificar que area_id fue eliminada
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'detecciones_peligro'
      AND column_name = 'area_id'
  ) INTO v_has_area_col;

  IF v_has_area_col THEN
    RAISE WARNING '⚠️  La columna area_id AÚN existe en detecciones_peligro.';
  ELSE
    RAISE NOTICE '✅ Columna area_id eliminada correctamente.';
  END IF;

  -- Verificar que contrato_codigo fue agregada
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'detecciones_peligro'
      AND column_name = 'contrato_codigo'
  ) INTO v_has_contrato_col;

  IF v_has_contrato_col THEN
    RAISE NOTICE '✅ Columna contrato_codigo agregada correctamente.';
  ELSE
    RAISE WARNING '⚠️  La columna contrato_codigo NO fue agregada.';
  END IF;

  -- Contar políticas RLS en la tabla
  SELECT COUNT(*) INTO v_policies
  FROM pg_policies
  WHERE tablename = 'detecciones_peligro';

  RAISE NOTICE '📋 Políticas RLS activas en detecciones_peligro: %', v_policies;

  RAISE NOTICE '============================================';
  RAISE NOTICE 'Migración 10 completada.';
  RAISE NOTICE '  - area_id         → ELIMINADA';
  RAISE NOTICE '  - contrato_codigo → AGREGADA (FK → contratos.codigo)';
  RAISE NOTICE '  - RLS actualizadas con bypass superadmin';
  RAISE NOTICE '============================================';
END $$;

COMMIT;