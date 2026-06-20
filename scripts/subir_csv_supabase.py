"""
Script de ingesta: Carga el LISTADO OFICIAL CSV a Supabase.
Estructura:
  1. Lee y parsea el CSV
  2. Limpia/normaliza datos (RUTs, fechas, valores)
  3. Inserta trabajadores en tabla 'trabajadores'
  4. Inserta cumplimiento en 'cumplimiento_trabajadores'
"""

import csv
import re
import sys
import os
from datetime import datetime, date
from dateutil import parser as dateparser

from supabase import create_client, Client

# ─── CONFIGURACIÓN ───────────────────────────────────────────────────────────
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://inleckebqssizgeovgov.supabase.co")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "TU_SERVICE_ROLE_KEY_AQUI")
CONTRATO_CODIGO = os.getenv("CONTRATO_CODIGO", "SC-9500014891")
CSV_PATH = os.getenv(
    "CSV_PATH",
    os.path.join(os.path.dirname(__file__), "..", "LISTADO OFICIAL CC SC-9500014891 - LISTADO COMPLETO.csv"),
)

# Mapeo: columna CSV (0-indexed) -> (requisito_id, requiere_vencimiento)
COLUMNAS_REQUISITOS = [
    (10, 1, True),   # Exámenes Ocup/PreOcup (AG/AF)
    (11, 2, True),   # Examen Alcohol y drogas
    (12, 3, True),   # Examen Psicosensometrico
    (13, 4, True),   # Fecha Vencimiento Inducción SQM
    (14, 5, False),  # Protocolo SQM (ODI)
    (15, 6, False),  # CTTA(ODI)
    (16, 7, False),  # Certificación (Soldadores, electricos, riggers, etc)
    (17, 8, False),  # Licencia Interna SQM
    (18, 9, False),  # Difusión Procedimientos
    (19, 10, False), # Difusión Plan y Sub Planes SQM
    (20, 11, False), # Difusión Plan y Sub Planes Cttas
    (21, 12, False), # Difusión HDS
]

# ─── FUNCIONES AUXILIARES ────────────────────────────────────────────────────

def limpiar_rut(rut_raw: str) -> str:
    """Limpia y normaliza un RUT chileno a formato xx.xxx.xxx-x."""
    if not rut_raw:
        return ""
    # 1. Reemplazar comas por puntos (ej: "201,261,406" -> "201.261.406")
    rut = rut_raw.replace(",", ".")
    # 2. Eliminar espacios
    rut = rut.strip()
    # 3. Extraer solo dígitos y la letra K (si es DV)
    digits_only = re.sub(r"[^\dkK]", "", rut)
    if len(digits_only) < 2:
        return rut  # no se puede procesar, devolver original
    # 4. El último carácter es el dígito verificador, el resto es el cuerpo
    dv = digits_only[-1]
    body = digits_only[:-1]
    # 5. Formatear cuerpo con puntos
    if len(body) <= 3:
        formatted = body
    elif len(body) <= 6:
        formatted = f"{body[:-3]}.{body[-3:]}"
    else:
        formatted = f"{body[:-6]}.{body[-6:-3]}.{body[-3:]}"
    return f"{formatted}-{dv}"


def parsear_fecha(valor: str):
    """
    Intenta parsear una fecha desde el valor del CSV.
    Retorna (date_obj, es_valida).
    Si no es una fecha reconocible, retorna (None, False).
    """
    if not valor:
        return None, False
    valor = valor.strip().strip('"')
    if not valor:
        return None, False
    # Casos especiales no-fecha
    if valor.upper() in ("N/A", "NA", "NO", "SI", ""):
        return None, False
    # Limpiar caracteres extraños alrededor
    valor = re.sub(r'[^\d/\.\-]', '', valor)
    if not valor:
        return None, False
    try:
        # Intentar parsear con dateutil (flexible)
        dt = dateparser.parse(valor, dayfirst=False)
        if dt:
            return dt.date(), True
    except Exception:
        pass
    return None, False


def determinar_valor_estado(valor: str, tiene_vencimiento: bool, fecha_valida: bool) -> str:
    """
    Determina el valor_estado (VIGENTE, SI, NO, N/A) según el valor del CSV
    y si el requisito tiene vencimiento o no.
    """
    if not valor:
        return "NO"
    v = valor.strip().upper()
    if v in ("N/A", "NA"):
        return "N/A"
    if v == "SI":
        return "SI"
    if v == "NO":
        return "NO"
    # Si es un valor con fecha
    if tiene_vencimiento and fecha_valida:
        return "VIGENTE"
    # Si tiene fecha pero no se pudo parsear, asumir VIGENTE de todas formas
    if tiene_vencimiento and valor.strip():
        return "VIGENTE"
    return "NO"


