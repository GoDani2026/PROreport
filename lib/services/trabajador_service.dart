// ================================================================
// PROreport - TrabajadorService
// ----------------------------------------------------------------
// Capa única de acceso a datos de trabajadores y cumplimiento HSE.
// Las pantallas NO deben importar supabase_flutter directamente,
// solo llamar a métodos de este servicio.
//
// Para operaciones atómicas (trabajador + cumplimientos) usa RPC:
//   supabase.rpc('upsert_trabajador_completo', params: {...})
// ================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'exceptions.dart';

class TrabajadorService {
  final SupabaseClient _db;

  /// Constructor con inyección opcional del cliente.
  /// Por defecto usa Supabase.instance.client.
  TrabajadorService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════════
  // CONSULTAS
  // ═══════════════════════════════════════════════════════════════

  /// Obtiene todos los trabajadores con campos seleccionados.
  Future<List<Map<String, dynamic>>> fetchAllTrabajadores() async {
    try {
      final res = await _db
          .from('trabajadores')
          .select(
              'id, rut, nombre, apellido_paterno, apellido_materno, cargo, nacionalidad, fecha_vencimiento_residencia, sexo, turno, estado_trabajador, contrato_codigo')
          .order('apellido_paterno', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al cargar trabajadores: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al cargar trabajadores');
    }
  }

  /// Obtiene un trabajador por su ID.
  Future<Map<String, dynamic>?> fetchTrabajadorById(int id) async {
    try {
      final res = await _db
          .from('trabajadores')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al buscar trabajador: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al buscar trabajador');
    }
  }

  /// Busca un trabajador por RUT exacto.
  Future<Map<String, dynamic>?> fetchTrabajadorPorRut(String rut) async {
    try {
      final res = await _db
          .from('trabajadores')
          .select()
          .eq('rut', rut.trim())
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al buscar por RUT: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al buscar por RUT');
    }
  }

  /// Obtiene el ID de un trabajador por RUT.
  Future<int?> fetchIdPorRut(String rut) async {
    try {
      final res = await _db
          .from('trabajadores')
          .select('id')
          .eq('rut', rut.trim())
          .maybeSingle();
      if (res == null) return null;
      return _toInt(res['id']);
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al buscar ID por RUT: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al buscar ID por RUT');
    }
  }

  /// Obtiene todos los requisitos HSE (catálogo).
  Future<List<Map<String, dynamic>>> fetchRequisitosHSE() async {
    try {
      final res = await _db
          .from('requisitos_hse')
          .select()
          .order('id', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al cargar requisitos: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al cargar requisitos');
    }
  }

  /// Obtiene el cumplimiento de un trabajador específico.
  Future<List<Map<String, dynamic>>> fetchCumplimientoTrabajador(
      int trabajadorId) async {
    try {
      final res = await _db
          .from('cumplimiento_trabajadores')
          .select()
          .eq('trabajador_id', trabajadorId);
      return List<Map<String, dynamic>>.from(res);
    } on PostgrestException catch (e) {
      throw DatabaseException(
          'Error al cargar cumplimiento: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al cargar cumplimiento');
    }
  }

  /// Obtiene cumplimiento para múltiples IDs de trabajadores.
  Future<List<Map<String, dynamic>>> fetchCumplimientoPorIds(
      List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final res = await _db
          .from('cumplimiento_trabajadores')
          .select()
          .inFilter('trabajador_id', ids);
      return List<Map<String, dynamic>>.from(res);
    } on PostgrestException catch (e) {
      throw DatabaseException(
          'Error al cargar cumplimiento masivo: ${e.message}');
    } catch (e) {
      throw NetworkException(
          'Error de conexión al cargar cumplimiento masivo');
    }
  }

  /// Crea un mapa {rut -> datos} para búsqueda rápida.
  Future<Map<String, Map<String, dynamic>>>
      fetchTrabajadoresIndexadosPorRut() async {
    final lista = await fetchAllTrabajadores();
    final map = <String, Map<String, dynamic>>{};
    for (final t in lista) {
      final rut = (t['rut'] ?? '').toString().trim();
      if (rut.isNotEmpty) map[rut] = t;
    }
    return map;
  }

  /// Obtiene los datos completos para exportación a Excel:
  /// trabajadores + cumplimiento + requisitos.
  /// Retorna un mapa con tres listas.
  Future<Map<String, List<Map<String, dynamic>>>>
      fetchDatosExportacion() async {
    try {
      final results = await Future.wait([
        _db
            .from('trabajadores')
            .select(
                'id, rut, nombre, apellido_paterno, apellido_materno, cargo, nacionalidad, fecha_vencimiento_residencia, sexo, turno, estado_trabajador, contrato_codigo')
            .order('apellido_paterno', ascending: true),
        _db
            .from('cumplimiento_trabajadores')
            .select('trabajador_id, requisito_id, valor_estado, fecha_vencimiento'),
        _db.from('requisitos_hse').select('id').order('id', ascending: true),
      ]);
      return {
        'trabajadores':
            (results[0] as List).map((e) => Map<String, dynamic>.from(e)).toList(),
        'cumplimiento':
            (results[1] as List).map((e) => Map<String, dynamic>.from(e)).toList(),
        'requisitos':
            (results[2] as List).map((e) => Map<String, dynamic>.from(e)).toList(),
      };
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al cargar datos de exportación: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al cargar datos de exportación');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // OPERACIONES ATÓMICAS (RPC — transacción ACID en el servidor)
  // ═══════════════════════════════════════════════════════════════

  /// Guarda un trabajador y sus cumplimientos en una transacción ACID
  /// usando la función RPC 'upsert_trabajador_completo'.
  ///
  /// [datosTrabajador] debe contener al menos 'rut'.
  /// [cumplimientos] es una lista de mapas con 'requisito_id' y 'valor_estado'.
  ///
  /// Retorna el ID del trabajador insertado/actualizado.
  Future<int> guardarTrabajadorCompleto({
    required Map<String, dynamic> datosTrabajador,
    List<Map<String, dynamic>> cumplimientos = const [],
  }) async {
    try {
      final result = await _db.rpc('upsert_trabajador_completo', params: {
        'p_datos': datosTrabajador,
        'p_cumplimientos': cumplimientos,
      });

      final map = Map<String, dynamic>.from(result);
      if (map['success'] != true) {
        throw RpcException(
          map['error']?.toString() ?? 'Error al guardar trabajador',
          rpcResult: map,
        );
      }

      final trabajadorId = _toInt(map['trabajador_id']);
      if (trabajadorId == null) {
        throw RpcException('La RPC no retornó un ID válido', rpcResult: map);
      }

      return trabajadorId;
    } on RpcException {
      rethrow;
    } on PostgrestException catch (e) {
      throw DatabaseException('Error en RPC: ${e.message}');
    } catch (e) {
      throw NetworkException(
          'Error de conexión al guardar trabajador: $e');
    }
  }

  /// Carga masiva atómica: envía un lote de trabajadores con sus
  /// cumplimientos a la función RPC 'upsert_trabajadores_lote'.
  ///
  /// [lote] es una lista de mapas con estructura:
  ///   { 'datos': { ... }, 'cumplimientos': [ ... ] }
  ///
  /// Retorna un mapa con { total_ok, total_err, errores }.
  Future<Map<String, dynamic>> cargaMasivaAtomica({
    required List<Map<String, dynamic>> lote,
  }) async {
    if (lote.isEmpty) {
      return {'success': true, 'total_ok': 0, 'total_err': 0, 'errores': <String>[]};
    }

    try {
      final result = await _db.rpc('upsert_trabajadores_lote', params: {
        'p_lote': lote,
      });

      final map = Map<String, dynamic>.from(result);
      return map;
    } on PostgrestException catch (e) {
      throw DatabaseException('Error en carga masiva RPC: ${e.message}');
    } catch (e) {
      throw NetworkException(
          'Error de conexión en carga masiva: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // OPERACIONES SIMPLES (vía REST — migración progresiva a RPC)
  // ═══════════════════════════════════════════════════════════════

  /// Actualiza los datos de un trabajador existente por ID.
  Future<void> actualizarTrabajador(
      int id, Map<String, dynamic> datos) async {
    try {
      final payload = Map<String, dynamic>.from(datos)
        ..['updated_at'] = DateTime.now().toIso8601String();
      await _db.from('trabajadores').update(payload).eq('id', id);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw DuplicateEntryException('El RUT ya existe en otro registro');
      }
      throw DatabaseException('Error al actualizar: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al actualizar');
    }
  }

  /// Cambia el estado de un trabajador (ACTIVO, DESVINCULADO, LICENCIA).
  Future<void> actualizarEstadoTrabajador(
      int id, String nuevoEstado) async {
    try {
      await _db.from('trabajadores').update({
        'estado_trabajador': nuevoEstado,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al cambiar estado: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al cambiar estado');
    }
  }

  /// Marca un trabajador como DESVINCULADO (baja lógica).
  Future<void> darDeBaja(int id) async {
    await actualizarEstadoTrabajador(id, 'DESVINCULADO');
  }

  /// Rehabilita un trabajador (cambia a ACTIVO).
  Future<void> rehabilitar(int id) async {
    await actualizarEstadoTrabajador(id, 'ACTIVO');
  }

  /// Actualiza los cumplimientos de un trabajador.
  /// Útil para operaciones individuales; para operaciones atómicas
  /// usar [guardarTrabajadorCompleto].
  Future<void> actualizarCumplimiento(
      int trabajadorId, List<Map<String, dynamic>> cumplimientos) async {
    if (cumplimientos.isEmpty) return;
    try {
      final data = cumplimientos.map((c) => {
            'trabajador_id': trabajadorId,
            'requisito_id': c['requisito_id'],
            'valor_estado': c['valor_estado'],
            'fecha_vencimiento': c['fecha_vencimiento'],
            'documento_url': c['documento_url'],
            'updated_at': DateTime.now().toIso8601String(),
          }).toList();

      await _db
          .from('cumplimiento_trabajadores')
          .upsert(data, onConflict: 'trabajador_id,requisito_id');
    } on PostgrestException catch (e) {
      throw DatabaseException(
          'Error al actualizar cumplimiento: ${e.message}');
    } catch (e) {
      throw NetworkException(
          'Error de conexión al actualizar cumplimiento');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTODOS LEGADOS (mantenidos para compatibilidad, serán migrados)
  // ═══════════════════════════════════════════════════════════════

  /// Obtiene o crea un trabajador por RUT.
  @Deprecated('Usar guardarTrabajadorCompleto para operaciones atómicas')
  Future<int> obtenerOCrearIdPorRut(
      Map<String, dynamic> datosTrabajador) async {
    final rut = (datosTrabajador['rut'] ?? '').toString().trim();
    final existente = await fetchIdPorRut(rut);
    if (existente != null) return existente;

    try {
      final res = await _db
          .from('trabajadores')
          .upsert(datosTrabajador, onConflict: 'rut')
          .select('id')
          .single();
      return _toInt(res['id']) ?? 0;
    } on PostgrestException catch (e) {
      throw DatabaseException(
          'Error al crear trabajador: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al crear trabajador');
    }
  }

  /// Bulk upsert de trabajadores (legado).
  @Deprecated('Usar cargaMasivaAtomica con RPC')
  Future<int> bulkUpsertTrabajadores(List<Map<String, dynamic>> datos) async {
    if (datos.isEmpty) return 0;
    try {
      await _db.from('trabajadores').upsert(datos, onConflict: 'rut');
      return datos.length;
    } on PostgrestException catch (e) {
      throw DatabaseException(
          'Error en bulk upsert: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión en bulk upsert');
    }
  }

  /// Bulk upsert de cumplimiento (legado).
  @Deprecated('Usar cargaMasivaAtomica con RPC')
  Future<void> bulkUpsertCumplimiento(
      List<Map<String, dynamic>> datos) async {
    if (datos.isEmpty) return;
    try {
      for (var i = 0; i < datos.length; i += 100) {
        final lote = datos.sublist(
            i, i + 100 > datos.length ? datos.length : i + 100);
        await _db
            .from('cumplimiento_trabajadores')
            .upsert(lote, onConflict: 'trabajador_id,requisito_id');
      }
    } on PostgrestException catch (e) {
      throw DatabaseException(
          'Error en bulk upsert cumplimiento: ${e.message}');
    } catch (e) {
      throw NetworkException(
          'Error de conexión en bulk upsert cumplimiento');
    }
  }

  /// Upsert individual de cumplimiento (legado).
  @Deprecated('Usar guardarTrabajadorCompleto o actualizarCumplimiento')
  Future<void> upsertCumplimiento(Map<String, dynamic> datos) async {
    try {
      await _db
          .from('cumplimiento_trabajadores')
          .upsert(datos, onConflict: 'trabajador_id,requisito_id');
    } on PostgrestException catch (e) {
      throw DatabaseException(
          'Error al upsert cumplimiento: ${e.message}');
    } catch (e) {
      throw NetworkException(
          'Error de conexión al upsert cumplimiento');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String && v.isNotEmpty) return int.tryParse(v);
    return null;
  }

  /// Tipos de estado permitidos.
  static const List<String> estadosValidos = [
    'ACTIVO',
    'DESVINCULADO',
    'LICENCIA',
  ];
}