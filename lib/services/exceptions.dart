// ================================================================
// PROreport - Exceptions tipadas para la capa de servicios
// Permite que la UI maneje errores de forma granular sin depender
// de strings o excepciones genéricas de Supabase.
// ================================================================

/// Error base de la capa de servicios.
class ServiceException implements Exception {
  final String message;
  final Object? originalError;

  ServiceException(this.message, {this.originalError});

  @override
  String toString() => message;
}

/// Error cuando un RUT ya existe o hay conflicto de duplicados.
class DuplicateEntryException extends ServiceException {
  DuplicateEntryException([super.message = 'El registro ya existe']);
}

/// Error cuando un trabajador no se encuentra.
class NotFoundException extends ServiceException {
  NotFoundException([super.message = 'Registro no encontrado']);
}

/// Error de validación de datos enviados al servicio.
class ValidationException extends ServiceException {
  final List<String> errors;

  ValidationException(this.errors)
      : super(errors.join('; '));
}

/// Error de conexión o timeout con Supabase.
class NetworkException extends ServiceException {
  NetworkException([super.message = 'Error de conexión con el servidor']);
}

/// Error cuando la función RPC falla del lado del servidor.
class RpcException extends ServiceException {
  final Map<String, dynamic>? rpcResult;

  RpcException(super.message, {this.rpcResult});
}

/// Error cuando no hay permisos suficientes (RLS).
class UnauthorizedException extends ServiceException {
  UnauthorizedException([super.message = 'No tienes permisos para realizar esta acción']);
}

/// Error de base de datos (constraint violation, etc.)
class DatabaseException extends ServiceException {
  final String? constraint;

  DatabaseException(super.message, {this.constraint});
}
