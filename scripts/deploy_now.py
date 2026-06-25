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
SCRIPTS = [
    "sql/01_schema_autenticacion.sql",
    "sql/02_schema_gestion_personal.sql",
    "sql/03_schema_solicitud_levantamiento.sql",
    "sql/04_migracion_consolidacion_hse.sql",
    "sql/05_rpc_transaccionales.sql",
]

headers = {
    "Authorization": f"Bearer {ACCESS_TOKEN}",
    "Content-Type": "application/json",
}


def ejecutar_script(script_path, label):
    full_path = os.path.join(BASE_DIR, script_path)
    if not os.path.exists(full_path):
        return f"❌ Archivo no encontrado: {full_path}"
    
    with open(full_path, "r", encoding="utf-8") as f:
        sql = f.read()
    
    print(f"   📏 {len(sql)} caracteres, ~{sql.count(';')} statements")
    print(f"   ⏳ Ejecutando...")
    
    try:
        r = httpx.post(URL, headers=headers, json={"query": sql}, timeout=300)
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
                    return f"⚠️  {len(errors)} errores (de {len(result)} statements). Primer error: {errors[0][:200]}"
                return f"✅ OK - {len(result)} statements ejecutados"
            return "✅ OK"
        else:
            return f"❌ HTTP {r.status_code}: {r.text[:300]}"
    except httpx.TimeoutException:
        return "❌ Timeout (excedió 5 min)"
    except Exception as e:
        return f"❌ Error: {e}"


def main():
    print("=" * 60)
    print("  🚀 DESPLIEGUE SUPABASE - PROreport")
    print("=" * 60)
    print(f"  Proyecto: {PROJECT_REF}")
    print(f"  Token: {ACCESS_TOKEN[:15]}...{ACCESS_TOKEN[-5:]}\n")
    
    resultados = []
    
    for i, script in enumerate(SCRIPTS, 1):
        print(f"  [{i}/5] {script}")
        resultado = ejecutar_script(script, script)
        print(f"  {resultado}\n")
        resultados.append((script, resultado))
    
    print("=" * 60)
    print("  📋 RESUMEN")
    print("=" * 60)
    todos_ok = True
    for script, r in resultados:
        icon = "✅" if r.startswith("✅") else "❌"
        status = "OK" if r.startswith("✅") else "ERROR"
        if not r.startswith("✅"):
            todos_ok = False
        print(f"  {icon} {script}: {status}")
    
    if todos_ok:
        print("\n  🎉 DESPLIEGUE EXITOSO!")
        print("\n  📌 Post-migración (ejecutar en SQL Editor):")
        print("     SELECT public.sincronizar_usuarios_existentes();")
    else:
        print("\n  ⚠️  Algunos scripts fallaron. Revisa los errores arriba.")
    
    print("=" * 60)


if __name__ == "__main__":
    main()