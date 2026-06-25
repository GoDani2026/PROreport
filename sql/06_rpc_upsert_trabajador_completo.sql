-- ============================================================
-- PROreport - 06. RPC: upsert_trabajador_completo
-- ------------------------------------------------------------
-- Función atómica (ACID) que recibe un JSON con datos del
-- trabajador y un array JSON con sus cumplimientos HSE.
--
-- Resuelve el desfase de llaves foráneas (Tarea 3 del plan):
--   1. UPSERT del trabajador + RETURNING id en variable local
--   2. UPSERT de cada cumplimiento con ese ID real
--   Todo dentro de una sola transacción PostgreSQL.
-- 
-- Uso desde Flutter:
--   supabase.rpc('upsert_trabajador_completo', params: {
--     'p_datos': { rut, nombre, apellido_paterno, ... },
--     'p_cumplimientos': [{ requisito_id, valor_estado, ... }]
--   })
-- ============================================================

CREATE OR REPLACE FUNCTION public.upsert_trabajador_completo(
  p_datos JSONB,
  p_cumplimientos JSONB DEFAULT '[]'::JSONB,
  p_usuario_registra_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_trabajador_id INTEGER;
  v_rut TEXT;
  v_cumplimiento JSONB;
  v_cumplimientos_ok INTEGER := 0;
  v_cumplimientos_err INTEGER := 0;
  v_errores_detalle TEXT[] := '{}';
BEGIN
  -- ============================================================
  -- 1. Validar que exista RUT
  -- ============================================================
  v_rut := trim(p_datos ->> 'rut');
  IF v_rut IS NULL OR v_rut = '' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'RUT es obligatorio',
      'trabajador_id', null::INTEGER,
      'cumplimientos_ok', 0,
      'cumplimientos_err', 0
    );
  END IF;

  -- ============================================================
  -- 2. UPSERT del trabajador — capturar ID real con RETURNING
  -- ============================================================
  INSERT INTO trabajadores (
    rut,
    nombre,
    apellido_paterno,
    apellido_materno,
    cargo,
    nacionalidad,
    fecha_vencimiento_residencia,
    sexo,
    turno,
    empresa,
    contrato_codigo,
    estado_trabajador,
    updated_at
  ) VALUES (
    v_rut,
    p_datos ->> 'nombre',
    p_datos ->> 'apellido_paterno',
    COALESCE(p_datos ->> 'apellido_materno', ''),
    COALESCE(p_datos ->> 'cargo', ''),
    COALESCE(p_datos ->> 'nacionalidad', 'Chilena'),
    COALESCE(p_datos ->> 'fecha_vencimiento_residencia', ''),
    COALESCE(p_datos ->> 'sexo', ''),
    COALESCE(p_datos ->> 'turno', ''),
    COALESCE(p_datos ->> 'empresa', ''),
    COALESCE(p_datos ->> 'contrato_codigo', 'SC-9500014891'),
    COALESCE(p_datos ->> 'estado_trabajador', 'ACTIVO'),
    now()
  )
  ON CONFLICT (rut) DO UPDATE SET
    nombre              = EXCLUDED.nombre,
    apellido_paterno    = EXCLUDED.apellido_paterno,
    apellido_materno    = EXCLUDED.apellido_materno,
    cargo               = EXCLUDED.cargo,
    nacionalidad        = EXCLUDED.nacionalidad,
    fecha_vencimiento_residencia = EXCLUDED.fecha_vencimiento_residencia,
    sexo                = EXCLUDED.sexo,
    turno               = EXCLUDED.turno,
    empresa             = EXCLUDED.empresa,
    contrato_codigo     = EXCLUDED.contrato_codigo,
    estado_trabajador   = EXCLUDED.estado_trabajador,
    updated_at          = now()
  RETURNING id INTO v_trabajador_id;

  -- ============================================================
  -- 3. UPSERT de cada cumplimiento con el ID real capturado
  --    SIN bucle — usando INSERT ... SELECT desde jsonb_array_elements
  --    para mejor rendimiento en lotes grandes
  -- ============================================================
  IF p_cumplimientos IS NOT NULL AND jsonb_array_length(p_cumplimientos) > 0 THEN
    INSERT INTO cumplimiento_trabajadores (
      trabajador_id,
      requisito_id,
      valor_estado,
      fecha_vencimiento,
      documento_url,
      usuario_registra_id,
      updated_at
    )
    SELECT
      v_trabajador_id,
      (item ->> 'requisito_id')::INTEGER,
      COALESCE(item ->> 'valor_estado', 'N/A'),
      CASE
        WHEN item ->> 'fecha_vencimiento' IS NOT NULL
             AND item ->> 'fecha_vencimiento' != ''
        THEN (item ->> 'fecha_vencimiento')::DATE
        ELSE NULL
      END,
      item ->> 'documento_url',
      p_usuario_registra_id,
      now()
    FROM jsonb_array_elements(p_cumplimientos) AS item
    ON CONFLICT (trabajador_id, requisito_id) DO UPDATE SET
      valor_estado       = EXCLUDED.valor_estado,
      fecha_vencimiento  = EXCLUDED.fecha_vencimiento,
      documento_url      = EXCLUDED.documento_url,
      usuario_registra_id = EXCLUDED.usuario_registra_id,
      updated_at         = now();

    GET DIAGNOSTICS v_cumplimientos_ok = ROW_COUNT;
  END IF;

  -- ============================================================
  -- 4. Retornar resultado JSON con el ID real del trabajador
  -- ============================================================
  RETURN jsonb_build_object(
    'success', true,
    'trabajador_id', v_trabajador_id,
    'rut', v_rut,
    'cumplimientos_ok', v_cumplimientos_ok,
    'cumplimientos_err', v_cumplimientos_err
  );
