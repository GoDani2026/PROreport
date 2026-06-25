"""
Script de despliegue de esquemas SQL en Supabase via Management API.
Ejecuta los 5 scripts SQL en orden sobre el proyecto Supabase configurado.

Uso:
    python scripts/desplegar_schemas.py

Requisitos:
    pip install httpx

Antes de ejecutar:
    1. Ir a: https://supabase.com/dashboard/account/tokens
    2. Crear un nuevo Access Token (Settings → API → Access Tokens)
    3. Copiar el token y pegarlo cuando el script lo solicite
"""

import os
import sys
import httpx

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '.'))
import env as _env
_env.load_env()

PROJECT_REF = os.environ.get('PROJECT_REF', '')
MANAGEMENT_API = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"

SCRIPT_DIR = os.path.join(os.path.dirname(__file__), "..", "sql")
SCRIPTS_ORDER = [
    "01_schema_autenticacion.sql",
    "02_schema_gestion_personal.sql",
    "03_schema_solicitud_levantamiento.sql",
    "04_migracion_consolidacion_hse.sql",
    "05_rpc_transaccionales.sql",
]


def ejecutar_sql_management_api(access_token: str, sql: str, etiqueta: str) -> tuple:
    """
    Ejecuta SQL en Supabase usando la Management API (v1/projects/{ref}/database/query).
    Esta API permite ejecutar DDL (CREATE TABLE, ALTER, CREATE FUNCTION, etc.)
    a diferencia de PostgREST que solo acepta CRUD.
    """
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    payload = {"query": sql}

    try:
        response = httpx.post(
            MANAGEMENT_API,
            headers=headers,
            json=payload,
            timeout=180,  # 3 minutos para scripts grandes
        )

        if response.status_code == 200:
            result = response.json()
            if isinstance(result, list):
                # Resumen de resultados (cada elemento es un statement ejecutado)
                total = len(result)
                errores = [r for r in result if "error" in r or r.get("result") == "ERROR"]
                if errores:
                    msgs = "; ".join(e.get("error", str(e))[:100] for e in errores[:3])
                    return False, f"{len(errores)}/{total} statements fallaron: {msgs}"
                return True, f"OK ({total} statements)"
            return True, "OK"
        elif response.status_code == 401:
            error_body = response.text[:200]
            if "Invalid token" in error_body or "JWT" in error_body:
                return False, "Token inválido. Genera un nuevo Access Token en:\n   https://supabase.com/dashboard/account/tokens"
            return False, f"HTTP 401 (no autorizado): {error_body}"
        elif response.status_code == 403:
            return False, f"HTTP 403 (sin permisos): {response.text[:200]}"
        elif response.status_code == 404:
            return False, f"HTTP 404 - Proyecto '{PROJECT_REF}' no encontrado. Verifica el project-ref."
        else:
            return False, f"HTTP {response.status_code}: {response.text[:300]}"

    except httpx.TimeoutException:
        return False, "Timeout: El script tardó más de 180 segundos. Intenta ejecutarlo manualmente."
    except httpx.ConnectError as e:
        return False, f"Error de conexión: {e}"
    except Exception as e:
        return False, str(e)


