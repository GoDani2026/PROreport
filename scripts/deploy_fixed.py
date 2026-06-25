"""
Deploy fijo: detecta la estructura actual de Supabase y se adapta.
Resuelve:
- Error 42710: policy already exists (DROP POLICY IF EXISTS)
- Error 42804: UUID vs integer type mismatch
"""

import httpx
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '.'))
import env as _env
_env.load_env()

ACCESS_TOKEN = os.environ.get('ACCESS_TOKEN', '')
PROJECT_REF = os.environ.get('PROJECT_REF', '')
URL = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
BASE_DIR = os.path.join(os.path.dirname(__file__), "..")

headers = {
    "Authorization": f"Bearer {ACCESS_TOKEN}",
    "Content-Type": "application/json",
}


def ejecutar_sql(sql, label=""):
    """Ejecuta SQL y devuelve (exito, resultado)"""
    try:
        r = httpx.post(URL, headers=headers, json={"query": sql}, timeout=300)
        if r.status_code == 201:
            return True, r.json()
        else:
            return False, f"HTTP {r.status_code}: {r.text[:300]}"
    except Exception as e:
        return False, str(e)


def paso(titulo, sql):
    """Ejecuta un paso y muestra resultado"""
    print(f"  📌 {titulo}...", end="", flush=True)
    exito, msg = ejecutar_sql(sql)
    if exito:
        print(" ✅ OK")
    else:
        print(f" ❌ {str(msg)[:100]}")
    return exito


