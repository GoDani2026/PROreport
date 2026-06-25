"""
Script para desplegar SOLO la función RPC upsert_trabajador_completo 
y upsert_trabajadores_lote en Supabase.

Uso:
    python scripts/deploy_rpc.py
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


def main():
    print("=" * 60)
    print("  🚀 DESPLIEGUE RPC - PROreport")
    print("=" * 60)
    print(f"  Proyecto: {PROJECT_REF}")
    print()

    if not os.path.exists(SCRIPT_PATH):
        print(f"  ❌ Archivo no encontrado: {SCRIPT_PATH}")
        sys.exit(1)

    with open(SCRIPT_PATH, "r", encoding="utf-8") as f:
        sql = f.read()

    print(f"  📄 {os.path.basename(SCRIPT_PATH)}")
    print(f"  📏 {len(sql)} caracteres")
    print(f"  ⏳ Ejecutando...")
    print()

    headers = {
        "Authorization": f"Bearer {ACCESS_TOKEN}",
        "Content-Type": "application/json",
    }

    try:
        r = httpx.post(
            URL,
            headers=headers,
            json={"query": sql},
            timeout=120,
        )

        if r.status_code == 201:
            result = r.json()
            if isinstance(result, list):
                errors = []
                for x in result:
                    if isinstance(x, dict):
                        if "error" in x:
                            errors.append(x["error"])
                        elif x.get("result") == "ERROR":
                            errors.append(str(x))
                if errors:
                    print(f"  ⚠️  {len(errors)} errores:")
                    for e in errors[:5]:
                        print(f"     - {e[:200]}")
                    sys.exit(1)
                print(f"  ✅ OK - {len(result)} statements ejecutados")
            else:
                print(f"  ✅ OK - Respuesta: {result}")

            print()
            print("=" * 60)
            print("  🎉 FUNCIONES RPC DESPLEGADAS EXITOSAMENTE!")
            print("=" * 60)
            print()
            print("  Funciones creadas:")
            print("    - public.upsert_trabajador_completo")
            print("    - public.upsert_trabajadores_lote")
            print()
            print("  Probar desde Flutter:")
            print("    final result = await supabase.rpc('upsert_trabajadores_lote', params: {")
            print("      'p_lote': [...]")
            print("    });")

        elif r.status_code == 401:
            print(f"  ❌ HTTP 401 - Token inválido. Genera uno nuevo en:")
            print(f"     https://supabase.com/dashboard/account/tokens")
            sys.exit(1)
        else:
            print(f"  ❌ HTTP {r.status_code}: {r.text[:300]}")
            sys.exit(1)

    except httpx.TimeoutException:
        print("  ❌ Timeout. Ejecuta manualmente el SQL en el SQL Editor de Supabase:")
        print(f"     https://supabase.com/dashboard/project/{PROJECT_REF}/sql/new")
        print("     Pega el contenido de sql/06_rpc_upsert_trabajador_completo.sql")
        sys.exit(1)
    except Exception as e:
        print(f"  ❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()