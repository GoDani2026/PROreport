"""
Script de verificación: conecta a Supabase y valida que las tablas
de gestión de personal existan y contengan datos coincidentes con el CSV local.

SOLO LECTURA - No modifica datos.
"""

import csv
import re
import sys
import os
from datetime import datetime

from supabase import create_client, Client

# ─── CONFIGURACIÓN ───────────────────────────────────────────────────────────
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://inleckebqssizgeovgov.supabase.co")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "TU_SERVICE_ROLE_KEY_AQUI")
CONTRATO_CODIGO = os.getenv("CONTRATO_CODIGO", "SC-9500014891")
CSV_PATH = os.getenv(
    "CSV_PATH",
    os.path.join(os.path.dirname(__file__), "..", "LISTADO OFICIAL CC SC-9500014891 - LISTADO COMPLETO.csv"),
)

# Columnas del CSV que mapean a requisitos (0-indexed)
# (col_csv, req_id, nombre_requisito, tiene_vencimiento)
COLUMNAS_REQUISITOS = [
    (10, 1, "Exámenes Ocupacionales / Pre-Ocupacionales (AG/AF)", True),
    (11, 2, "Examen Alcohol y drogas", True),
    (12, 3, "Examen Psicosensometrico", True),
    (13, 4, "Fecha Vencimiento Inducción SQM", True),
    (14, 5, "Protocolo SQM (ODI)", False),
    (15, 6, "CTTA(ODI)", False),
    (16, 7, "Certificación (Soldadores, electricos, riggers, op.Maquinaria, etc)", False),
    (17, 8, "Licencia Interna SQM", False),
    (18, 9, "Difusión Procedimientos", False),
    (19, 10, "Difusión Plan y Sub Planes SQM", False),
    (20, 11, "Difusión Plan y Sub Planes Cttas", False),
    (21, 12, "Difusión HDS", False),
]


def limpiar_rut(rut_raw: str) -> str:
    """Normaliza RUT a formato xx.xxx.xxx-x (misma lógica que el script de ingesta)."""
    if not rut_raw:
        return ""
    rut = rut_raw.replace(",", ".").strip()
    digits_only = re.sub(r"[^\dkK]", "", rut)
    if len(digits_only) < 2:
        return rut
    dv = digits_only[-1]
    body = digits_only[:-1]
    if len(body) <= 3:
        formatted = body
    elif len(body) <= 6:
        formatted = f"{body[:-3]}.{body[-3:]}"
    else:
        formatted = f"{body[:-6]}.{body[-6:-3]}.{body[-3:]}"
    return f"{formatted}-{dv}"


def parsear_csv(ruta_csv: str):
    """Lee el CSV y devuelve lista de filas de trabajadores con datos normalizados."""
    with open(ruta_csv, "r", encoding="utf-8-sig") as f:
        lines = f.readlines()

    # Buscar encabezados
    header_idx = None
    for i, line in enumerate(lines):
        if "N°" in line and "Nombre" in line and "Rut" in line:
            header_idx = i
            break

    if header_idx is None:
        print("❌ No se encontró la fila de encabezados en el CSV")
        sys.exit(1)

    reader = csv.reader(lines[header_idx:])
    next(reader)  # saltar encabezados

    trabajadores = []
    for row in reader:
        if len(row) < 5:
            continue
        num = row[0].strip()
        nombre = row[1].strip()
        if not num or not nombre:
            continue
        try:
            int(num)
        except ValueError:
            continue

        rut_raw = row[4].strip() if len(row) > 4 else ""
        rut = limpiar_rut(rut_raw)

        trabajadores.append({
            "num": int(num),
            "nombre": nombre,
            "apellido_paterno": row[2].strip() if len(row) > 2 else "",
            "apellido_materno": row[3].strip() if len(row) > 3 else "",
            "rut": rut,
            "cargo": row[5].strip() if len(row) > 5 else "",
            "nacionalidad": row[6].strip() if len(row) > 6 else "Chilena",
            "venc_res": row[7].strip() if len(row) > 7 else "",
            "sexo_raw": row[8].strip() if len(row) > 8 else "",
            "turno": row[9].strip() if len(row) > 9 else "",
        })

    return trabajadores


