// ================================================================
// VALIDADOR DE CUMPLIMIENTO HSE
// Validación cruzada de estados y fechas del ciclo PHVA
//
// Refleja exactamente las reglas del trigger PostgreSQL:
//   public.validar_fechas_cumplimiento()
// ================================================================

class CumplimientoValidator {
  // Estados válidos en el sistema
  static const List<String> estadosValidos = [
    'VIGENTE',
    'VENCIDO',
    'N/A',
  ];

  /// Valida que el estado sea uno de los valores permitidos
  static String? validarEstado(String? estado) {
    if (estado == null || estado.trim().isEmpty) {
      return 'El estado es requerido';
    }
    final normalizado = _normalizarEstado(estado.toUpperCase());
    if (!estadosValidos.contains(normalizado)) {
      return 'Estado inválido: $estado. Debe ser: ${estadosValidos.join(", ")}';
    }
    return null;
  }

  static String _normalizarEstado(String estado) {
    switch (estado) {
      case 'SI':
      case 'APROBADO':
        return 'VIGENTE';
      case 'NO':
      case 'PENDIENTE':
      case 'RECHAZADO':
        return 'N/A';
      default:
        return estado;
    }
  }

  /// Valida la relación cruzada entre estado y fecha de vencimiento.
  /// Reglas (espejo del trigger PostgreSQL):
  ///   1. VIGENTE → fecha requerida, futura, máx 365 días
  ///   2. N/A → fecha debe ser NULL
  ///   3. VENCIDO → fecha debe ser pasada
  ///   4. SI/NO → fecha debe ser NULL (booleanos)
  static String? validarEstadoYFecha(String? estado, DateTime? fechaVencimiento) {
    final errorEstado = validarEstado(estado);
    if (errorEstado != null) return errorEstado;

    final estadoUpper = estado!.toUpperCase();

    switch (estadoUpper) {
      case 'VIGENTE':
        if (fechaVencimiento == null) {
          return 'Estado VIGENTE requiere una fecha de vencimiento';
        }
        final hoy = DateTime.now();
        final fechaSinHora = DateTime(hoy.year, hoy.month, hoy.day);
        if (fechaVencimiento.isBefore(fechaSinHora)) {
          return 'Fecha de vencimiento no puede ser anterior a hoy para estado VIGENTE';
        }
        final limite = fechaSinHora.add(const Duration(days: 365));
        if (fechaVencimiento.isAfter(limite)) {
          return 'Fecha de vencimiento no puede exceder 365 días desde hoy';
        }
        break;

      case 'N/A':
        if (fechaVencimiento != null) {
          return 'Estado N/A no debe tener fecha de vencimiento. Se limpiará automáticamente.';
        }
        break;

      case 'VENCIDO':
        if (fechaVencimiento != null) {
          final hoy = DateTime.now();
          final fechaSinHora = DateTime(hoy.year, hoy.month, hoy.day);
          if (!fechaVencimiento.isBefore(fechaSinHora)) {
            return 'No se puede marcar como VENCIDO: la fecha de vencimiento es futura';
          }
        }
        break;

      case 'SI':
      case 'NO':
        if (fechaVencimiento != null) {
          return 'Estado $estadoUpper no requiere fecha de vencimiento. Se limpiará automáticamente.';
        }
        break;
    }

    return null;
  }

  /// Valida que la fecha no sea demasiado lejana (por ejemplo, > 5 años)
  static String? validarFechaFutura(DateTime? fecha) {
    if (fecha == null) return null;
    final limite = DateTime.now().add(const Duration(days: 365 * 5));
    if (fecha.isAfter(limite)) {
      return 'La fecha no puede estar más allá de 5 años en el futuro';
    }
    return null;
  }

  /// Valida que el trabajador exista (no esté desvinculado)
  static String? validarTrabajadorActivo(String? estadoTrabajador) {
    if (estadoTrabajador == null) return null;
    if (estadoTrabajador == 'DESVINCULADO') {
      return 'No se puede modificar cumplimiento de un trabajador desvinculado';
    }
    return null;
  }

  /// Sanitiza los datos antes de enviar: limpia fechas inconsistentes
  static Map<String, dynamic> sanitizarDatos({
    required String estado,
    DateTime? fechaVencimiento,
  }) {
    final estadoUpper = _normalizarEstado(estado.toUpperCase());
    DateTime? fechaSanitizada = fechaVencimiento;

    // Limpiar fecha según estado
    if (estadoUpper == 'N/A') {
      fechaSanitizada = null;
    }

    return {
      'valor_estado': estadoUpper,
      'fecha_vencimiento': fechaSanitizada,
    };
  }
}