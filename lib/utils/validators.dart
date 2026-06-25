// ================================================================
// Utilidades de validación reutilizables
// Incluye validador de RUT chileno con dígito verificador real.
// ================================================================

class Validators {
  static const _sexosValidos = ['M', 'F', 'Otro'];
  static const _estadosValidos = ['ACTIVO', 'DESVINCULADO', 'LICENCIA'];
  static const _estadosRequisitoValidos = ['VIGENTE', 'VENCIDO', 'N/A'];

  // ── RUT ────────────────────────────────────────────────────────

  /// Valida formato y dígito verificador de RUT chileno.
  /// Retorna el RUT limpio (sin puntos, guión normalizado) o null.
  /// Soporta formatos: 12.345.678-9, 12,345,678-9, 12.345.678.9 (punto como separador).
  static String? validarRut(String? input) {
    if (input == null) return null;
    // Reemplazar comas por puntos (ej: "201,261,406" -> "201.261.406")
    String s = input.replaceAll(',', '.').trim();
    // Si tiene puntos pero NO guión, podría ser que el DV esté después del último punto
    if (s.contains('.') && !s.contains('-')) {
      // 28.029.173.0 → parte con puntos, el último segmento es el DV
      final partes = s.split('.');
      if (partes.length >= 2) {
        final dv = partes.removeLast();
        s = '${partes.join('.')}-$dv';
      }
    }
    final limpio = s.replaceAll('.', '').replaceAll(' ', '').toUpperCase().trim();
    if (limpio.isEmpty) return null;

    final match = RegExp(r'^(\d{7,8})-([\dK])$').firstMatch(limpio);
    if (match == null) return null;

    final cuerpo = match.group(1)!;
    final dvIngresado = match.group(2)!;

    int suma = 0;
    int multiplicador = 2;
    for (int i = cuerpo.length - 1; i >= 0; i--) {
      suma += int.parse(cuerpo[i]) * multiplicador;
      multiplicador = multiplicador == 7 ? 2 : multiplicador + 1;
    }
    final resto = suma % 11;
    final dvCalculado = resto == 0 ? '0' : resto == 1 ? 'K' : (11 - resto).toString();

    if (dvIngresado != dvCalculado) return null;
    return limpio;
  }

  // ── Campos genéricos ───────────────────────────────────────────

  static bool esRutValido(String? v) => validarRut(v) != null;

  static bool esNoVacio(String? v) => v != null && v.trim().isNotEmpty;

  static bool esSexoValido(String? v) => v != null && _sexosValidos.contains(v);

  static bool esEstadoValido(String? v) => v != null && _estadosValidos.contains(v);

  static bool esEstadoRequisitoValido(String? v) => v != null && _estadosRequisitoValidos.contains(v);

  // ── Normalización de valores CSV ───────────────────────────────

