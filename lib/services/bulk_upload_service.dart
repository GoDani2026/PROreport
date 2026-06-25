// ================================================================
// BULK UPLOAD SERVICE — MIGRADO A RPC
// ----------------------------------------------------------------
// Este archivo SE MANTIENE por compatibilidad pero su lógica ahora
// delega en TrabajadorService.cargaMasivaAtomica() que usa la RPC
// 'upsert_trabajadores_lote' de PostgreSQL (transacción ACID).
//
// El viejo método HTTP directo con service_role_key se elimina.
// Ahora se usa el cliente Supabase autenticado vía RPC SECURITY DEFINER.
// ================================================================

import '../services/trabajador_service.dart';
import '../services/exceptions.dart';

class BulkUploadResult {
  final int totalTrabajadores;
  final int totalCumplimiento;
  final int errores;
  final String? mensajeError;

  BulkUploadResult({
    required this.totalTrabajadores,
    required this.totalCumplimiento,
    this.errores = 0,
    this.mensajeError,
  });
}

@Deprecated('Usar TrabajadorService.cargaMasivaAtomica() en su lugar')
class BulkUploadService {
  final TrabajadorService _service;

  BulkUploadService({TrabajadorService? service})
      : _service = service ?? TrabajadorService();

  /// Sube trabajadores + cumplimiento usando la RPC atómica.
  ///
  /// [trabajadores]: lista de mapas con datos de trabajadores (debe incluir 'rut')
  /// [cumplimientoBuilder]: función que recibe {rut -> id} y retorna lista de cumplimiento maps
  ///
  /// Retorna [BulkUploadResult] con conteos.
  Future<BulkUploadResult> upload({
    required List<Map<String, dynamic>> trabajadores,
    required List<Map<String, dynamic>> Function(Map<String, int> idMap)
        cumplimientoBuilder,
  }) async {
    if (trabajadores.isEmpty) {
      return BulkUploadResult(totalTrabajadores: 0, totalCumplimiento: 0);
    }

    try {
      // Construir lote con estructura { datos, cumplimientos }
      // Nota: como la RPC recibe cumplimientos dentro del mismo payload,
      // NO necesitamos el idMap antes (la RPC genera el ID internamente).
      // Sin embargo, mantenemos la interfaz legacy que recibe cumplimientoBuilder.
      // Construimos un idMap temporal {rut -> 0} ya que la RPC asigna los IDs.
      final cumplMap = <String, List<Map<String, dynamic>>>{};
      for (final t in trabajadores) {
        final rut = (t['rut'] ?? '').toString().trim();
        if (rut.isNotEmpty) {
          cumplMap[rut] = [];
        }
      }

      // El cumplimientoBuilder legacy espera recibir un idMap {rut -> id}.
      // Como la RPC asigna IDs internamente, ignoramos el idMap en el builder.
      // Pero debemos cumplir con la interfaz legacy.
      final tempIdMap = <String, int>{};
      var idx = 1;
      for (final rut in cumplMap.keys) {
        tempIdMap[rut] = idx++;
      }

      final cumplimientoList = cumplimientoBuilder(tempIdMap);

      // Re-agrupar cumplimientos por RUT usando los datos originales
      // Asumimos que cumplimientoList viene en el mismo orden que trabajadores
      var cumIdx = 0;
      for (final t in trabajadores) {
        final rut = (t['rut'] ?? '').toString().trim();
        final reqsPorTrabajador = 12; // 12 requisitos HSE fijos
        if (rut.isNotEmpty) {
          cumplMap[rut] = [];
          for (var j = 0; j < reqsPorTrabajador; j++) {
            if (cumIdx + j < cumplimientoList.length) {
              cumplMap[rut]!.add(cumplimientoList[cumIdx + j]);
            }
          }
        }
        cumIdx += reqsPorTrabajador;
      }

      // Construir lote para RPC
      final lote = trabajadores.map((t) {
        final rut = (t['rut'] ?? '').toString().trim();
        return {
          'datos': t,
          'cumplimientos': cumplMap[rut] ?? [],
        };
      }).toList();

      // Ejecutar carga masiva atómica vía RPC
      final result = await _service.cargaMasivaAtomica(lote: lote);

      final totalOk = (result['total_ok'] as num?)?.toInt() ?? 0;
      final totalErr = (result['total_err'] as num?)?.toInt() ?? 0;
      final erroresList = (result['errores'] as List?) ?? [];

      return BulkUploadResult(
        totalTrabajadores: totalOk,
        totalCumplimiento: totalOk * 12, // Aproximación: 12 reqs por trabajador
        errores: totalErr,
        mensajeError: totalErr > 0
            ? '$totalErr error(es): ${erroresList.join('; ')}'
            : null,
      );
    } on ServiceException catch (e) {
      return BulkUploadResult(
        totalTrabajadores: 0,
        totalCumplimiento: 0,
        errores: 1,
        mensajeError: e.message,
      );
    } catch (e) {
      return BulkUploadResult(
        totalTrabajadores: 0,
        totalCumplimiento: 0,
        errores: 1,
        mensajeError: 'Error de conexión: $e',
      );
    }
  }
}