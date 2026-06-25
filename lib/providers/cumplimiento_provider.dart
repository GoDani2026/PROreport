// ================================================================
// PROVIDER DE CUMPLIMIENTO HSE
// Transacciones ACID con validación cruzada estado/fecha
// v2: Estados normalizados VIGENTE/VENCIDO/N/A
// ================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../validators/cumplimiento_validator.dart';

class CumplimientoProvider extends ChangeNotifier {
  final SupabaseClient _client;

  CumplimientoProvider(this._client);

  // --- Estado ---
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _trabajadores = [];
  List<Map<String, dynamic>> _requisitos = [];
  Map<int, Map<int, Map<String, dynamic>>> _cumplimientoIndex = {};
  final bool _sincronizado = false;

  // --- Getters ---
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get trabajadores => _trabajadores;
  List<Map<String, dynamic>> get requisitos => _requisitos;
  bool get sincronizado => _sincronizado;

  // ==========================================================
  // MÉTODOS DE CARGA
  // ==========================================================

  /// Carga trabajadores, requisitos y cumplimiento en paralelo
  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _client
            .from('trabajadores')
            .select(
                'id, rut, nombre, apellido_paterno, apellido_materno, cargo, turno, estado_trabajador')
            .order('apellido_paterno'),
        _client
            .from('requisitos_hse')
            .select('id, nombre_requisito, requiere_vencimiento')
            .order('id'),
        _client
            .from('cumplimiento_trabajadores')
            .select(
                'id, trabajador_id, requisito_id, valor_estado, fecha_vencimiento, documento_url'),
      ]);

      _trabajadores = List<Map<String, dynamic>>.from(results[0] as List);
      _requisitos = List<Map<String, dynamic>>.from(results[1] as List);
      final cumplimientoRows =
          List<Map<String, dynamic>>.from(results[2] as List);

      // Indexar cumplimiento: {trabajador_id: {requisito_id: row}}
      _cumplimientoIndex = {};
      for (final row in cumplimientoRows) {
        final tid = row['trabajador_id'] as int?;
        final rid = row['requisito_id'] as int?;
        if (tid != null && rid != null) {
          _cumplimientoIndex.putIfAbsent(tid, () => {})[rid] = row;
        }
      }
    } catch (e) {
      _errorMessage = 'Error al cargar datos: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtener datos del usuario actual (auth → trabajador)
  Future<Map<String, dynamic>?> obtenerUsuarioActual() async {
    try {
      final response = await _client.rpc('obtener_usuario_actual_completo');
      if (response != null && response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response[0]);
      }
      return null;
    } catch (e) {
      debugPrint('Error al obtener usuario actual: $e');
      return null;
    }
  }

  /// Obtener cumplimiento de un trabajador específico
  List<Map<String, dynamic>> obtenerCumplimientoTrabajador(int trabajadorId) {
    // Solo cargar si el índice está vacío
    if (_cumplimientoIndex.isEmpty && _trabajadores.isNotEmpty) {
      _reindexarCumplimiento();
    }
    final cumTrabajador = _cumplimientoIndex[trabajadorId] ?? {};
    return _requisitos.map((req) {
      final reqId = req['id'] as int;
      final cumpl = cumTrabajador[reqId];
      return {
        'requisito_id': reqId,
        'nombre_requisito': req['nombre_requisito'] as String,
        'requiere_vencimiento': req['requiere_vencimiento'] as bool,
        'valor_estado': cumpl?['valor_estado'] ?? 'N/A',
        'fecha_vencimiento': cumpl?['fecha_vencimiento'],
        'documento_url': cumpl?['documento_url'],
        'cumplimiento_id': cumpl?['id'],
      };
    }).toList();
  }

  /// Obtener estado de acreditación de un trabajador
  Map<String, dynamic> obtenerEstadoAcreditacion(int trabajadorId) {
    final cumplimiento = obtenerCumplimientoTrabajador(trabajadorId);
    final tieneVencido = cumplimiento.any((c) => c['valor_estado'] == 'VENCIDO');
    final todosVigentes = cumplimiento
        .every((c) => ['VIGENTE', 'N/A'].contains(c['valor_estado']));

    return {
      'habilitado': todosVigentes,
      'observado': tieneVencido,
      'total_requisitos': cumplimiento.length,
      'cumplidos': cumplimiento
          .where((c) => c['valor_estado'] == 'VIGENTE')
          .length,
      'vencidos': cumplimiento.where((c) => c['valor_estado'] == 'VENCIDO').length,
    };
  }

  // ==========================================================
  // MÉTODOS DE TRANSACCIÓN ACID
  // ==========================================================

  /// Reindexar el cumplimiento desde los datos cargados
  void _reindexarCumplimiento() {
    // El índice ya se construye en loadAll, esto es un respaldo
  }

  /// Actualizar cumplimiento con validación local y remota.
  /// Usa RPC transaccional en Supabase para garantizar ACID.
  Future<bool> actualizarCumplimiento({
    required int trabajadorId,
    required int requisitoId,
    required String nuevoEstado,
    DateTime? nuevaFechaVencimiento,
    String? documentoUrl,
  }) async {
    // 1. Validación local (cliente-side)
    final errorEstado =
        CumplimientoValidator.validarEstado(nuevoEstado);
    if (errorEstado != null) {
      _errorMessage = errorEstado;
      notifyListeners();
      return false;
    }

    final errorEstadoFecha =
        CumplimientoValidator.validarEstadoYFecha(
            nuevoEstado, nuevaFechaVencimiento);
    if (errorEstadoFecha != null) {
      _errorMessage = errorEstadoFecha;
      notifyListeners();
      return false;
    }

    // 2. Sanitizar datos (limpiar fechas inconsistentes)
    final sanitizado = CumplimientoValidator.sanitizarDatos(
      estado: nuevoEstado,
      fechaVencimiento: nuevaFechaVencimiento,
    );

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 3. Ejecutar mediante RPC transaccional (ACID)
      await _client.rpc('actualizar_cumplimiento_seguro', params: {
        'p_trabajador_id': trabajadorId,
        'p_requisito_id': requisitoId,
        'p_valor_estado': sanitizado['valor_estado'],
        'p_fecha_vencimiento':
            sanitizado['fecha_vencimiento']?.toString(),
        'p_documento_url': documentoUrl,
      });

      // 4. Actualizar caché local
      final cumplActual =
          _cumplimientoIndex[trabajadorId]?[requisitoId];
      if (cumplActual != null) {
        cumplActual['valor_estado'] = sanitizado['valor_estado'];
        cumplActual['fecha_vencimiento'] =
            sanitizado['fecha_vencimiento'];
        if (documentoUrl != null) {
          cumplActual['documento_url'] = documentoUrl;
        }
      } else {
        _cumplimientoIndex.putIfAbsent(trabajadorId, () => {})[requisitoId] = {
          'trabajador_id': trabajadorId,
          'requisito_id': requisitoId,
          'valor_estado': sanitizado['valor_estado'],
          'fecha_vencimiento': sanitizado['fecha_vencimiento'],
          'documento_url': documentoUrl,
        };
      }

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar cumplimiento: ${e.toString()}';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualización masiva (batch) de cumplimiento para un trabajador.
  /// Usa una sola transacción RPC en Supabase.
  Future<bool> actualizarCumplimientoMasivo({
    required int trabajadorId,
    required List<Map<String, dynamic>> cambios,
  }) async {
    // Validar todos los cambios primero
    for (final cambio in cambios) {
      final error = CumplimientoValidator.validarEstadoYFecha(
        cambio['valor_estado'] as String?,
        cambio['fecha_vencimiento'] as DateTime?,
      );
      if (error != null) {
        _errorMessage = 'Error en requisito ${cambio['requisito_id']}: $error';
        notifyListeners();
        return false;
      }
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Sanitizar cada cambio
      final cambiosSanitizados = cambios.map((c) {
        final sanitizado = CumplimientoValidator.sanitizarDatos(
          estado: c['valor_estado'] as String,
          fechaVencimiento: c['fecha_vencimiento'] as DateTime?,
        );
        return {
          'requisito_id': c['requisito_id'],
          ...sanitizado,
        };
      }).toList();

      await _client.rpc('actualizar_cumplimiento_masivo', params: {
        'p_trabajador_id': trabajadorId,
        'p_cambios': cambiosSanitizados,
      });

      // Actualizar caché local
      for (final cambio in cambiosSanitizados) {
        final rid = cambio['requisito_id'] as int;
        _cumplimientoIndex
            .putIfAbsent(trabajadorId, () => {})[rid] = {
          'trabajador_id': trabajadorId,
          'requisito_id': rid,
          'valor_estado': cambio['valor_estado'],
          'fecha_vencimiento': cambio['fecha_vencimiento'],
        };
      }

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error en actualización masiva: ${e.toString()}';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  // ==========================================================
  // KPIs Y MÉTRICAS
  // ==========================================================

  /// Obtener KPIs del dashboard HSE
  Future<Map<String, dynamic>> obtenerKPIs() async {
    try {
      final response = await _client.rpc('obtener_kpis_dashboard');
      if (response != null && response is List) {
        final kpis = <String, dynamic>{};
        for (final kpi in response) {
          kpis[kpi['kpi_nombre'] as String] = {
            'valor': kpi['kpi_valor'],
            'tendencia': kpi['kpi_tendencia'],
          };
        }
        return kpis;
      }
    } catch (e) {
      debugPrint('Error obteniendo KPIs: $e');
    }
    return {};
  }

  /// Resetear errores
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}