  /// Normaliza sexo del CSV (Hombre/Mujer) a valores BD (M/F).
  static String normalizarSexo(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'hombre' || v == 'm' || v == 'masculino') return 'M';
    if (v == 'mujer' || v == 'f' || v == 'femenino') return 'F';
    return 'M'; // default
  }

  /// Parsea una fecha a yyyy-MM-dd.
  /// Soporta formatos: MM/dd/yyyy, dd/MM/yyyy, dd-MM-yyyy, yyyy-MM-dd.
  /// Retorna string vacío si no puede parsear.
  static String parsearFechaCsv(String raw) {
    final v = raw.trim();
    if (v.isEmpty || v == 'N/A' || v == 'n/a') return '';
    try {
      // Si ya viene en formato ISO (yyyy-MM-dd), retornar tal cual
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) return v;

      List<String> partes;
      // Intentar con '/' (MM/dd/yyyy o dd/MM/yyyy)
      if (v.contains('/')) {
        partes = v.split('/');
      } else if (v.contains('-')) {
        // Intentar con '-' (dd-MM-yyyy)
        partes = v.split('-');
      } else {
        return '';
      }

      if (partes.length == 3) {
        final p1 = int.parse(partes[0]);
        final p2 = int.parse(partes[1]);
        final anio = int.parse(partes[2]);
        if (anio > 1900 && anio < 2100) {
          // Si p1 > 12, es dd/MM/yyyy; si p1 <= 12, tratar como MM/dd/yyyy
          if (p1 > 12) {
            // Formato dd/MM/yyyy o dd-MM-yyyy
            return '$anio-${p2.toString().padLeft(2, '0')}-${p1.toString().padLeft(2, '0')}';
          } else {
            // Asumir MM/dd/yyyy (formato usado en el Excel)
            return '$anio-${p1.toString().padLeft(2, '0')}-${p2.toString().padLeft(2, '0')}';
          }
        }
      }
    } catch (_) {}
    return ''; // No se pudo parsear → string vacío
  }

  /// Determina si una fecha representa VIGENTE o VENCIDO comparando con hoy.
  static String estadoDesdeFecha(String fechaStr) {
    if (fechaStr.isEmpty) return 'N/A';
    try {
      final fecha = DateTime.parse(fechaStr);
      return fecha.isAfter(DateTime.now()) ? 'VIGENTE' : 'VENCIDO';
    } catch (_) {
      return 'N/A';
    }
  }

  /// Mapea un valor de celda de requisito SI/N/A a estado HSE.
  static String mapearEstadoSiNa(String raw) {
    final v = raw.trim().toUpperCase();
    if (v == 'SI' || v == 'SÍ' || v == 'SI ') return 'VIGENTE';
    return 'N/A';
  }

  // ── Parseo de fila completa de carga masiva ───────────────────

  /// Parsea una fila de CSV/XLSX extrayendo datos personales + 12 requisitos HSE.
  /// 'columnas' debe ser un Map con claves String y valores int 
  /// donde la clave es el nombre interno del campo y el valor es el indice 
  /// de la columna (empezando en 0) en el array.
  ///
  /// Params: fila (datos de la fila), colIndex (mapa de indices)
  ///
  static FilaCargaCompleta parsearFilaCargaMasiva(
    List<String> fila,
    Map<String, int> colIndex,
  ) {
    String get(String key) => (colIndex.containsKey(key) && colIndex[key]! < fila.length)
        ? fila[colIndex[key]!].trim()
        : '';

    // Datos personales
    final rutRaw = get('rut');
    final rut = validarRut(rutRaw) ?? rutRaw;
    final nombre = get('nombre');
    final apellidoPaterno = get('apellido_paterno');
    final apellidoMaterno = get('apellido_materno');
    final cargo = get('cargo');
    final nacionalidad = get('nacionalidad');
    final vencResRaw = get('vencimiento_residencia');
    final sexoRaw = get('sexo');
    final turno = get('turno');
    final estadoRaw = get('estado_trabajador');

    final sexo = normalizarSexo(sexoRaw);
    final estado = _estadosValidos.contains(estadoRaw.toUpperCase()) ? estadoRaw.toUpperCase() : 'ACTIVO';

    // Definir 12 requisitos HSE: índices de columna
    const reqColumns = [
      'req_examenes_ocupacionales',
      'req_examen_alcohol_drogas',
      'req_examen_psicosensometrico',
      'req_vencimiento_induccion_sqm',
      'req_protocolo_sqm',
      'req_ctta',
      'req_certificacion',
      'req_licencia_interna_sqm',
      'req_difusion_procedimientos',
      'req_difusion_plan_subplanes_sqm',
      'req_difusion_plan_subplanes_cttas',
      'req_difusion_hds',
    ];

    final cumplimientos = <Map<String, dynamic>>[];
    for (var i = 0; i < 12; i++) {
      final raw = get(reqColumns[i]);
      final requisitoId = i + 1; // IDs 1-12 en BD
      final requiereVenc = i < 4; // requisitos 1-4 tienen fecha

      String estadoReq;
      String? fechaVen;

      if (requiereVenc) {
        // Columnas con fecha de vencimiento
        final fechaParsed = parsearFechaCsv(raw);
        if (fechaParsed.isNotEmpty) {
          estadoReq = estadoDesdeFecha(fechaParsed);
          fechaVen = fechaParsed;
        } else {
          estadoReq = 'N/A';
          fechaVen = null;
        }
      } else {
        // Columnas SI/N/A
        estadoReq = mapearEstadoSiNa(raw);
        fechaVen = null;
      }

      cumplimientos.add({
        'requisito_id': requisitoId,
        'valor_estado': estadoReq,
        'fecha_vencimiento': fechaVen,
        'documento_url': null,
      });
    }

    // Errores de validación
    final errores = <String>[];
    if (validarRut(rutRaw) == null) errores.add('RUT inválido o DV incorrecto');
    if (!esNoVacio(nombre)) errores.add('Nombre obligatorio');
    if (!esNoVacio(apellidoPaterno)) errores.add('Apellido Paterno obligatorio');
    if (!esNoVacio(cargo)) errores.add('Cargo obligatorio');
    if (!esNoVacio(turno)) errores.add('Turno obligatorio');

    return FilaCargaCompleta(
      datosTrabajador: {
        'rut': rut,
        'nombre': nombre,
        'apellido_paterno': apellidoPaterno,
        'apellido_materno': apellidoMaterno,
        'cargo': cargo,
        'nacionalidad': nacionalidad.isNotEmpty ? nacionalidad : 'Chilena',
        'fecha_vencimiento_residencia': vencResRaw,
        'sexo': sexo,
        'turno': turno,
        'estado_trabajador': estado,
        'contrato_codigo': 'SC-9500014891', // default
      },
      cumplimiento: cumplimientos,
      errores: errores,
    );
  }

  // ── Resultado de validación de fila CSV/XLSX (legacy) ──────────

  static FilaValidacion validarFilaCargaMasiva(Map<String, dynamic> fila) {
    final errores = <String>[];

    final rut = (fila['rut'] ?? '').toString().trim();
    final nombre = (fila['nombre'] ?? '').toString().trim();
    final apellidoPaterno = (fila['apellido_paterno'] ?? '').toString().trim();
    final cargo = (fila['cargo'] ?? '').toString().trim();
    final sexo = (fila['sexo'] ?? '').toString().trim();
    final turno = (fila['turno'] ?? '').toString().trim();
    final contratoCodigo = (fila['contrato_codigo'] ?? '').toString().trim();
    final estado = (fila['estado_trabajador'] ?? '').toString().trim();

    if (!esRutValido(rut)) errores.add('RUT inválido o DV incorrecto');
    if (!esNoVacio(nombre)) errores.add('Nombre obligatorio');
    if (!esNoVacio(apellidoPaterno)) errores.add('Apellido Paterno obligatorio');
    if (!esNoVacio(cargo)) errores.add('Cargo obligatorio');
    if (!esSexoValido(sexo)) errores.add('Sexo inválido (M/F/Otro)');
    if (!esNoVacio(turno)) errores.add('Turno obligatorio');
    if (!esNoVacio(contratoCodigo)) errores.add('Código de Contrato obligatorio');
    if (!esEstadoValido(estado)) errores.add('Estado inválido (ACTIVO/DESVINCULADO/LICENCIA)');

    final limpios = <String, dynamic>{
      'rut': rut,
      'nombre': nombre,
      'apellido_paterno': apellidoPaterno,
      'apellido_materno': (fila['apellido_materno'] ?? '').toString().trim(),
      'cargo': cargo,
      'nacionalidad': (fila['nacionalidad'] ?? 'Chilena').toString().trim(),
      'fecha_vencimiento_residencia': (fila['fecha_vencimiento_residencia'] ?? '').toString().trim(),
      'sexo': sexo,
      'turno': turno,
      'contrato_codigo': contratoCodigo,
      'estado_trabajador': estado,
    };

    return FilaValidacion(datos: limpios, errores: errores);
  }
}

// ── Clase de resultado de validación (legacy) ────────────────────

class FilaValidacion {
  final Map<String, dynamic> datos;
  final List<String> errores;
  const FilaValidacion({required this.datos, required this.errores});

  bool get esValida => errores.isEmpty;
}

// ── Clase de resultado de parseo completo ────────────────────────

class FilaCargaCompleta {
  final Map<String, dynamic> datosTrabajador;
  final List<Map<String, dynamic>> cumplimiento; // 12 items
  final List<String> errores;

  const FilaCargaCompleta({
    required this.datosTrabajador,
    required this.cumplimiento,
    required this.errores,
  });

  bool get esValida => errores.isEmpty;
}