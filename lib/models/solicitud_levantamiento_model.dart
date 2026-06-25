// ================================================================
// MODELO UNIFICADO: Solicitud de Levantamiento (ProReport HSE)
// ----------------------------------------------------------------
// Este archivo agrupa todos los modelos relacionados con el
// formulario de Solicitud de Levantamiento.
//
// Mapea exactamente a las tablas de Supabase:
//   - incidentes       (tabla principal del reporte)
//   - tipos_incidente   (catálogo de tipos)
//   - areas             (catálogo de áreas)
//   - perfiles          (usuarios / supervisores)
//
// v2: Alineado con esquema normalizado (sin JSONB, FK consistentes)
// ================================================================

// ──────────────────────────────────────────────────────────────
// TipoIncidente (catálogo)
// ──────────────────────────────────────────────────────────────
class TipoIncidente {
  final int id;
  final String nombre;

  TipoIncidente({
    required this.id,
    required this.nombre,
  });

  factory TipoIncidente.fromJson(Map<String, dynamic> json) {
    return TipoIncidente(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }

  @override
  String toString() => nombre;
}

// ──────────────────────────────────────────────────────────────
// Area (catálogo)
// ──────────────────────────────────────────────────────────────
class Area {
  final int id;
  final String nombre;

  Area({
    required this.id,
    required this.nombre,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }

  @override
  String toString() => nombre;
}

// ──────────────────────────────────────────────────────────────
// Perfil (usuario / supervisor)
// ──────────────────────────────────────────────────────────────
class Perfil {
  final String id;
  final String nombreCompleto;
  final String rol;
  final String? avatarUrl;

  Perfil({
    required this.id,
    required this.nombreCompleto,
    required this.rol,
    this.avatarUrl,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'] as String,
      nombreCompleto: json['nombre_completo'] as String? ?? '',
      rol: json['rol'] as String? ?? 'colaborador',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_completo': nombreCompleto,
      'rol': rol,
      'avatar_url': avatarUrl,
    };
  }

  @override
  String toString() => nombreCompleto;
}

// ──────────────────────────────────────────────────────────────
// Incidente (tabla principal del reporte)
// v2: Alineado con incidentes(id SERIAL, usuario_reportante_id uuid,
//     supervisor_trabajador_id int, tipo_incidente_id int, area_id int,
//     titulo text, descripcion text, fecha_reporte timestamp,
//     fecha_incidente date, estado text, severidad text, fotos text[])
// ──────────────────────────────────────────────────────────────
class Incidente {
  final int? id;
  final String titulo;
  final String descripcion;
  final int? tipoIncidenteId;
  final int? areaId;
  final int? supervisorTrabajadorId;
  final DateTime? fechaReporte;
  final DateTime fechaIncidente;
  final String? estado;
  final String? severidad;
  final List<String> fotos;
  final String? usuarioReportanteId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Incidente({
    this.id,
    required this.titulo,
    required this.descripcion,
    this.tipoIncidenteId,
    this.areaId,
    this.supervisorTrabajadorId,
    this.fechaReporte,
    DateTime? fechaIncidente,
    this.estado,
    this.severidad,
    this.fotos = const [],
    this.usuarioReportanteId,
    this.createdAt,
    this.updatedAt,
  }) : fechaIncidente = fechaIncidente ?? DateTime.now();

