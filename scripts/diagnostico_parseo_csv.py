#!/usr/bin/env python3
"""
Diagnóstico de parseo de la carga masiva CSV.
Replica la lógica exacta de la app Flutter:
  - _mapearFila() parsea columnas posicionales (0-21)
  - parsearFechaCsv() 
  - estadoDesdeFecha()
  - Validación de RUT
"""
import csv
import re
from datetime import datetime, date
from collections import namedtuple

ARCHIVO = "LISTADO OFICIAL CC SC-9500014891 - LISTADO COMPLETO.csv"

NOMBRES_REQUISITOS = [
    'Exámenes Ocupacionales',        # i=0, col 10
    'Alcohol/Drogas',                # i=1, col 11
    'Psicosensométrico',             # i=2, col 12
    'Inducción SQM',                 # i=3, col 13
    'Protocolo SQM (ODI)',           # i=4, col 14
    'CTTA(ODI)',                     # i=5, col 15
    'Certificación',                 # i=6, col 16
    'Licencia Interna SQM',          # i=7, col 17
    'Dif. Procedimientos',           # i=8, col 18
    'Dif. Plan SQM',                 # i=9, col 19
    'Dif. Plan CTTAS',               # i=10, col 20
    'Dif. HDS',                      # i=11, col 21
]

def validar_rut(raw):
    """Valida y formatea RUT chileno como la app.
    Soporta formatos: 12.345.678-9, 12,345,678-9, 12.345.678.9 (punto como separador)."""
    if not raw:
        return None
    # Reemplazar comas por puntos (ej: "201,261,406" -> "201.261.406")
    s = raw.replace(',', '.').strip()
    # Si tiene puntos pero NO guión, el DV puede estar después del último punto
    if '.' in s and '-' not in s:
        partes = s.split('.')
        if len(partes) >= 2:
            dv = partes.pop()
            s = '.'.join(partes) + '-' + dv
    limpio = s.replace('.', '').replace('-', '').replace(' ', '').upper()
    if len(limpio) < 8 or len(limpio) > 9:
        return None
    if not re.match(r'^\d+[\dK]$', limpio):
        return None
    # Calcular DV
    cuerpo = limpio[:-1]
    dv = limpio[-1]
    suma = 0
    multiplicador = 2
    for c in reversed(cuerpo):
        suma += int(c) * multiplicador
        multiplicador = 2 if multiplicador == 7 else multiplicador + 1
    resto = suma % 11
    dv_calc = {0: '0', 1: 'K'}.get(resto, str(11 - resto))
    if dv != dv_calc:
        return None
    # Formatear
    partes = []
    temp = cuerpo
    while len(temp) > 3:
        partes.insert(0, temp[-3:])
        temp = temp[:-3]
    if temp:
        partes.insert(0, temp)
    return f"{'.'.join(partes)}-{dv}"

def parsear_fecha(raw):
    """Replica Validators.parsearFechaCsv() actualizada."""
    v = raw.strip()
    if not v or v.upper() == 'N/A':
        return ''
    # yyyy-MM-dd
    if re.match(r'^\d{4}-\d{2}-\d{2}$', v):
        return v
    partes = None
    if '/' in v:
        partes = v.split('/')
    elif '-' in v:
        # Solo si parece fecha (no es un RUT)
        partes = v.split('-')
    if not partes or len(partes) != 3:
        return ''
    try:
        p1, p2, anio = int(partes[0]), int(partes[1]), int(partes[2])
        if 1900 < anio < 2100:
            if p1 > 12:
                return f"{anio}-{p2:02d}-{p1:02d}"
            else:
                return f"{anio}-{p1:02d}-{p2:02d}"
    except:
        pass
    return ''

def estado_desde_fecha(fecha_str):
    """Replica Validators.estadoDesdeFecha()."""
    if not fecha_str:
        return 'N/A'
    try:
        f = datetime.strptime(fecha_str, '%Y-%m-%d').date()
        return 'VIGENTE' if f > date.today() else 'VENCIDO'
    except:
        return 'N/A'

def normalizar_sexo(raw):
    v = raw.strip().lower()
    if v in ('hombre', 'm', 'masculino', 'h'):
        return 'M'
    if v in ('mujer', 'f', 'femenino'):
        return 'F'
    return 'M'