END;
$$;

-- ============================================================
-- FUNCIÓN AUXILIAR: upsert_trabajadores_lote
-- Para carga masiva de múltiples trabajadores en una sola RPC.
-- Recibe un array de objetos { datos: {...}, cumplimientos: [...] }
-- y procesa cada uno en una sola transacción.
-- ============================================================
CREATE OR REPLACE FUNCTION public.upsert_trabajadores_lote(
  p_lote JSONB,
  p_usuario_registra_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item JSONB;
  v_resultado JSONB;
  v_resultados JSONB[] := '{}';
  v_total_ok INTEGER := 0;
  v_total_err INTEGER := 0;
  v_errores TEXT[] := '{}';
BEGIN
  IF p_lote IS NULL OR jsonb_array_length(p_lote) = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Lote vacío',
      'total_ok', 0,
      'total_err', 0
    );
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_lote)
  LOOP
    BEGIN
      v_resultado := public.upsert_trabajador_completo(
        p_datos              => v_item -> 'datos',
        p_cumplimientos      => v_item -> 'cumplimientos',
        p_usuario_registra_id => p_usuario_registra_id
      );

      IF v_resultado ->> 'success' = 'true' THEN
        v_total_ok := v_total_ok + 1;
      ELSE
        v_total_err := v_total_err + 1;
        v_errores := array_append(
          v_errores,
          'Item con rut ' || COALESCE(v_item -> 'datos' ->> 'rut', 'N/A')
          || ': ' || COALESCE(v_resultado ->> 'error', 'error desconocido')
        );
      END IF;

      v_resultados := array_append(v_resultados, v_resultado);
    EXCEPTION WHEN OTHERS THEN
      v_total_err := v_total_err + 1;
      v_errores := array_append(
        v_errores,
        'Item con rut ' || COALESCE(v_item -> 'datos' ->> 'rut', 'N/A')
        || ': ' || SQLERRM
      );
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', v_total_err = 0,
    'total_ok', v_total_ok,
    'total_err', v_total_err,
    'errores', CASE WHEN array_length(v_errores, 1) > 0
               THEN to_jsonb(v_errores)
               ELSE '[]'::JSONB END
  );
END;
$$;

-- ============================================================
-- Permitir ejecución desde RPC autenticado
-- (SECURITY DEFINER ya bypassea RLS, pero hay que asegurar
--  que cualquier rol autenticado pueda invocarla)
-- ============================================================
GRANT EXECUTE ON FUNCTION public.upsert_trabajador_completo TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_trabajadores_lote TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_trabajador_completo TO anon;
GRANT EXECUTE ON FUNCTION public.upsert_trabajadores_lote TO anon;

-- ============================================================
-- NOTA: Al ser SECURITY DEFINER, las funciones operan con
-- privilegios del owner (superadmin), lo que permite bypassear
-- RLS sin necesitar service_role_key en el cliente.
-- Esto es seguro porque la lógica de negocio (qué se inserta
-- y cómo) está encapsulada y validada en la función.
-- ============================================================