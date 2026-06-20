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
// No altera el esquema de la base de datos.
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
// ──────────────────────────────────────────────────────────────
class Incidente {
  final String? id;
  final DateTime fecha;
  final String descripcion;
  final int? tipoIncidenteId;
  final String? tipoIncidenteNombre;
  final int? areaId;
  final String? areaNombre;
  final String? supervisorId;
  final String? supervisorNombre;
  final List<String> fotosUrls;
  final String? usuarioId;
  final DateTime? createdAt;

  Incidente({
    this.id,
    DateTime? fecha,
    required this.descripcion,
    this.tipoIncidenteId,
    this.tipoIncidenteNombre,
    this.areaId,
    this.areaNombre,
    this.supervisorId,
    this.supervisorNombre,
    this.fotosUrls = const [],
    this.usuarioId,
    this.createdAt,
  }) : fecha = fecha ?? DateTime.now();

  factory Incidente.fromJson(Map<String, dynamic> json) {
    return Incidente(
      id: json['id'] as String?,
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : DateTime.now(),
      descripcion: json['descripcion'] as String? ?? '',
      tipoIncidenteId: json['tipo_incidente_id'] as int?,
      areaId: json['area_id'] as int?,
      supervisorId: json['supervisor_id'] as String?,
      fotosUrls: json['fotos_urls'] != null
          ? List<String>.from(json['fotos_urls'] as List)
          : [],
      usuarioId: json['usuario_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'fecha': fecha.toIso8601String().split('T')[0],
      'descripcion': descripcion,
      if (tipoIncidenteId != null) 'tipo_incidente_id': tipoIncidenteId,
      if (areaId != null) 'area_id': areaId,
      if (supervisorId != null) 'supervisor_id': supervisorId,
      if (fotosUrls.isNotEmpty) 'fotos_urls': fotosUrls,
      if (usuarioId != null) 'usuario_id': usuarioId,
    };
  }
}