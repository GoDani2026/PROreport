"""
Script para desplegar FULL_SCHEMA_PROreport.sql directamente en Supabase.
Ejecuta el esquema consolidado completo en un solo paso.

Uso:
    python scripts/deploy_full_schema.py
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
SCRIPT_PATH = os.path.join(BASE_DIR, "sql", "FULL_SCHEMA_PROreport.sql")


def main():
    print("=" * 60)
    print("  🚀 DESPLIEGUE FULL SCHEMA - PROreport")
    print("=" * 60)
    print(f"  Proyecto: {PROJECT_REF}")
    print(f"  Token: {ACCESS_TOKEN[:15]}...{ACCESS_TOKEN[-5:]}")
    print()

    # Verificar que el archivo existe
    if not os.path.exists(SCRIPT_PATH):
        print(f"  ❌ Archivo no encontrado: {SCRIPT_PATH}")
        print()
        print("  Asegúrate de ejecutar este script desde el directorio raíz:")
        print("  python scripts/deploy_full_schema.py")
        sys.exit(1)

    # Leer el SQL
    with open(SCRIPT_PATH, "r", encoding="utf-8") as f:
        sql = f.read()

    print(f"  📄 FULL_SCHEMA_PROreport.sql")
    print(f"  📏 {len(sql)} caracteres, ~{sql.count(';')} statements")
    print(f"  ⏳ Ejecutando... (timeout: 5 minutos)")
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
            timeout=300,  # 5 minutos
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
                    print(f"  ⚠️  {len(errors)} errores (de {len(result)} statements).")
                    print(f"  Primer error: {errors[0][:300]}")
                    print()
                    print("  💡 Revisa el SQL Editor de Supabase para más detalles:")
                    print(f"     https://supabase.com/dashboard/project/{PROJECT_REF}/sql/new")
                    sys.exit(1)
                print(f"  ✅ OK - {len(result)} statements ejecutados exitosamente")
            else:
                print(f"  ✅ OK - Respuesta: {result}")
            
            print()
            print("=" * 60)
            print("  🎉 DESPLIEGUE EXITOSO!")
            print("=" * 60)
            print()
            print("  📌 Post-instalación (ejecutar en SQL Editor):")
            print("     SELECT public.sincronizar_trabajador_actual();")
            print()
            print("  📌 Verificar tablas:")
            print("     SELECT table_name FROM information_schema.tables")
            print("     WHERE table_schema = 'public' ORDER BY table_name;")

        elif r.status_code == 401:
            print(f"  ❌ HTTP 401 - Token inválido o expirado.")
            print(f"  Respuesta: {r.text[:200]}")
            print()
            print("  📌 Genera un nuevo token en:")
            print("     https://supabase.com/dashboard/account/tokens")
            sys.exit(1)
        else:
            print(f"  ❌ HTTP {r.status_code}: {r.text[:300]}")
            sys.exit(1)

    except httpx.TimeoutException:
        print("  ❌ Timeout: El script tardó más de 5 minutos.")
        print()
        print("  💡 Ejecuta manualmente en el SQL Editor:")
        print(f"     https://supabase.com/dashboard/project/{PROJECT_REF}/sql/new")
        print("     Pega el contenido de sql/FULL_SCHEMA_PROreport.sql")
        sys.exit(1)
    except Exception as e:
        print(f"  ❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()