def main():
    print("=" * 60)
    print("🚀 DESPLIEGUE DE ESQUEMAS SUPABASE - PROreport")
    print("=" * 60)
    print(f"📦 Proyecto: {PROJECT_REF}")

    # ─── Solicitar Access Token ──────────────────────────────────────────────
    print("\n" + "─" * 60)
    print("🔑 SE REQUIERE UN ACCESS TOKEN DE SUPABASE")
    print("─" * 60)
    print("La service_role key NO puede ejecutar DDL (CREATE TABLE, etc.).")
    print("Necesitas un Personal Access Token (PAT) de Management API.")
    print()
    print("📌 Para obtenerlo:")
    print("   1. Abrir: https://supabase.com/dashboard/account/tokens")
    print("   2. Crear un nuevo token (Settings → API → Access Tokens)")
    print("   3. Copiarlo y pegarlo aquí")
    print()
    
    access_token = input("👉 Pega tu Access Token de Supabase: ").strip()

    if not access_token:
        print("\n❌ No se ingresó ningún token. Saliendo...")
        print("\n💡 Ejecución manual alternativa:")
        print("   Abre el SQL Editor de Supabase:")
        print(f"   https://supabase.com/dashboard/project/{PROJECT_REF}/sql/new")
        print("   Y pega el contenido de sql/FULL_SCHEMA_PROreport.sql")
        sys.exit(1)

    # Verificar formato del token
    if len(access_token) < 20:
        print("\n⚠️  El token parece muy corto. Los tokens de Supabase suelen tener 40+ caracteres.")
        confirmar = input("   ¿Continuar de todas formas? (s/N): ").strip().lower()
        if confirmar != "s":
            print("   Cancelado.")
            sys.exit(1)

    # ─── Ejecutar scripts ────────────────────────────────────────────────────
    resultados = []
    todos_exitosos = True

    for i, script_name in enumerate(SCRIPTS_ORDER, 1):
        script_path = os.path.join(SCRIPT_DIR, script_name)
        
        print(f"\n{'─' * 60}")
        print(f"📄 [{i}/{len(SCRIPTS_ORDER)}] {script_name}")
        print(f"{'─' * 60}")

        if not os.path.exists(script_path):
            print(f"   ❌ Archivo no encontrado: {script_path}")
            resultados.append((script_name, False, "Archivo no encontrado"))
            todos_exitosos = False
            continue

        with open(script_path, "r", encoding="utf-8") as f:
            sql_content = f.read()

        print(f"   📏 {len(sql_content)} caracteres, ~{sql_content.count(';')} statements")
        print(f"   ⏳ Ejecutando...")

        exito, mensaje = ejecutar_sql_management_api(access_token, sql_content, script_name)

        if exito:
            print(f"   ✅ {mensaje}")
            resultados.append((script_name, True, mensaje))
        else:
            print(f"   ❌ {mensaje}")
            resultados.append((script_name, False, mensaje))
            todos_exitosos = False

    # ─── Resumen Final ───────────────────────────────────────────────────────
    print(f"\n{'=' * 60}")
    print("📋 RESUMEN DEL DESPLIEGUE")
    print(f"{'=' * 60}")
    
    for name, ok, msg in resultados:
        icon = "✅" if ok else "❌"
        print(f"   {icon} {name}: {msg[:80]}")

    if todos_exitosos:
        print(f"\n{'=' * 60}")
        print("🎉 DESPLIEGUE EXITOSO")
        print(f"{'=' * 60}")
        print()
        print("📌 Próximos pasos:")
        print("   1. Abrir el SQL Editor de Supabase:")
        print(f"      https://supabase.com/dashboard/project/{PROJECT_REF}/sql/new")
        print("   2. Ejecutar: SELECT public.sincronizar_usuarios_existentes();")
        print()
        print("📌 Opcional - Verificar tablas creadas:")
        print("   Ejecutar en SQL Editor:")
        print("   SELECT table_name FROM information_schema.tables")
        print("   WHERE table_schema = 'public' ORDER BY table_name;")
    else:
        print(f"\n{'=' * 60}")
        print("⚠️  HUBO ERRORES EN ALGUNOS SCRIPTS")
        print(f"{'=' * 60}")
        print()
        print("📌 Posibles causas:")
        print("   • Token inválido o sin permisos suficientes")
        print("   • El script ya fue ejecutado parcialmente (usar IF NOT EXISTS)")
        print("   • Error de sintaxis SQL")
        print()
        print("📌 Solución manual:")
        print("   1. Abrir: https://supabase.com/dashboard/project/{PROJECT_REF}/sql/new")
        print("   2. Pegar el contenido de sql/FULL_SCHEMA_PROreport.sql (TODO en uno)")
        print("   3. Ejecutar")
        print()
        print("💡 Para reintentar automáticamente, ejecuta el script de nuevo")
        print("   Los scripts usan IF NOT EXISTS, así que son idempotentes")


if __name__ == "__main__":
    main()