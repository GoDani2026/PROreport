// ================================================================
// VALIDADOR DE INCIDENTES HSE
// Validación de formularios de reporte de incidentes
// con workflow PHVA (ABIERTO → EN_INVESTIGACION → CERRADO)
// ================================================================

class IncidenteValidator {
  // Estados del workflow
  static const List<String> estadosWorkflow = [
    'ABIERTO',
    'EN_INVESTIGACION',
    'CERRADO',
  ];

  // Niveles de gravedad
  static const List<String> nivelesGravedad = [
    'Leve',
    'Moderada',
    'Grave',
    'Crítica',
  ];

  // Niveles de prioridad
  static const List<String> nivelesPrioridad = [
    'Baja',
    'Media',
    'Alta',
    'Crítica',
  ];

  /// Valida la descripción del incidente (requerida, mínimo 10 caracteres)
  static String? validarDescripcion(String? descripcion) {
    if (descripcion == null || descripcion.trim().isEmpty) {
      return 'La descripción del incidente es requerida';
    }
    if (descripcion.trim().length < 10) {
      return 'La descripción debe tener al menos 10 caracteres';
    }
    if (descripcion.trim().length > 1000) {
      return 'La descripción no puede exceder 1000 caracteres';
    }
    return null;
  }

  /// Valida que el tipo de incidente esté seleccionado
  static String? validarTipoIncidente(dynamic tipoIncidenteId) {
    if (tipoIncidenteId == null) {
      return 'Debe seleccionar un tipo de incidente';
    }
    return null;
  }

  /// Valida que el área esté seleccionada
  static String? validarArea(dynamic areaId) {
    if (areaId == null) {
      return 'Debe seleccionar un área';
    }
    return null;
  }

  /// Valida que la gravedad sea válida
  static String? validarGravedad(String? gravedad) {
    if (gravedad != null && !nivelesGravedad.contains(gravedad)) {
      return 'Gravedad inválida. Debe ser: ${nivelesGravedad.join(", ")}';
    }
    return null;
  }

  /// Valida la transición de estado del workflow
  static String? validarTransicionEstado(
    String? estadoActual,
    String? nuevoEstado,
  ) {
    if (estadoActual == null || nuevoEstado == null) return null;

    final estadoActualUpper = estadoActual.toUpperCase();
    final nuevoEstadoUpper = nuevoEstado.toUpperCase();

    // Validar que ambos estados sean válidos
    if (!estadosWorkflow.contains(estadoActualUpper)) {
      return 'Estado actual inválido: $estadoActual';
    }
    if (!estadosWorkflow.contains(nuevoEstadoUpper)) {
      return 'Nuevo estado inválido: $nuevoEstado';
    }

    // Reglas de transición
    final transicionesValidas = <String, List<String>>{
      'ABIERTO': ['EN_INVESTIGACION'],
      'EN_INVESTIGACION': ['CERRADO'],
      'CERRADO': [],  // No se puede cambiar de CERRADO
    };

    final permitidos = transicionesValidas[estadoActualUpper] ?? [];
    if (!permitidos.contains(nuevoEstadoUpper)) {
      return 'No se puede cambiar de $estadoActualUpper a $nuevoEstadoUpper. '
          'Transiciones permitidas desde $estadoActualUpper: ${permitidos.isEmpty ? "ninguna" : permitidos.join(", ")}';
    }

    return null;
  }

  /// Valida que el supervisor asignado tenga rol de supervisor/admin
  static String? validarSupervisor(String? supervisorRol) {
    if (supervisorRol == null) return null;
    if (!['supervisor', 'admin'].contains(supervisorRol)) {
      return 'El asignado debe tener rol de supervisor o administrador';
    }
    return null;
  }

  /// Valida que la fecha del incidente no sea futura
  static String? validarFechaIncidente(DateTime? fecha) {
    if (fecha == null) return null;
    final hoy = DateTime.now();
    final fechaSinHora = DateTime(hoy.year, hoy.month, hoy.day);
    if (fecha.isAfter(fechaSinHora.add(const Duration(days: 1)))) {
      return 'La fecha del incidente no puede ser futura';
    }
    return null;
  }

  /// Valida que la cantidad de fotos no exceda el máximo
  static String? validarCantidadFotos(int cantidad, {int maximo = 5}) {
    if (cantidad > maximo) {
      return 'Máximo $maximo fotos permitidas';
    }
    return null;
  }

  /// Validación completa del formulario de incidente
  static String? validarFormularioCompleto({
    required String? descripcion,
    required dynamic tipoIncidenteId,
    required dynamic areaId,
    String? gravedad,
    DateTime? fecha,
    int cantidadFotos = 0,
  }) {
    // Ejecutar todas las validaciones
    final errores = <String>[];

    final errorDesc = validarDescripcion(descripcion);
    if (errorDesc != null) errores.add(errorDesc);

    final errorTipo = validarTipoIncidente(tipoIncidenteId);
    if (errorTipo != null) errores.add(errorTipo);

    final errorArea = validarArea(areaId);
    if (errorArea != null) errores.add(errorArea);

    final errorGravedad = validarGravedad(gravedad);
    if (errorGravedad != null) errores.add(errorGravedad);

    final errorFecha = validarFechaIncidente(fecha);
    if (errorFecha != null) errores.add(errorFecha);

    final errorFotos = validarCantidadFotos(cantidadFotos);
    if (errorFotos != null) errores.add(errorFotos);

    if (errores.isNotEmpty) {
      return errores.join('\n');
    }

    return null;
  }
}