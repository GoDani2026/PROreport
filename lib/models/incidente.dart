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