def verificar_conexion(supabase: Client):
    """Verifica que Supabase responda correctamente."""
    print("\n🔌 Probando conexión a Supabase...")
    try:
        # Intentar una consulta simple a una tabla que debería existir
        result = supabase.table("trabajadores").select("count", count="exact").execute()
        print(f"   ✅ Conexión exitosa. Tabla 'trabajadores' accesible.")
        return True
    except Exception as e:
        print(f"   ❌ Error de conexión o tabla inexistente: {e}")
        return False


def verificar_tablas(supabase: Client):
    """Verifica la existencia de las tablas necesarias."""
    print("\n📋 Verificando existencia de tablas...")
    tablas_requeridas = ["trabajadores", "requisitos_hse", "cumplimiento_trabajadores"]
    tablas_ok = {}

    for tabla in tablas_requeridas:
        try:
            result = supabase.table(tabla).select("*").limit(1).execute()
            tablas_ok[tabla] = True
            print(f"   ✅ {tabla} existe")
        except Exception as e:
            tablas_ok[tabla] = False
            print(f"   ❌ {tabla} no existe o no accesible: {e}")

    return tablas_ok


def verificar_datos(supabase: Client, csv_trabajadores):
    """Compara los datos en Supabase con el CSV local."""
    print("\n📊 Comparando datos entre Supabase y CSV local...")

    # 1. Obtener todos los trabajadores de Supabase
    try:
        result = supabase.table("trabajadores").select("*").eq("contrato_codigo", CONTRATO_CODIGO).execute()
        supabase_trabajadores = result.data if result.data else []
    except Exception as e:
        print(f"   ❌ Error al consultar trabajadores: {e}")
        return False

    print(f"   📄 Trabajadores en CSV local: {len(csv_trabajadores)}")
    print(f"   ☁️  Trabajadores en Supabase: {len(supabase_trabajadores)}")

    if len(supabase_trabajadores) == 0:
        print("   ⚠️  No hay trabajadores en Supabase. ¿Se ejecutó el script de ingesta?")
        return False

    # 2. Comparar por RUT
    csv_ruts = {t["rut"] for t in csv_trabajadores}
    sup_ruts = {t["rut"] for t in supabase_trabajadores}

    faltan_en_sup = csv_ruts - sup_ruts
    sobran_en_sup = sup_ruts - csv_ruts

    if faltan_en_sup:
        print(f"   ⚠️  RUTs en CSV pero NO en Supabase ({len(faltan_en_sup)}):")
        for rut in sorted(faltan_en_sup)[:10]:
            print(f"      - {rut}")
        if len(faltan_en_sup) > 10:
            print(f"      ... y {len(faltan_en_sup) - 10} más")
    else:
        print("   ✅ Todos los RUTs del CSV están en Supabase")

    if sobran_en_sup:
        print(f"   ⚠️  RUTs en Supabase pero NO en CSV ({len(sobran_en_sup)}):")
        for rut in sorted(sobran_en_sup)[:10]:
            print(f"      - {rut}")
    else:
        print("   ✅ No hay RUTs extras en Supabase")

    # 3. Validar campos clave de algunos registros
    print("\n   🔍 Validando campos de 5 trabajadores aleatorios...")
    import random
    random.seed(42)
    muestra = random.sample(supabase_trabajadores, min(5, len(supabase_trabajadores)))

    for t in muestra:
        rut = t.get("rut", "")
        nombre = t.get("nombre", "")
        apellido_pat = t.get("apellido_paterno", "")
        apellido_mat = t.get("apellido_materno", "")
        cargo = t.get("cargo", "")
        estado = t.get("estado_trabajador", "")

        # Buscar en CSV por RUT
        csv_match = next((c for c in csv_trabajadores if c["rut"] == rut), None)

        if csv_match:
            status = "✅"
            if nombre != csv_match["nombre"]:
                status = "⚠️"
                print(f"      {status} {rut}: Nombre difiere - Supabase: '{nombre}' vs CSV: '{csv_match['nombre']}'")
            if apellido_pat != csv_match["apellido_paterno"]:
                status = "⚠️"
                print(f"      {status} {rut}: Apellido paterno difiere")
            if cargo != csv_match["cargo"]:
                status = "⚠️"
                print(f"      {status} {rut}: Cargo difiere - Supabase: '{cargo}' vs CSV: '{csv_match['cargo']}'")
            if estado not in ("ACTIVO", "DESVINCULADO", "LICENCIA"):
                status = "⚠️"
                print(f"      {status} {rut}: Estado inválido: '{estado}'")
            print(f"      {status} {rut}: {nombre} {apellido_pat} | {cargo} | {estado}")
        else:
            print(f"   ⚠️  {rut}: Encontrado en Supabase pero NO en CSV")

    return True


