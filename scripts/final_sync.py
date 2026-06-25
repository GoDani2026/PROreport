import httpx
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '.'))
import env as _env
_env.load_env()

ACCESS_TOKEN = os.environ.get('ACCESS_TOKEN', '')
PROJECT_REF = os.environ.get('PROJECT_REF', '')
URL = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
headers = {"Authorization": f"Bearer {ACCESS_TOKEN}", "Content-Type": "application/json"}

def run(sql, label):
    r = httpx.post(URL, headers=headers, json={"query": sql}, timeout=60)
    ok = r.status_code == 201
    if ok:
        print(f"  {label}: OK")
    else:
        print(f"  {label}: ERROR - {r.text[:200]}")
    return ok

print("1. Creando funcion de sincronizacion...")
run("""
CREATE OR REPLACE FUNCTION public.sincronizar_usuarios_existentes()
RETURNS integer AS $$
DECLARE
  v_count integer := 0;
  v_user RECORD;
BEGIN
  FOR v_user IN
    SELECT au.id, au.email,
           COALESCE(au.raw_user_meta_data ->> 'rut', '') as user_rut
    FROM auth.users au
    WHERE NOT EXISTS (
      SELECT 1 FROM public.usuarios_trabajadores ut WHERE ut.auth_user_id = au.id
    )
  LOOP
    IF v_user.user_rut != '' THEN
      INSERT INTO public.usuarios_trabajadores (auth_user_id, trabajador_id, rut_asociado, rol_acceso, sincronizado)
      SELECT v_user.id, t.id, v_user.user_rut, 'colaborador', true
      FROM trabajadores t
      WHERE t.rut = v_user.user_rut
        AND NOT EXISTS (
          SELECT 1 FROM public.usuarios_trabajadores ut2 WHERE ut2.auth_user_id = v_user.id
        )
      ON CONFLICT DO NOTHING;
      GET DIAGNOSTICS v_count = ROW_COUNT;
    END IF;
  END LOOP;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
""", "CREATE sincronizar_usuarios_existentes")

print()
print("2. Ejecutando sincronizacion...")
r = httpx.post(URL, headers=headers, json={
    "query": "SELECT public.sincronizar_usuarios_existentes() as usuarios_sincronizados"
}, timeout=60)
if r.status_code == 201:
    print(f"  Usuarios sincronizados: {r.json()}")
else:
    print(f"  Error: {r.text[:200]}")

print()
print("3. Verificando vinculos existentes...")
r = httpx.post(URL, headers=headers, json={
    "query": "SELECT ut.auth_user_id, ut.trabajador_id, ut.rut_asociado, ut.rol_acceso, ut.sincronizado FROM usuarios_trabajadores ut LIMIT 10"
}, timeout=30)
if r.status_code == 201:
    result = r.json()
    if result and len(result) > 0:
        for row in result:
            print(f"  - auth_user: {str(row.get('auth_user_id','?'))[:8]} -> trabajador: {row.get('trabajador_id')} (rut: {row.get('rut_asociado','?')})")
    else:
        print("  (sin resultados - no hay usuarios auth vinculados todavia)")
else:
    print(f"  Error: {r.text[:200]}")

print()
print("=== DESPLIEGUE COMPLETO ===")