# ─── PROCESO PRINCIPAL ──────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("Ingesta de LISTADO OFICIAL a Supabase")
    print("=" * 60)

    # 1. Leer CSV
    if not os.path.exists(CSV_PATH):
        print(f"❌ No se encuentra el CSV en: {CSV_PATH}")
        sys.exit(1)

    with open(CSV_PATH, "r", encoding="utf-8-sig") as f:
        lines = f.readlines()

    print(f"📄 Archivo leído: {CSV_PATH}")
    print(f"   Total líneas: {len(lines)}")

    # Buscar la fila de encabezados (contiene "N°,Nombre")
    header_idx = None
    for i, line in enumerate(lines):
        if "N°" in line and "Nombre" in line and "Rut" in line:
            header_idx = i
            break

    if header_idx is None:
        print("❌ No se encontró la fila de encabezados")
        sys.exit(1)

    print(f"   Encabezados encontrados en línea {header_idx + 1}")

    # Leer CSV desde la fila de encabezados
    reader = csv.reader(lines[header_idx:])
    headers = next(reader)
    print(f"   Columnas: {len(headers)}")

    # Filtrar solo filas con datos (que tengan al menos N° y Nombre)
    trabajadores_raw = []
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
        trabajadores_raw.append(row)

    print(f"   Trabajadores encontrados: {len(trabajadores_raw)}")

    if len(trabajadores_raw) == 0:
        print("❌ No hay trabajadores para procesar")
        sys.exit(1)

    # 2. Conectar a Supabase
    print("\n🔌 Conectando a Supabase...")
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    print("✅ Conectado!")

    # 3. Insertar trabajadores (uno por uno con upsert por RUT)
    print("\n📋 Insertando trabajadores...")
    trabajadores_insertados = 0
    trabajadores_actualizados = 0
    trabajadores_con_error = []

    for row in trabajadores_raw:
        try:
            num = row[0].strip()
            nombre = row[1].strip()
            apellido_pat = row[2].strip() if len(row) > 2 else ""
            apellido_mat = row[3].strip() if len(row) > 3 else ""
            rut_raw = row[4].strip() if len(row) > 4 else ""
            cargo = row[5].strip() if len(row) > 5 else ""
            nacionalidad = row[6].strip() if len(row) > 6 else "Chilena"
            venc_res = row[7].strip() if len(row) > 7 else ""
            sexo_raw = row[8].strip() if len(row) > 8 else ""
            turno = row[9].strip() if len(row) > 9 else ""

            # Limpiar RUT
            rut = limpiar_rut(rut_raw)

            # Mapear sexo
            if sexo_raw.upper() in ("HOMBRE", "MASCULINO", "M"):
                sexo = "M"
            elif sexo_raw.upper() in ("MUJER", "FEMENINO", "F"):
                sexo = "F"
            else:
                sexo = sexo_raw[0].upper() if sexo_raw else "M"

            # Limpiar nacionalidad (algunas vienen con género: "Boliviana" -> "Boliviana" ok)
            nacionalidad = nacionalidad.strip()

            # Si vencimiento de residencia es "N/A" o "PERMANENCIA DEFINITIVA", guardar como está
            if venc_res.upper() in ("N/A", "NA", ""):
                venc_res = ""
            elif "PERMANENCIA" in venc_res.upper():
                venc_res = "PERMANENCIA DEFINITIVA"

            # Upsert trabajador por RUT
            data = {
                "rut": rut,
                "nombre": nombre,
                "apellido_paterno": apellido_pat,
                "apellido_materno": apellido_mat if apellido_mat else None,
                "cargo": cargo,
                "nacionalidad": nacionalidad,
                "vencimiento_residencia": venc_res if venc_res else None,
                "sexo": sexo,
                "turno": turno,
                "contrato_codigo": CONTRATO_CODIGO,
            }

            # Intentar upsert
            result = supabase.table("trabajadores").upsert(
                data, on_conflict="rut"
            ).execute()

            if result.data:
                trabajadores_insertados += 1
                if len(result.data) > 0:
                    print(f"   ✅ {num:>2}. {nombre} {apellido_pat} (RUT: {rut})")
            else:
                print(f"   ⚠️  {num:>2}. {nombre} {apellido_pat} -> sin respuesta")
                trabajadores_con_error.append((num, rut, "sin respuesta"))

        except Exception as e:
            print(f"   ❌ {num:>2}. Error: {e}")
            trabajadores_con_error.append((num, row[4].strip() if len(row) > 4 else "", str(e)))

    print(f"\n📊 Resultado trabajadores:")
    print(f"   Insertados/Actualizados: {trabajadores_insertados}")
    print(f"   Errores: {len(trabajadores_con_error)}")
    if trabajadores_con_error:
        for err in trabajadores_con_error[:5]:
            print(f"      - N°{err[0]} RUT:{err[1]}: {err[2]}")

    # 4. Obtener IDs de trabajadores insertados (para vincular cumplimiento)
    print("\n🔍 Recuperando IDs de trabajadores...")
    result = supabase.table("trabajadores").select("id, rut").eq("contrato_codigo", CONTRATO_CODIGO).execute()
    trabajadores_map = {}  # rut -> id
    if result.data:
        for t in result.data:
            trabajadores_map[t["rut"]] = t["id"]
    print(f"   IDs recuperados: {len(trabajadores_map)}")

    # 5. Insertar cumplimiento
    print("\n📋 Insertando cumplimiento de trabajadores...")
    cumplimiento_insertados = 0
    cumplimiento_errores = 0

    for row in trabajadores_raw:
        num = row[0].strip()
        rut_raw = row[4].strip()
        rut = limpiar_rut(rut_raw)
        trabajador_id = trabajadores_map.get(rut)
        if not trabajador_id:
            print(f"   ⚠️  N°{num}: Trabajador {rut} no encontrado en BD, saltando cumplimiento")
            continue

        for col_idx, req_id, tiene_venc in COLUMNAS_REQUISITOS:
            if col_idx >= len(row):
                continue
            valor_raw = row[col_idx].strip() if len(row) > col_idx else ""
            valor = valor_raw.strip()

            if tiene_venc:
                # Intentar parsear fecha
                fecha_parsed, es_valida = parsear_fecha(valor)
                estado = determinar_valor_estado(valor, tiene_venc, es_valida)
                fecha_str = str(fecha_parsed) if es_valida else None
            elif req_id in (5, 6):
                # ODI: Protocolo SQM (ODI) y CTTA(ODI) no tienen vencimiento
                # según catálogo, pero en el CSV pueden traer fecha.
                # Si traen fecha, se guarda como VIGENTE con fecha_vencimiento.
                fecha_parsed, es_valida = parsear_fecha(valor)
                if es_valida:
                    estado = "VIGENTE"
                    fecha_str = str(fecha_parsed)
                else:
                    estado = determinar_valor_estado(valor, tiene_venc, False)
                    fecha_str = None
            else:
                estado = determinar_valor_estado(valor, tiene_venc, False)
                fecha_str = None

            try:
                cumpl_data = {
                    "trabajador_id": trabajador_id,
                    "requisito_id": req_id,
                    "valor_estado": estado,
                    "fecha_vencimiento": fecha_str,
                }
                supabase.table("cumplimiento_trabajadores").upsert(
                    cumpl_data, on_conflict="trabajador_id, requisito_id"
                ).execute()
                cumplimiento_insertados += 1
            except Exception as e:
                print(f"   ❌ N°{num} req_id={req_id}: {e}")
                cumplimiento_errores += 1

    print(f"\n📊 Resultado cumplimiento:")
    print(f"   Insertados: {cumplimiento_insertados}")
    print(f"   Errores: {cumplimiento_errores}")

    # 6. Resumen final
    print("\n" + "=" * 60)
    print("RESUMEN FINAL")
    print("=" * 60)
    print(f"   Trabajadores procesados: {trabajadores_insertados}")
    print(f"   Registros de cumplimiento: {cumplimiento_insertados}")
    if trabajadores_con_error:
        print(f"   ⚠️  Errores en trabajadores: {len(trabajadores_con_error)}")
    if cumplimiento_errores > 0:
        print(f"   ⚠️  Errores en cumplimiento: {cumplimiento_errores}")
    print("=" * 60)
    print("✅ Proceso completado!")


if __name__ == "__main__":
    main()