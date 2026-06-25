import httpx
import json
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '.'))
import env as _env
_env.load_env()

ACCESS_TOKEN = os.environ.get('ACCESS_TOKEN', '')
PROJECT_REF = os.environ.get('PROJECT_REF', '')
URL = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"

headers = {
    "Authorization": f"Bearer {ACCESS_TOKEN}",
    "Content-Type": "application/json",
}

def run(sql, label):
    r = httpx.post(URL, headers=headers, json={"query": sql}, timeout=60)
    ok = r.status_code == 201
    status = "OK" if ok else "ERROR: " + r.text[:150]
    print(f"  {label}: {status}")
    return ok

print("Creando tablas faltantes...")

run("""
CREATE TABLE IF NOT EXISTS usuarios_trabajadores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trabajador_id uuid REFERENCES trabajadores(id) ON DELETE SET NULL,
  rut_asociado text, rol_acceso text NOT NULL DEFAULT 'colaborador',
  sincronizado boolean NOT NULL DEFAULT false, ultima_conexion timestamp with time zone,
  creado_en_auth timestamp with time zone DEFAULT now(), actualizado_a timestamp with time zone DEFAULT now(),
  UNIQUE(auth_user_id), UNIQUE(trabajador_id)
);
""", "CREATE usuarios_trabajadores")

run("""
ALTER TABLE usuarios_trabajadores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Usuarios ven su propio vinculo" ON usuarios_trabajadores FOR SELECT TO authenticated USING (auth_user_id = auth.uid());
CREATE POLICY "Admin/supervisor gestiona vinculos" ON usuarios_trabajadores FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));
""", "RLS usuarios_trabajadores")

run("""
CREATE TABLE IF NOT EXISTS acciones_correctivas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  incidente_id uuid REFERENCES incidentes(id) ON DELETE CASCADE,
  descripcion text NOT NULL, fecha_asignacion timestamp DEFAULT now(),
  fecha_limite date NOT NULL, fecha_cierre timestamp,
  estado text NOT NULL DEFAULT 'pendiente', prioridad text DEFAULT 'media',
  evidencia_url text, notas_cierre text, deleted_at timestamp DEFAULT NULL
);
""", "CREATE acciones_correctivas")

run("""
ALTER TABLE acciones_correctivas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Acciones visibles para autenticados" ON acciones_correctivas FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admin/supervisor gestiona acciones" ON acciones_correctivas FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol IN ('admin', 'supervisor')));
""", "RLS acciones_correctivas")

run("""
CREATE TABLE IF NOT EXISTS auditoria_cumplimiento (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tabla_afectada text NOT NULL, registro_id text NOT NULL,
  operacion text NOT NULL, usuario_id uuid, usuario_nombre text,
  valor_anterior jsonb, valor_nuevo jsonb, created_at timestamp DEFAULT now()
);
""", "CREATE auditoria_cumplimiento")

run("""
ALTER TABLE auditoria_cumplimiento ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Auditoria visible solo para admin" ON auditoria_cumplimiento FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM perfiles WHERE id = auth.uid() AND rol = 'admin'));
""", "RLS auditoria_cumplimiento")

print()
print("Agregando columnas faltantes...")
run("ALTER TABLE cumplimiento_trabajadores ADD COLUMN IF NOT EXISTS deleted_at timestamp DEFAULT NULL;", "deleted_at cumplimiento")
run("ALTER TABLE incidentes ADD COLUMN IF NOT EXISTS deleted_at timestamp DEFAULT NULL;", "deleted_at incidentes")
run("ALTER TABLE trabajadores ADD COLUMN IF NOT EXISTS deleted_at timestamp DEFAULT NULL;", "deleted_at trabajadores")

print()
print("Recreando vistas...")

run("""
DROP VIEW IF EXISTS v_cumplimiento_silver;
CREATE OR REPLACE VIEW v_cumplimiento_silver AS
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
""", "v_cumplimiento_silver")

run("""
DROP VIEW IF EXISTS v_dashboard_cumplimiento_gold;
CREATE OR REPLACE VIEW v_dashboard_cumplimiento_gold AS
SELECT t.contrato_codigo,
       COUNT(DISTINCT t.id) as total_trabajadores,
       COUNT(DISTINCT ct.trabajador_id) FILTER (WHERE ct.valor_estado = 'APROBADO') as con_cumplimiento_total,
       COUNT(DISTINCT ct.trabajador_id) FILTER (WHERE ct.valor_estado IN ('PENDIENTE','RECHAZADO','VENCIDO')) as con_brechas,
       ROUND(100.0 * COUNT(DISTINCT ct.trabajador_id) FILTER (WHERE ct.valor_estado = 'APROBADO') / NULLIF(COUNT(DISTINCT t.id), 0), 1) as porcentaje_cumplimiento,
       COUNT(*) FILTER (WHERE ct.valor_estado = 'VENCIDO') as total_vencidos,
       COUNT(*) FILTER (WHERE ct.fecha_vencimiento <= CURRENT_DATE + INTERVAL '30 days') as total_por_vencer
FROM trabajadores t
LEFT JOIN cumplimiento_trabajadores ct ON t.id = ct.trabajador_id AND ct.deleted_at IS NULL
WHERE t.deleted_at IS NULL AND t.estado_trabajador = 'ACTIVO'
GROUP BY t.contrato_codigo;
""", "v_dashboard_cumplimiento_gold")

print()
print("Verificando tablas finales...")
r = httpx.post(URL, headers=headers, json={
    "query": "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name"
}, timeout=30)

if r.status_code == 201:
    for t in r.json():
        print(f"  - {t['table_name']}")
else:
    print(f"ERROR al listar: {r.text[:200]}")

print()
print("Verificando vistas...")
r = httpx.post(URL, headers=headers, json={
    "query": "SELECT table_name FROM information_schema.views WHERE table_schema='public' ORDER BY table_name"
}, timeout=30)
if r.status_code == 201:
    for t in r.json():
        print(f"  - {t['table_name']} (view)")

print()
print("Verificando funciones RPC...")
r = httpx.post(URL, headers=headers, json={
    "query": "SELECT proname FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND prokind = 'f' ORDER BY proname"
}, timeout=30)
if r.status_code == 201:
    for t in r.json():
        print(f"  - {t['proname']}()")