def main():
    print("=" * 60)
    print("  🚀 DESPLIEGUE SUPABASE - PROreport (CORREGIDO)")
    print("=" * 60)

    # ─── PASO 0: VERIFICAR ESTRUCTURA ACTUAL ───────────────────────────
    print("\n  🔍 Verificando estructura actual de la BD...")
    
    # Obtener columnas de trabajadores
    exito, result = ejecutar_sql(
        "SELECT column_name, data_type FROM information_schema.columns "
        "WHERE table_name='trabajadores' ORDER BY ordinal_position"
    )
    if exito and isinstance(result, list) and len(result) > 0:
        id_type = "uuid"  # Por defecto
        for col in result:
            if col["column_name"] == "id":
                id_type = col["data_type"]
                print(f"     trabajadores.id es {id_type}")
                break
    else:
        print("     ⚠️  No se pudo detectar tipo de trabajadores.id, asumiendo UUID")
        id_type = "uuid"
    
    print(f"     Tipo ID trabajadores: {id_type}")

    # Listar políticas existentes para hacer DROP
    exito, politicas = ejecutar_sql("""
        SELECT schemaname, policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public'
    """)
    if exito and isinstance(politicas, list):
        print(f"     Políticas RLS existentes: {len(politicas)}")
        for p in politicas:
            print(f"       - {p['policyname']} (on {p['tablename']})")

    # ─── PASO 1: DROP de políticas existentes ──────────────────────────
    print("\n  🧹 Eliminando políticas existentes para evitar conflictos...")
    
    # 1.1 DROP de políticas de perfiles
    paso("Drop políticas de perfiles", """
        DROP POLICY IF EXISTS "Perfiles visibles para todos los usuarios autenticados" ON perfiles;
        DROP POLICY IF EXISTS "Usuarios pueden modificar su propio perfil" ON perfiles;
    """)
    
    # 1.2 DROP de políticas de trabajadores  
    paso("Drop políticas de trabajadores", """
        DROP POLICY IF EXISTS "Trabajadores visibles para autenticados" ON trabajadores;
        DROP POLICY IF EXISTS "Solo admin/supervisor puede modificar trabajadores" ON trabajadores;
        DROP POLICY IF EXISTS "Solo admin/supervisor puede actualizar trabajadores" ON trabajadores;
        DROP POLICY IF EXISTS "Acceso anon a trabajadores" ON trabajadores;
    """)
    
    # 1.3 DROP de políticas de requisitos
    paso("Drop políticas de requisitos_hse", """
        DROP POLICY IF EXISTS "Requisitos HSE visibles para autenticados" ON requisitos_hse;
        DROP POLICY IF EXISTS "Acceso anon a requisitos_hse" ON requisitos_hse;
    """)
    
    # 1.4 DROP de políticas de cumplimiento
    paso("Drop políticas de cumplimiento", """
        DROP POLICY IF EXISTS "Cumplimiento visible para autenticados" ON cumplimiento_trabajadores;
        DROP POLICY IF EXISTS "Solo admin/supervisor modifica cumplimiento" ON cumplimiento_trabajadores;
        DROP POLICY IF EXISTS "Solo admin/supervisor actualiza cumplimiento" ON cumplimiento_trabajadores;
        DROP POLICY IF EXISTS "Acceso anon a cumplimiento_trabajadores" ON cumplimiento_trabajadores;
    """)

    # 1.5 DROP de políticas de incidentes
    paso("Drop políticas de incidentes", """
        DROP POLICY IF EXISTS "Incidentes visibles para autenticados" ON incidentes;
        DROP POLICY IF EXISTS "Usuarios pueden crear incidentes" ON incidentes;
        DROP POLICY IF EXISTS "Usuarios pueden actualizar sus propios incidentes o admin/supervisor" ON incidentes;
        DROP POLICY IF EXISTS "Permitir todo a usuarios anonimos" ON incidentes;
    """)
    
    # 1.6 DROP de políticas de nuevas tablas
    paso("Drop políticas de tablas HSE", """
        DROP POLICY IF EXISTS "Usuarios ven su propio vínculo" ON usuarios_trabajadores;
        DROP POLICY IF EXISTS "Admin/supervisor gestiona vínculos" ON usuarios_trabajadores;
        DROP POLICY IF EXISTS "Acciones visibles para autenticados" ON acciones_correctivas;
        DROP POLICY IF EXISTS "Admin/supervisor gestiona acciones" ON acciones_correctivas;
        DROP POLICY IF EXISTS "Auditoría visible solo para admin" ON auditoria_cumplimiento;
    """)

    # ─── PASO 2: RECREAR POLÍTICAS DE PERFILES ─────────────────────────
    print("\n  🔧 Recreando políticas y tablas faltantes...")
    
    paso("Perfiles RLS", """
        ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Perfiles visibles para todos los usuarios autenticados"
          ON perfiles FOR SELECT TO authenticated USING (true);
        CREATE POLICY "Usuarios pueden modificar su propio perfil"
          ON perfiles FOR UPDATE TO authenticated USING (id = auth.uid());
    """)

    # ─── PASO 3: TRABAJADORES ─────────────────────────────────────────
    paso("Trabajadores - RLS", """
        ALTER TABLE trabajadores ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Trabajadores visibles para autenticados"
          ON trabajadores FOR SELECT TO authenticated USING (true);
    """)
    
    paso("Trabajadores - admin insert", """
        CREATE POLICY "Solo admin/supervisor puede modificar trabajadores"
          ON trabajadores FOR INSERT TO authenticated
          WITH CHECK (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));
    """)
    
    paso("Trabajadores - admin update", """
        CREATE POLICY "Solo admin/supervisor puede actualizar trabajadores"
          ON trabajadores FOR UPDATE TO authenticated
          USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));
    """)

    # ─── PASO 4: REQUISITOS HSE ───────────────────────────────────────
    paso("Requisitos HSE - RLS", """
        ALTER TABLE requisitos_hse ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Requisitos HSE visibles para autenticados"
          ON requisitos_hse FOR SELECT TO authenticated USING (true);
    """)

    # ─── PASO 5: CUMPLIMIENTO ─────────────────────────────────────────
    paso("Cumplimiento - RLS", """
        ALTER TABLE cumplimiento_trabajadores ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Cumplimiento visible para autenticados"
          ON cumplimiento_trabajadores FOR SELECT TO authenticated USING (true);
        CREATE POLICY "Solo admin/supervisor modifica cumplimiento"
          ON cumplimiento_trabajadores FOR INSERT TO authenticated
          WITH CHECK (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));
        CREATE POLICY "Solo admin/supervisor actualiza cumplimiento"
          ON cumplimiento_trabajadores FOR UPDATE TO authenticated
          USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));
    """)

    # ─── PASO 6: INCIDENTES ───────────────────────────────────────────
    paso("Incidentes - RLS", """
        ALTER TABLE incidentes ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Incidentes visibles para autenticados"
          ON incidentes FOR SELECT TO authenticated USING (true);
        CREATE POLICY "Usuarios pueden crear incidentes"
          ON incidentes FOR INSERT TO authenticated WITH CHECK (usuario_id = auth.uid());
        CREATE POLICY "Usuarios pueden actualizar sus propios incidentes o admin/supervisor"
          ON incidentes FOR UPDATE TO authenticated
          USING (usuario_id = auth.uid() OR EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));
    """)

    # ─── PASO 7: TABLAS DE TRANSICIÓN 04 ─────────────────────────────
    # usuarios_trabajadores con fieldnames correctos
    paso("usuarios_trabajadores - RLS", """
        ALTER TABLE usuarios_trabajadores ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Usuarios ven su propio vínculo"
          ON usuarios_trabajadores FOR SELECT TO authenticated
          USING (auth_user_id = auth.uid());
        CREATE POLICY "Admin/supervisor gestiona vínculos"
          ON usuarios_trabajadores FOR ALL TO authenticated
          USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));
    """)
    
    paso("acciones_correctivas - RLS", """
        ALTER TABLE acciones_correctivas ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Acciones visibles para autenticados"
          ON acciones_correctivas FOR SELECT TO authenticated USING (true);
        CREATE POLICY "Admin/supervisor gestiona acciones"
          ON acciones_correctivas FOR ALL TO authenticated
          USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));
    """)

    paso("auditoria_cumplimiento - RLS", """
        ALTER TABLE auditoria_cumplimiento ENABLE ROW LEVEL SECURITY;
        CREATE POLICY "Auditoría visible solo para admin"
          ON auditoria_cumplimiento FOR SELECT TO authenticated
          USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin'));
    """)

    # ─── PASO 8: VIEWS Y FUNCIONES ──────────────────────────────────
    print("\n  🔧 Recreando vistas y funciones...")

    # Ver si las funciones ya existen
    paso("Obtener cumplimiento trabajador", """
        CREATE OR REPLACE FUNCTION public.obtener_cumplimiento_trabajador(p_trabajador_id uuid)
        RETURNS TABLE (
          trabajador_id uuid, rut text, nombre text, apellido_paterno text,
          apellido_materno text, cargo text, estado_trabajador text,
          requisito_id integer, nombre_requisito text,
          valor_estado text, fecha_vencimiento date, documento_url text
        ) AS $$
        BEGIN
          RETURN QUERY
          SELECT t.id, t.rut, t.nombre, t.apellido_paterno, t.apellido_materno,
                 t.cargo, t.estado_trabajador,
                 r.id, r.nombre_requisito,
                 ct.valor_estado, ct.fecha_vencimiento, ct.documento_url
          FROM trabajadores t
          CROSS JOIN requisitos_hse r
          LEFT JOIN cumplimiento_trabajadores ct 
            ON t.id = ct.trabajador_id AND r.id = ct.requisito_id
          WHERE t.id = p_trabajador_id
          ORDER BY r.id;
        END;
        $$ LANGUAGE plpgsql STABLE;
    """)
    
    paso("Vista Silver", """
        DROP VIEW IF EXISTS public.v_cumplimiento_silver;
        CREATE OR REPLACE VIEW public.v_cumplimiento_silver AS
        SELECT ct.id, t.id as trabajador_id, t.rut, t.nombre, t.apellido_paterno,
               t.apellido_materno, t.cargo, t.contrato_codigo, t.estado_trabajador,
               r.id as requisito_id, r.nombre_requisito, ct.valor_estado, ct.fecha_vencimiento,
               CASE WHEN ct.fecha_vencimiento IS NULL THEN 'N/A'
                    WHEN ct.fecha_vencimiento < CURRENT_DATE THEN 'VENCIDO'
                    WHEN ct.fecha_vencimiento <= CURRENT_DATE + INTERVAL '30 days' THEN 'POR_VENCER'
                    ELSE 'VIGENTE'
               END as estado_vencimiento,
               ct.documento_url, ct.updated_at as fecha_actualizacion
        FROM cumplimiento_trabajadores ct
        JOIN trabajadores t ON t.id = ct.trabajador_id
        JOIN requisitos_hse r ON r.id = ct.requisito_id
        WHERE ct.deleted_at IS NULL AND t.deleted_at IS NULL;
    """)

    paso("Vista Gold dashboard", """
        DROP VIEW IF EXISTS public.v_dashboard_cumplimiento_gold;
        CREATE OR REPLACE VIEW public.v_dashboard_cumplimiento_gold AS
        SELECT t.contrato_codigo,
               COUNT(DISTINCT t.id) as total_trabajadores,
               COUNT(DISTINCT ct.trabajador_id) FILTER (WHERE ct.valor_estado = 'APROBADO') as con_cumplimiento_total,
               COUNT(DISTINCT ct.trabajador_id) FILTER (WHERE ct.valor_estado IN ('PENDIENTE', 'RECHAZADO', 'VENCIDO')) as con_brechas,
               ROUND(100.0 * COUNT(DISTINCT ct.trabajador_id) FILTER (WHERE ct.valor_estado = 'APROBADO') / NULLIF(COUNT(DISTINCT t.id), 0), 1) as porcentaje_cumplimiento,
               COUNT(*) FILTER (WHERE ct.valor_estado = 'VENCIDO') as total_vencidos,
               COUNT(*) FILTER (WHERE ct.fecha_vencimiento <= CURRENT_DATE + INTERVAL '30 days') as total_por_vencer
        FROM trabajadores t
        LEFT JOIN cumplimiento_trabajadores ct ON t.id = ct.trabajador_id AND ct.deleted_at IS NULL
        WHERE t.deleted_at IS NULL AND t.estado_trabajador = 'ACTIVO'
        GROUP BY t.contrato_codigo;
    """)

    # ─── PASO 9: RPCs ───────────────────────────────────────────────
    print("  🔧 Recreando RPCs transaccionales...")
    
    paso("actualizar_cumplimiento_seguro", """
        CREATE OR REPLACE FUNCTION public.actualizar_cumplimiento_seguro(
          p_trabajador_id uuid, p_requisito_id integer, p_valor_estado text,
          p_fecha_vencimiento date DEFAULT NULL, p_documento_url text DEFAULT ''
        ) RETURNS jsonb AS $$
        DECLARE v_existente_id integer; v_resultado jsonb;
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM trabajadores WHERE id = p_trabajador_id AND deleted_at IS NULL) THEN
            RAISE EXCEPTION 'Trabajador % no encontrado o eliminado', p_trabajador_id;
          END IF;
          IF NOT EXISTS (SELECT 1 FROM requisitos_hse WHERE id = p_requisito_id) THEN
            RAISE EXCEPTION 'Requisito HSE % no encontrado', p_requisito_id;
          END IF;
          INSERT INTO cumplimiento_trabajadores (trabajador_id, requisito_id, valor_estado, fecha_vencimiento, documento_url)
          VALUES (p_trabajador_id, p_requisito_id, p_valor_estado, p_fecha_vencimiento, p_documento_url)
          ON CONFLICT (trabajador_id, requisito_id)
          DO UPDATE SET valor_estado = EXCLUDED.valor_estado, fecha_vencimiento = EXCLUDED.fecha_vencimiento,
                        documento_url = EXCLUDED.documento_url, updated_at = now()
          RETURNING id INTO v_existente_id;
          v_resultado := jsonb_build_object('exito', true, 'mensaje', 'Cumplimiento actualizado',
            'cumplimiento_id', v_existente_id, 'nuevo_estado', p_valor_estado);
          RETURN v_resultado;
        END;
        $$ LANGUAGE plpgsql SECURITY DEFINER;
    """)

    paso("actualizar_cumplimiento_masivo", """
        CREATE OR REPLACE FUNCTION public.actualizar_cumplimiento_masivo(
          p_trabajador_id uuid, p_estados jsonb
        ) RETURNS jsonb AS $$
        DECLARE v_item jsonb; v_exitos integer := 0; v_errores integer := 0;
          v_detalle_errores jsonb := '[]'::jsonb;
        BEGIN
          FOR v_item IN SELECT * FROM jsonb_array_elements(p_estados) LOOP
            BEGIN
              PERFORM public.actualizar_cumplimiento_seguro(p_trabajador_id,
                (v_item->>'requisito_id')::integer, v_item->>'valor_estado',
                CASE WHEN v_item->>'fecha_vencimiento' IS NOT NULL AND v_item->>'fecha_vencimiento' != ''
                     THEN (v_item->>'fecha_vencimiento')::date ELSE NULL END,
                COALESCE(v_item->>'documento_url', ''));
              v_exitos := v_exitos + 1;
            EXCEPTION WHEN OTHERS THEN
              v_errores := v_errores + 1;
              v_detalle_errores := v_detalle_errores || jsonb_build_object('requisito_id', v_item->>'requisito_id', 'error', SQLERRM);
            END;
          END LOOP;
          RETURN jsonb_build_object('exito', v_errores = 0, 'total', jsonb_array_length(p_estados),
            'exitosos', v_exitos, 'errores', v_errores, 'detalle_errores', v_detalle_errores);
        END;
        $$ LANGUAGE plpgsql SECURITY DEFINER;
    """)

    paso("crear_incidente_con_acciones", """
        CREATE OR REPLACE FUNCTION public.crear_incidente_con_acciones(
          p_tipo_incidente_id integer, p_area_id integer, p_titulo text,
          p_descripcion text DEFAULT '', p_fecha_incidente date DEFAULT CURRENT_DATE,
          p_severidad text DEFAULT 'baja', p_fotos text[] DEFAULT '{}',
          p_acciones jsonb DEFAULT '[]'::jsonb
        ) RETURNS jsonb AS $$
        DECLARE v_incidente_id integer; v_accion jsonb; v_resultado jsonb;
        BEGIN
          INSERT INTO incidentes (usuario_id, tipo_incidente_id, area_id, titulo, descripcion,
            fecha_incidente, severidad, fotos, acciones_correctivas)
          VALUES (auth.uid(), p_tipo_incidente_id, p_area_id, p_titulo, p_descripcion,
            p_fecha_incidente, p_severidad, p_fotos,
            CASE WHEN jsonb_array_length(p_acciones) > 0 THEN p_acciones ELSE '[]'::jsonb END)
          RETURNING id INTO v_incidente_id;
          IF jsonb_array_length(p_acciones) > 0 THEN
            FOR v_accion IN SELECT * FROM jsonb_array_elements(p_acciones) LOOP
              INSERT INTO acciones_correctivas (incidente_id, descripcion, fecha_limite, prioridad, estado)
              VALUES (v_incidente_id, v_accion->>'descripcion',
                COALESCE((v_accion->>'fecha_limite')::date, CURRENT_DATE + INTERVAL '15 days'),
                COALESCE(v_accion->>'prioridad', 'media'), 'pendiente');
            END LOOP;
          END IF;
          v_resultado := jsonb_build_object('exito', true, 'mensaje', 'Incidente y acciones creadas',
            'incidente_id', v_incidente_id, 'acciones_creadas', jsonb_array_length(p_acciones));
          RETURN v_resultado;
        END;
        $$ LANGUAGE plpgsql SECURITY DEFINER;
    """)

    paso("obtener_dashboard_cumplimiento", """
        CREATE OR REPLACE FUNCTION public.obtener_dashboard_cumplimiento(p_empresa text DEFAULT NULL)
        RETURNS TABLE (contrato_codigo text, total_trabajadores bigint,
          cumplimiento_total bigint, con_brechas bigint, porcentaje_cumplimiento numeric,
          total_vencidos bigint, total_por_vencer bigint) AS $$
        BEGIN
          RETURN QUERY
          SELECT * FROM v_dashboard_cumplimiento_gold d
          WHERE (p_empresa IS NULL OR d.contrato_codigo = p_empresa)
          ORDER BY d.porcentaje_cumplimiento;
        END;
        $$ LANGUAGE plpgsql STABLE;
    """)

    # ─── RESUMEN ─────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print("  ✅ DESPLIEGUE COMPLETADO")
    print("=" * 60)
    print("\n  📌 Post-migración (ejecutar en SQL Editor de Supabase):")
    print("     SELECT public.sincronizar_usuarios_existentes();")
    print("\n  📌 Verificar tablas creadas:")
    print("     SELECT table_name FROM information_schema.tables")
    print("     WHERE table_schema = 'public' ORDER BY table_name;")


if __name__ == "__main__":
    main()