"""
Script para verificar y forzar el despliegue de la función RPC.
"""
import httpx
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '.'))
import env as _env
_env.load_env()

ACCESS_TOKEN = os.environ.get('ACCESS_TOKEN', '')
PROJECT_REF = os.environ.get('PROJECT_REF', '')
URL = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"

BASE_DIR = os.path.join(os.path.dirname(__file__), "..")
SCRIPT_PATH = os.path.join(BASE_DIR, "sql", "06_rpc_upsert_trabajador_completo.sql")

headers = {
    "Authorization": f"Bearer {ACCESS_TOKEN}",
    "Content-Type": "application/json",
}

def run_sql(query, label="SQL"):
    print(f"\n  --- {label} ---")
    r = httpx.post(URL, headers=headers, json={"query": query}, timeout=60)
    print(f"  Status: {r.status_code}")
    if r.status_code == 201:
        data = r.json()
        if isinstance(data, list):
            for item in data:
                if isinstance(item, dict) and "error" in item:
                    print(f"  ERROR: {item['error'][:200]}")
                else:
                    print(f"  OK: {item}")
        else:
            print(f"  Respuesta: {data}")
    else:
        print(f"  Error: {r.text[:300]}")
    return r

# 1. Verificar si las funciones existen
print("=" * 60)
print("  VERIFICACIÓN DE FUNCIONES RPC")
print("=" * 60)

run_sql(
    "SELECT proname, pronargs FROM pg_proc WHERE proname LIKE 'upsert_trabaj%' ORDER BY proname;",
    "Funciones existentes"
)

# 2. Desplegar si no existen
print("\n" + "=" * 60)
print("  DESPLEGANDO FUNCIÓN RPC")
print("=" * 60)

with open(SCRIPT_PATH, "r", encoding="utf-8") as f:
    sql = f.read()

run_sql(sql, "Ejecutando 06_rpc_upsert_trabajador_completo.sql")

# 3. Verificar de nuevo
print("\n" + "=" * 60)
print("  VERIFICACIÓN POST-DEPLOY")
print("=" * 60)

run_sql(
    "SELECT proname, pronargs FROM pg_proc WHERE proname LIKE 'upsert_trabaj%' ORDER BY proname;",
    "Funciones después del deploy"
)

# 4. Probar la función individual
print("\n" + "=" * 60)
print("  PRUEBA: upsert_trabajador_completo")
print("=" * 60)

test_sql = """
SELECT public.upsert_trabajador_completo(
    '{"rut":"99.999.999-9","nombre":"TEST","apellido_paterno":"RPC","cargo":"Prueba"}'::jsonb,
    '[{"requisito_id":1,"valor_estado":"N/A"}]'::jsonb
) AS resultado;
"""
run_sql(test_sql, "Test individual")

# 5. Probar la función batch
print("\n" + "=" * 60)
print("  PRUEBA: upsert_trabajadores_lote")
print("=" * 60)

batch_sql = """
SELECT public.upsert_trabajadores_lote(
    '[{"datos":{"rut":"88.888.888-8","nombre":"TEST2","apellido_paterno":"LOTE","cargo":"Prueba"},"cumplimientos":[{"requisito_id":1,"valor_estado":"VIGENTE"}]}]'::jsonb
) AS resultado;
"""
run_sql(batch_sql, "Test batch")

print("\n" + "=" * 60)
print("  COMPLETADO")
print("=" * 60)