  factory Incidente.fromJson(Map<String, dynamic> json) {
    return Incidente(
      id: json['id'] as int?,
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      tipoIncidenteId: json['tipo_incidente_id'] as int?,
      areaId: json['area_id'] as int?,
      supervisorTrabajadorId: json['supervisor_trabajador_id'] as int?,
      fechaReporte: json['fecha_reporte'] != null
          ? DateTime.parse(json['fecha_reporte'] as String)
          : null,
      fechaIncidente: json['fecha_incidente'] != null
          ? DateTime.parse(json['fecha_incidente'] as String)
          : DateTime.now(),
      estado: json['estado'] as String?,
      severidad: json['severidad'] as String?,
      fotos: json['fotos'] != null
          ? List<String>.from(json['fotos'] as List)
          : const [],
      usuarioReportanteId: json['usuario_reportante_id'] as String?,
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
      'titulo': titulo,
      'descripcion': descripcion,
      if (tipoIncidenteId != null) 'tipo_incidente_id': tipoIncidenteId,
      if (areaId != null) 'area_id': areaId,
      if (supervisorTrabajadorId != null) 'supervisor_trabajador_id': supervisorTrabajadorId,
      if (fechaReporte != null) 'fecha_reporte': fechaReporte!.toIso8601String(),
      'fecha_incidente': fechaIncidente.toIso8601String().split('T')[0],
      if (estado != null) 'estado': estado,
      if (severidad != null) 'severidad': severidad,
      if (fotos.isNotEmpty) 'fotos': fotos,
      if (usuarioReportanteId != null) 'usuario_reportante_id': usuarioReportanteId,
    };
  }
}

// ──────────────────────────────────────────────────────────────
// AccionCorrectiva (tabla relacional independiente)
// v2: Sin duplicado JSONB en incidentes
// ──────────────────────────────────────────────────────────────
class AccionCorrectiva {
  final int? id;
  final int incidenteId;
  final int? trabajadorAsignadoId;
  final String? usuarioAsignadoId;
  final String descripcion;
  final DateTime fechaAsignacion;
  final DateTime fechaLimite;
  final DateTime? fechaCierre;
  final String estado;
  final String prioridad;
  final String? evidenciaUrl;
  final String? notasCierre;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AccionCorrectiva({
    this.id,
    required this.incidenteId,
    this.trabajadorAsignadoId,
    this.usuarioAsignadoId,
    required this.descripcion,
    required this.fechaAsignacion,
    required this.fechaLimite,
    this.fechaCierre,
    this.estado = 'pendiente',
    this.prioridad = 'media',
    this.evidenciaUrl,
    this.notasCierre,
    this.createdAt,
    this.updatedAt,
  });

  factory AccionCorrectiva.fromJson(Map<String, dynamic> json) {
    return AccionCorrectiva(
      id: json['id'] as int?,
      incidenteId: json['incidente_id'] as int? ?? 0,
      trabajadorAsignadoId: json['trabajador_asignado_id'] as int?,
      usuarioAsignadoId: json['usuario_asignado_id'] as String?,
      descripcion: json['descripcion'] as String? ?? '',
      fechaAsignacion: json['fecha_asignacion'] != null
          ? DateTime.parse(json['fecha_asignacion'] as String)
          : DateTime.now(),
      fechaLimite: json['fecha_limite'] != null
          ? DateTime.parse(json['fecha_limite'] as String)
          : DateTime.now().add(const Duration(days: 15)),
      fechaCierre: json['fecha_cierre'] != null
          ? DateTime.parse(json['fecha_cierre'] as String)
          : null,
      estado: json['estado'] as String? ?? 'pendiente',
      prioridad: json['prioridad'] as String? ?? 'media',
      evidenciaUrl: json['evidencia_url'] as String?,
      notasCierre: json['notas_cierre'] as String?,
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
      'incidente_id': incidenteId,
      if (trabajadorAsignadoId != null) 'trabajador_asignado_id': trabajadorAsignadoId,
      if (usuarioAsignadoId != null) 'usuario_asignado_id': usuarioAsignadoId,
      'descripcion': descripcion,
      'fecha_asignacion': fechaAsignacion.toIso8601String(),
      'fecha_limite': fechaLimite.toIso8601String().split('T')[0],
      if (fechaCierre != null) 'fecha_cierre': fechaCierre!.toIso8601String(),
      'estado': estado,
      'prioridad': prioridad,
      if (evidenciaUrl != null) 'evidencia_url': evidenciaUrl,
      if (notasCierre != null) 'notas_cierre': notasCierre,
    };
  }
}