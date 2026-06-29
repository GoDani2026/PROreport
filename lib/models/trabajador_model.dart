// ================================================================
// MODELO UNIFICADO: Gestión de Personal (ProReport HSE)
// ----------------------------------------------------------------
// Este archivo agrupa todos los modelos relacionados con el
// registro y gestión de trabajadores y su cumplimiento HSE.
//
// Mapea exactamente a las tablas de Supabase:
//   - trabajadores             (datos fijos del personal)
//   - requisitos_hse           (catálogo dinámico de documentos/exámenes)
//   - cumplimiento_trabajadores (matriz vertical de estados y fechas)
//
// No altera el esquema de la base de datos.
// ================================================================

// ──────────────────────────────────────────────────────────────
// Trabajador (tabla: trabajadores)
// ──────────────────────────────────────────────────────────────
class Trabajador {
  final int? id;
  final String rut;
  final String nombre;
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String cargo;
  final String nacionalidad;
  final String? vencimientoResidencia;
  final String? sexo;
  final String turno;
  final String estadoTrabajador;
  final String contratoCodigo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Trabajador({
    this.id,
    required this.rut,
    required this.nombre,
    required this.apellidoPaterno,
    this.apellidoMaterno,
    required this.cargo,
    this.nacionalidad = 'Chilena',
    this.vencimientoResidencia,
    this.sexo,
    required this.turno,
    this.estadoTrabajador = 'ACTIVO',
    required this.contratoCodigo,
    this.createdAt,
    this.updatedAt,
  });

  String get nombreCompleto =>
      '$nombre $apellidoPaterno${apellidoMaterno != null ? ' $apellidoMaterno' : ''}';