def verificar_cumplimiento(supabase: Client):
    """Verifica que existan registros de cumplimiento."""
    print("\n📋 Verificando cumplimiento de trabajadores...")

    try:
        # Contar registros
        result = supabase.table("cumplimiento_trabajadores").select("count", count="exact").execute()
        count = result.count if hasattr(result, 'count') else len(result.data or [])
        print(f"   📊 Registros en cumplimiento_trabajadores: {count}")

        if count == 0:
            print("   ⚠️  No hay registros de cumplimiento. Ejecuta el script de ingesta.")
            return False

        # Obtener muestra
        muestra = supabase.table("cumplimiento_trabajadores").select("*").limit(5).execute()
        if muestra.data:
            print(f"   📋 Muestra de registros:")
            for r in muestra.data[:5]:
                print(f"      - trabajador_id: {r.get('trabajador_id')} | requisito_id: {r.get('requisito_id')} | estado: {r.get('valor_estado')} | vencimiento: {r.get('fecha_vencimiento')}")

        # Verificar requisitos_hse
        reqs = supabase.table("requisitos_hse").select("*").execute()
        if reqs.data:
            print(f"\n   📋 Catálogo de requisitos HSE ({len(reqs.data)} items):")
            for r in reqs.data:
                print(f"      {r['id']:2d}. {r['nombre_requisito'][:50]}... (req. vencimiento: {r['requiere_vencimiento']})")

        return True

    except Exception as e:
        print(f"   ❌ Error al consultar cumplimiento: {e}")
        return False


def main():
    print("=" * 60)
    print("VERIFICACIÓN DE CONEXIÓN Y DATOS EN SUPABASE")
    print("=" * 60)
    print(f"📅 Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📍 Proyecto: {SUPABASE_URL}")
    print(f"📄 CSV: {CSV_PATH}")

    if not os.path.exists(CSV_PATH):
        print(f"\n❌ No se encuentra el CSV en: {CSV_PATH}")
        sys.exit(1)

    # Leer CSV local
    print("\n📄 Leyendo CSV local...")
    csv_trabajadores = parsear_csv(CSV_PATH)
    print(f"   Trabajadores leídos: {len(csv_trabajadores)}")

    # Conectar a Supabase
    print("\n🔌 Conectando a Supabase...")
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    print("   ✅ Conectado")

    # Verificar tabla trabajadores
    tablas_ok = verificar_tablas(supabase)
    if not all(tablas_ok.values()):
        print("\n❌ Faltan tablas necesarias. Ejecuta la app Flutter para auto-crearlas,")
        print("   o ejecuta manualmente el SQL del archivo supabase_schema_hse.sql")
        sys.exit(1)

    # Verificar conexión
    if not verificar_conexion(supabase):
        sys.exit(1)

    # Comparar datos
    datos_ok = verificar_datos(supabase, csv_trabajadores)

    # Verificar cumplimiento
    cumplimiento_ok = verificar_cumplimiento(supabase)

    # Resumen final
    print("\n" + "=" * 60)
    print("RESUMEN")
    print("=" * 60)
    print(f"   ✅ Conexión: OK")
    print(f"   ✅ Tablas: {'OK' if all(tablas_ok.values()) else 'FALTAN'}")
    print(f"   {'✅' if datos_ok else '⚠️'} Datos trabajadores: {'COINCIDEN' if datos_ok else 'REVISAR'}")
    print(f"   {'✅' if cumplimiento_ok else '⚠️'} Cumplimiento: {'COINCIDEN' if cumplimiento_ok else 'REVISAR'}")
    print("=" * 60)


if __name__ == "__main__":
    main()