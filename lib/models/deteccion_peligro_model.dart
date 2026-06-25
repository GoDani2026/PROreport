// ================================================================
// PROreport - Modelo: DeteccionPeligro
// ----------------------------------------------------------------
// Representa un registro de la tabla `detecciones_peligro`.
// Inmutable con copyWith para actualizaciones parciales.
// ================================================================

class DeteccionPeligro {
  final int? id;
  final String usuarioReportanteId;
  final int areaId;
  final String turno;
  final String lugarExacto;

  // Hallazgo (Antes)
  final String? fotoEvidenciaUrl;
  final String? descripcionHallazgo;
  final String nivelAtencionLgf; // BAJO | MEDIO | SIGNIFICATIVO
  final String? accionInmediata;

  // Seguimiento y Compromiso
  final String estatusSeguimiento; // Pendiente | En Ejecución | Eliminada
  final int? supervisorResponsableId;
  final String? planAccion;
  final DateTime? fechaCompromisoEliminacion;

  // Cierre (Después)
  final String? resumenCierre;
  final String? fotoCierreUrl;

  // Notario Digital
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? fechaCierre;

  // Sistema
  final String? urlPdfEvolutivo;

  const DeteccionPeligro({
    this.id,
    required this.usuarioReportanteId,
    required this.areaId,
    required this.turno,
    required this.lugarExacto,
    this.fotoEvidenciaUrl,
    this.descripcionHallazgo,
    required this.nivelAtencionLgf,
    this.accionInmediata,
    this.estatusSeguimiento = 'Pendiente',
    this.supervisorResponsableId,
    this.planAccion,
    this.fechaCompromisoEliminacion,
    this.resumenCierre,
    this.fotoCierreUrl,
    this.createdAt,
    this.updatedAt,
    this.fechaCierre,
    this.urlPdfEvolutivo,
  });

  /// Crea una instancia desde un Map de Supabase/JSON.
  factory DeteccionPeligro.fromJson(Map<String, dynamic> json) {
    return DeteccionPeligro(
      id: json['id'] as int?,
      usuarioReportanteId: json['usuario_reportante_id'] as String,
      areaId: json['area_id'] as int,
      turno: json['turno'] as String,
      lugarExacto: json['lugar_exacto'] as String,
      fotoEvidenciaUrl: json['foto_evidencia_url'] as String?,
      descripcionHallazgo: json['descripcion_hallazgo'] as String?,
      nivelAtencionLgf: json['nivel_atencion_lgf'] as String,
      accionInmediata: json['accion_inmediata'] as String?,
      estatusSeguimiento:
          json['estatus_seguimiento'] as String? ?? 'Pendiente',
      supervisorResponsableId: json['supervisor_responsable_id'] as int?,
      planAccion: json['plan_accion'] as String?,
      fechaCompromisoEliminacion:
          json['fecha_compromiso_eliminacion'] != null
              ? DateTime.parse(json['fecha_compromiso_eliminacion'] as String)
              : null,
      resumenCierre: json['resumen_cierre'] as String?,
      fotoCierreUrl: json['foto_cierre_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      fechaCierre: json['fecha_cierre'] != null
          ? DateTime.parse(json['fecha_cierre'] as String)
          : null,
      urlPdfEvolutivo: json['url_pdf_evolutivo'] as String?,
    );
  }

  /// Convierte a Map para enviar a Supabase.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'usuario_reportante_id': usuarioReportanteId,
      'area_id': areaId,
      'turno': turno,
      'lugar_exacto': lugarExacto,
      if (fotoEvidenciaUrl != null) 'foto_evidencia_url': fotoEvidenciaUrl,
      if (descripcionHallazgo != null)
        'descripcion_hallazgo': descripcionHallazgo,
      'nivel_atencion_lgf': nivelAtencionLgf,
      if (accionInmediata != null) 'accion_inmediata': accionInmediata,
      'estatus_seguimiento': estatusSeguimiento,
      if (supervisorResponsableId != null)
        'supervisor_responsable_id': supervisorResponsableId,
      if (planAccion != null) 'plan_accion': planAccion,
      if (fechaCompromisoEliminacion != null)
        'fecha_compromiso_eliminacion':
            fechaCompromisoEliminacion!.toIso8601String().split('T').first,
      if (resumenCierre != null) 'resumen_cierre': resumenCierre,
      if (fotoCierreUrl != null) 'foto_cierre_url': fotoCierreUrl,
      if (urlPdfEvolutivo != null) 'url_pdf_evolutivo': urlPdfEvolutivo,
    };
  }

  /// Crea una copia con campos opcionales actualizados.
  DeteccionPeligro copyWith({
    int? id,
    String? usuarioReportanteId,
    int? areaId,
    String? turno,
    String? lugarExacto,
    String? fotoEvidenciaUrl,
    String? descripcionHallazgo,
    String? nivelAtencionLgf,
    String? accionInmediata,
    String? estatusSeguimiento,
    int? supervisorResponsableId,
    String? planAccion,
    DateTime? fechaCompromisoEliminacion,
    String? resumenCierre,
    String? fotoCierreUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? fechaCierre,
    String? urlPdfEvolutivo,
  }) {
    return DeteccionPeligro(
      id: id ?? this.id,
      usuarioReportanteId: usuarioReportanteId ?? this.usuarioReportanteId,
      areaId: areaId ?? this.areaId,
      turno: turno ?? this.turno,
      lugarExacto: lugarExacto ?? this.lugarExacto,
      fotoEvidenciaUrl: fotoEvidenciaUrl ?? this.fotoEvidenciaUrl,
      descripcionHallazgo: descripcionHallazgo ?? this.descripcionHallazgo,
      nivelAtencionLgf: nivelAtencionLgf ?? this.nivelAtencionLgf,
      accionInmediata: accionInmediata ?? this.accionInmediata,
      estatusSeguimiento: estatusSeguimiento ?? this.estatusSeguimiento,
      supervisorResponsableId:
          supervisorResponsableId ?? this.supervisorResponsableId,
      planAccion: planAccion ?? this.planAccion,
      fechaCompromisoEliminacion:
          fechaCompromisoEliminacion ?? this.fechaCompromisoEliminacion,
      resumenCierre: resumenCierre ?? this.resumenCierre,
      fotoCierreUrl: fotoCierreUrl ?? this.fotoCierreUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      urlPdfEvolutivo: urlPdfEvolutivo ?? this.urlPdfEvolutivo,
    );
  }

  /// Retorna una representación legible del nivel de atención.
  String get nivelAtencionLabel {
    switch (nivelAtencionLgf) {
      case 'BAJO':
        return 'Bajo';
      case 'MEDIO':
        return 'Medio';
      case 'SIGNIFICATIVO':
        return 'Significativo';
      default:
        return nivelAtencionLgf;
    }
  }

  /// Indica si el registro está pendiente de ejecución.
  bool get isPendiente => estatusSeguimiento == 'Pendiente';

  /// Indica si el registro está en ejecución.
  bool get isEnEjecucion => estatusSeguimiento == 'En Ejecución';

  /// Indica si el registro está eliminado (cerrado).
  bool get isEliminada => estatusSeguimiento == 'Eliminada';
}