  factory Trabajador.fromJson(Map<String, dynamic> json) {
    return Trabajador(
      id: _toInt(json['id']),
      rut: json['rut'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      apellidoPaterno: json['apellido_paterno'] as String? ?? '',
      apellidoMaterno: json['apellido_materno'] as String?,
      cargo: json['cargo'] as String? ?? '',
      nacionalidad: json['nacionalidad'] as String? ?? 'Chilena',
      vencimientoResidencia: json['fecha_vencimiento_residencia'] as String?,
      sexo: json['sexo'] as String?,
      turno: json['turno'] as String? ?? '',
      estadoTrabajador: json['estado_trabajador'] as String? ?? 'ACTIVO',
      contratoCodigo: json['contrato_codigo'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'rut': rut,
      'nombre': nombre,
      'apellido_paterno': apellidoPaterno,
      'apellido_materno': apellidoMaterno,
      'cargo': cargo,
      'nacionalidad': nacionalidad,
      'fecha_vencimiento_residencia': vencimientoResidencia,
      'sexo': sexo,
      'turno': turno,
      'estado_trabajador': estadoTrabajador,
      // NOTA: contrato_codigo ya no se envía aquí.
      // Se maneja a través de la tabla intermedia trabajador_contratos
      // vía la RPC upsert_trabajador_completo.
    };
  }

  /// Retorna un mapa con solo los campos actualizables (incluye updated_at).
  Map<String, dynamic> toJsonUpdate() {
    return {
      ...toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  String toString() => '$rut - $nombreCompleto';
}

// ──────────────────────────────────────────────────────────────
// RequisitoHSE (catálogo: requisitos_hse)
// ──────────────────────────────────────────────────────────────
class RequisitoHSE {
  final int id;
  final String nombreRequisito;
  final bool requiereVencimiento;

  RequisitoHSE({
    required this.id,
    required this.nombreRequisito,
    this.requiereVencimiento = false,
  });

  factory RequisitoHSE.fromJson(Map<String, dynamic> json) {
    return RequisitoHSE(
      id: json['id'] as int,
      nombreRequisito: json['nombre_requisito'] as String? ?? '',
      requiereVencimiento: json['requiere_vencimiento'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_requisito': nombreRequisito,
      'requiere_vencimiento': requiereVencimiento,
    };
  }

  @override
  String toString() => nombreRequisito;
}

// ──────────────────────────────────────────────────────────────
// CumplimientoTrabajador (tabla: cumplimiento_trabajadores)
// ──────────────────────────────────────────────────────────────
class CumplimientoTrabajador {
  final int? id;
  final int trabajadorId;
  final int requisitoId;
  final String valorEstado;
  final DateTime? fechaVencimiento;
  final String? documentoUrl;
  final DateTime? updatedAt;

  CumplimientoTrabajador({
    this.id,
    required this.trabajadorId,
    required this.requisitoId,
    this.valorEstado = 'N/A',
    this.fechaVencimiento,
    this.documentoUrl,
    this.updatedAt,
  });

  /// Indica si este requisito permite selección de fecha de vencimiento
  /// basado en el estado actual.
  bool get permiteFechaVencimiento => valorEstado != 'N/A';

  /// Crea un CumplimientoTrabajador desde valores parseados de CSV.
  factory CumplimientoTrabajador.fromCsvValues({
    required int trabajadorId,
    required int requisitoId,
    required String valorEstado,
    String? fechaVencimiento,
    String? documentoUrl,
  }) {
    return CumplimientoTrabajador(
      trabajadorId: trabajadorId,
      requisitoId: requisitoId,
      valorEstado: valorEstado,
      fechaVencimiento: fechaVencimiento != null && fechaVencimiento.isNotEmpty
          ? DateTime.tryParse(fechaVencimiento)
          : null,
      documentoUrl: documentoUrl,
    );
  }

  factory CumplimientoTrabajador.fromJson(Map<String, dynamic> json) {
    return CumplimientoTrabajador(
      id: _toInt(json['id']),
      trabajadorId: _toInt(json['trabajador_id']) ?? 0,
      requisitoId: json['requisito_id'] as int? ?? 0,
      valorEstado: json['valor_estado'] as String? ?? 'N/A',
      fechaVencimiento: json['fecha_vencimiento'] != null
          ? DateTime.parse(json['fecha_vencimiento'] as String)
          : null,
      documentoUrl: json['documento_url'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trabajador_id': trabajadorId,
      'requisito_id': requisitoId,
      'valor_estado': valorEstado,
      'fecha_vencimiento':
          fechaVencimiento?.toIso8601String().split('T')[0],
      'documento_url': documentoUrl,
    };
  }

  Map<String, dynamic> toJsonUpdate() {
    return {
      ...toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  String toString() =>
      'Req #$requisitoId: $valorEstado${fechaVencimiento != null ? ' (vence: ${fechaVencimiento!.toIso8601String().split('T')[0]})' : ''}';
}

// ──────────────────────────────────────────────────────────────
// CumplimientoCompleto (vista combinada usada en reportes)
// ----------------------------------------------------------------
// Resultado de la función obtener_cumplimiento_trabajador()
// que hace CROSS JOIN entre trabajadores y requisitos_hse.
// ──────────────────────────────────────────────────────────────
class CumplimientoCompleto {
  final int trabajadorId;
  final String rut;
  final String nombre;
  final String apellidoPaterno;
  final String? apellidoMaterno;
  final String cargo;
  final String estadoTrabajador;
  final int requisitoId;
  final String nombreRequisito;
  final String? valorEstado;
  final DateTime? fechaVencimiento;
  final String? documentoUrl;

  CumplimientoCompleto({
    required this.trabajadorId,
    required this.rut,
    required this.nombre,
    required this.apellidoPaterno,
    this.apellidoMaterno,
    required this.cargo,
    required this.estadoTrabajador,
    required this.requisitoId,
    required this.nombreRequisito,
    this.valorEstado,
    this.fechaVencimiento,
    this.documentoUrl,
  });

  String get nombreCompleto =>
      '$nombre $apellidoPaterno${apellidoMaterno != null ? ' $apellidoMaterno' : ''}';

  factory CumplimientoCompleto.fromJson(Map<String, dynamic> json) {
    return CumplimientoCompleto(
      trabajadorId: _toInt(json['trabajador_id']) ?? 0,
      rut: json['rut'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      apellidoPaterno: json['apellido_paterno'] as String? ?? '',
      apellidoMaterno: json['apellido_materno'] as String?,
      cargo: json['cargo'] as String? ?? '',
      estadoTrabajador: json['estado_trabajador'] as String? ?? 'ACTIVO',
      requisitoId: json['requisito_id'] as int? ?? 0,
      nombreRequisito: json['nombre_requisito'] as String? ?? '',
      valorEstado: json['valor_estado'] as String?,
      fechaVencimiento: json['fecha_vencimiento'] != null
          ? DateTime.parse(json['fecha_vencimiento'] as String)
          : null,
      documentoUrl: json['documento_url'] as String?,
    );
  }

  @override
  String toString() =>
      '$rut - $nombreCompleto | $nombreRequisito: ${valorEstado ?? "Pendiente"}';
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String && value.isNotEmpty) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  return null;
}