def parsear_fila(fila, num_linea):
    """Replica _mapearFila()"""
    def get_col(idx):
        return fila[idx].strip() if idx < len(fila) else ''
    
    rut_raw = get_col(4)
    rut_valido = validar_rut(rut_raw)
    nombre = get_col(1)
    ap_paterno = get_col(2)
    ap_materno = get_col(3)
    cargo = get_col(5)
    nacionalidad = get_col(6)
    venc_res = get_col(7)
    sexo = normalizar_sexo(get_col(8))
    turno = get_col(9)
    
    errores = []
    if not rut_valido:
        errores.append('RUT inválido')
    if not nombre:
        errores.append('Nombre obligatorio')
    if not ap_paterno:
        errores.append('Ap. Paterno obligatorio')
    if not cargo:
        errores.append('Cargo obligatorio')
    
    if not rut_valido:
        rut_formateado = rut_raw.replace(',', '.')
    else:
        rut_formateado = rut_valido
    
    cumplimientos = []
    for i in range(12):
        raw = get_col(10 + i)
        fecha_str = parsear_fecha(raw)
        if fecha_str and re.match(r'^\d{4}-\d{2}-\d{2}$', fecha_str):
            estado = estado_desde_fecha(fecha_str)
            fecha = fecha_str
        else:
            upper = raw.strip().upper()
            if upper in ('SI', 'SÍ'):
                estado = 'VIGENTE'
                fecha = None
            elif upper in ('NO', 'N/A', 'NA', ''):
                estado = 'N/A'
                fecha = None
            else:
                estado = 'VENCIDO'
                fecha = None
        cumplimientos.append({
            'requisito': NOMBRES_REQUISITOS[i],
            'raw': raw,
            'estado': estado,
            'fecha': fecha,
        })
    
    return {
        'linea': num_linea,
        'rut': rut_formateado,
        'nombre': nombre,
        'ap_paterno': ap_paterno,
        'ap_materno': ap_materno,
        'cargo': cargo,
        'nacionalidad': nacionalidad,
        'sexo': sexo,
        'turno': turno,
        'errores': errores,
        'cumplimientos': cumplimientos,
    }


