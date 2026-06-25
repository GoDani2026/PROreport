import os
import sys
import httpx

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '.'))
import env as _env
_env.load_env()

ACCESS_TOKEN = os.environ.get('ACCESS_TOKEN', '')
PROJECT_REF = os.environ.get('PROJECT_REF', '')
URL = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
headers = {"Authorization": f"Bearer {ACCESS_TOKEN}", "Content-Type": "application/json"}

print("Ejecutando: SELECT public.sincronizar_usuarios_existentes()")
r = httpx.post(URL, headers=headers, json={
    "query": "SELECT public.sincronizar_usuarios_existentes() as result"
}, timeout=60)
if r.status_code == 201:
    print(f"Resultado: {r.json()}")
else:
    print(f"Error: {r.status_code} - {r.text[:300]}")

print()
print("Verificando tablas finales...")
r = httpx.post(URL, headers=headers, json={
    "query": "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name"
}, timeout=30)
if r.status_code == 201:
    for t in r.json():
        print(f"  - {t['table_name']}")

print()
print("Verificando vistas...")
r = httpx.post(URL, headers=headers, json={
    "query": "SELECT table_name FROM information_schema.views WHERE table_schema='public' ORDER BY table_name"
}, timeout=30)
if r.status_code == 201:
    for t in r.json():
        print(f"  - {t['table_name']}")

print()
print("Verificando funciones RPC disponibles...")
r = httpx.post(URL, headers=headers, json={
    "query": "SELECT proname FROM pg_proc WHERE pronamespace='public'::regnamespace AND prokind='f' ORDER BY proname"
}, timeout=30)
if r.status_code == 201:
    for t in r.json():
        print(f"  - {t['proname']}()")