def main():
    print("=" * 100)
    print("DIAGNÓSTICO DE PARSEO DE CARGA MASIVA CSV")
    print("=" * 100)
    print(f"Archivo: {ARCHIVO}")
    print(f"Fecha actual: {date.today()}")
    print("=" * 100)

    with open(ARCHIVO, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replicar _splitCsv correctamente (manejo de comillas)
    lines = content.split('\n')
    
    def split_csv(line):
        out = []
        sb = ''
        in_quotes = False
        i = 0
        while i < len(line):
            c = line[i]
            if c == '"':
                if in_quotes and i + 1 < len(line) and line[i + 1] == '"':
                    sb += '"'
                    i += 1
                else:
                    in_quotes = not in_quotes
            elif c == ',' and not in_quotes:
                out.append(sb)
                sb = ''
            else:
                sb += c
            i += 1
        out.append(sb)
        return out

    # Parsear todo
    all_rows = []
    for i, line in enumerate(lines):
        cols = split_csv(line)
        if len(cols) <= 1 and cols[0].strip() == '':
            continue
        all_rows.append(cols)
    
    # Encontrar header (replicando _encontrarHeader)
    hdr_idx = -1
    for i, row in enumerate(all_rows):
        if len(row) < 10:
            continue
        if any('rut' in c.lower().strip() for c in row):
            hdr_idx = i
            break
        if hdr_idx == -1 and any('nombre' in c.lower().strip() for c in row):
            hdr_idx = i
    
    if hdr_idx == -1:
        print("ERROR: No se encontró cabecera")
        return
    
    print(f"\nHeader encontrado en línea {hdr_idx}:")
    header = all_rows[hdr_idx]
    for i, h in enumerate(header):
        print(f"  Col {i}: '{h}'")
    
    num_cols = len(header)
    data_rows = all_rows[hdr_idx + 1:]
    
    # Pad rows (como la app)
    padded = []
    for r in data_rows:
        if len(r) >= num_cols:
            padded.append(r)
        else:
            p = list(r)
            while len(p) < num_cols:
                p.append('')
            padded.append(p)
    
    # Filtrar solo filas de datos (replicando _esFilaDatos)
    def es_fila_datos(row):
        if len(row) < 5:
            return False
        col1 = row[1].strip().upper() if len(row) > 1 else ''
        if not col1:
            return False
        if col1 in ('FIRMA', 'OBSERVACIONES', 'OBSERVACIÓN', 'TOTAL', 'SUBTOTAL', 'NOTA'):
            return False
        col4 = row[4].strip() if len(row) > 4 else ''
        return len(col4) >= 6
    
    data_rows_filtradas = [r for r in padded if es_fila_datos(r)]
    
    print(f"\nTotal filas de datos encontradas: {len(data_rows_filtradas)}")
    print(f"Columnas en cabecera: {num_cols}")
    print("=" * 100)
    
    if not data_rows_filtradas:
        print("ERROR: No hay filas de datos")
        return
    
    # Parsear cada fila
    total_invalidos = 0
    total_validos = 0
    req_estados = {r: {'VIGENTE': 0, 'VENCIDO': 0, 'N/A': 0} for r in NOMBRES_REQUISITOS}
    
    print("\n--- RESULTADOS POR FILA ---\n")
    
    for i, row in enumerate(data_rows_filtradas):
        num_linea_real = hdr_idx + 1 + i + 1  # +1 por cabecera, +1 por 1-based
        parsed = parsear_fila(row, num_linea_real)
        
        simbolo = '✅' if not parsed['errores'] else '❌'
        print(f"{simbolo} Fila {num_linea_real} ({parsed['rut']}): {parsed['nombre']} {parsed['ap_paterno']} — {parsed['cargo']}")
        
        if parsed['errores']:
            total_invalidos += 1
            for e in parsed['errores']:
                print(f"       ↳ ERROR: {e}")
        else:
            total_validos += 1
        
        # Mostrar cumplimientos
        for c in parsed['cumplimientos']:
            req_estados[c['requisito']][c['estado']] += 1
            if c['estado'] == 'VENCIDO':
                print(f"       ⚠️  {c['requisito']}: {c['estado']} (raw='{c['raw']}')")
        
        if parsed['cumplimientos']:
            vigentes = sum(1 for c in parsed['cumplimientos'] if c['estado'] == 'VIGENTE')
            vencidos = sum(1 for c in parsed['cumplimientos'] if c['estado'] == 'VENCIDO')
            nas = sum(1 for c in parsed['cumplimientos'] if c['estado'] == 'N/A')
            print(f"       Resumen HSE: {vigentes}V 🟢 | {vencidos}X 🔴 | {nas}- ⚪")
    
    print("\n" + "=" * 100)
    print(f"RESUMEN TOTAL: {total_validos} válidos | {total_invalidos} inválidos")
    print("=" * 100)
    
    # Resumen por requisito
    print("\n--- ESTADO POR REQUISITO (total filas: {}) ---".format(total_validos + total_invalidos))
    for r in NOMBRES_REQUISITOS:
        est = req_estados[r]
        total = est['VIGENTE'] + est['VENCIDO'] + est['N/A']
        if total > 0:
            print(f"  {r}:")
            print(f"     VIGENTE: {est['VIGENTE']} ({est['VIGENTE']*100//total}%)")
            print(f"     VENCIDO: {est['VENCIDO']} ({est['VENCIDO']*100//total}%)")
            print(f"     N/A:     {est['N/A']} ({est['N/A']*100//total}%)")
    
    # Listar RUTs inválidos
    print("\n--- DETALLE DE RUTS INVÁLIDOS ---")
    for i, row in enumerate(data_rows_filtradas):
        num_linea_real = hdr_idx + 1 + i + 1
        rut_raw = row[4].strip() if len(row) > 4 else ''
        if not validar_rut(rut_raw):
            print(f"  ❌ Fila {num_linea_real}: RUT crudo='{rut_raw}' → {row[1].strip()} {row[2].strip()}")

if __name__ == '__main__':
    main()