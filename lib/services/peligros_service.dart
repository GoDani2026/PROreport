// ================================================================
// PROreport - PeligrosService
// ----------------------------------------------------------------
// Capa única de acceso a datos del módulo Detecciones de Peligro.
// Las pantallas NO deben importar supabase_flutter directamente,
// solo llamar a métodos de este servicio.
//
// Para operaciones atómicas usa las RPCs:
//   supabase.rpc('iniciar_ejecucion_peligro', params: {...})
//   supabase.rpc('cerrar_peligro', params: {...})
// ================================================================
//
// ╔═══════════════════════════════════════════════════════════════╗
// ║ TODO: BACKEND — Webhooks + Edge Functions (Supabase)         ║
// ║ ============================================================ ║
// ║ Cuando se inserte un nuevo registro en `detecciones_peligro`, ║
// ║ una Edge Function de Supabase (disparada por Database        ║
// ║ Webhook en el evento INSERT) deberá encargarse de:           ║
// ║                                                              ║
// ║ 1. Obtener el perfil del usuario_reportante_id.              ║
// ║ 2. Obtener el trabajador asociado (perfiles.trabajador_id).  ║
// ║ 3. Determinar el rol del reportante:                         ║
// ║    a) Si rol == 'colaborador' (Trabajador):                  ║
// ║       → Enviar correo a su Supervisor directo + equipo HSE.  ║
// ║         (Supervisor se obtiene de la relación jerárquica     ║
// ║          o de un campo supervisor_id en trabajadores.)       ║
// ║    b) Si rol == 'supervisor':                                ║
// ║       → Enviar correo solo al equipo HSE.                    ║
// ║ 4. El correo debe incluir: foto_evidencia_url,               ║
// ║    descripcion_hallazgo, nivel_atencion_lgf, lugar_exacto,   ║
// ║    area, turno, y un link al PDF evolutivo.                  ║
// ║ 5. Generar el PDF evolutivo y almacenar la URL en            ║
// ║    url_pdf_evolutivo.                                        ║
// ║                                                              ║
// ║ NOTA: La app Flutter NO debe generar el PDF ni enviar el     ║
// ║ correo. Solo debe subir las fotos a Supabase Storage y       ║
// ║ llamar a la base de datos.                                   ║
// ╚═══════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deteccion_peligro_model.dart';
import 'exceptions.dart';

class PeligrosService {
  final SupabaseClient _db;

  /// Bucket donde se almacenan las fotos de evidencia y cierre.
  static const String _storageBucket = 'documentos_hse';

  /// Constructor con inyección opcional del cliente.
  /// Por defecto usa Supabase.instance.client.
  PeligrosService({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  // ═══════════════════════════════════════════════════════════════
  // CONSULTAS
  // ═══════════════════════════════════════════════════════════════

  /// Obtiene todas las detecciones de peligro.
  Future<List<DeteccionPeligro>> fetchAll() async {
    try {
      final res = await _db
          .from('detecciones_peligro')
          .select()
          .order('created_at', ascending: false);
      return (res as List)
          .map((e) => DeteccionPeligro.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al cargar detecciones: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al cargar detecciones');
    }
  }

  /// Obtiene una detección por su ID.
  Future<DeteccionPeligro?> fetchById(int id) async {
    try {
      final res = await _db
          .from('detecciones_peligro')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      return DeteccionPeligro.fromJson(res);
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al buscar detección: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al buscar detección');
    }
  }

  /// Obtiene las detecciones filtradas por estatus.
  Future<List<DeteccionPeligro>> fetchByEstatus(String estatus) async {
    try {
      final res = await _db
          .from('detecciones_peligro')
          .select()
          .eq('estatus_seguimiento', estatus)
          .order('created_at', ascending: false);
      return (res as List)
          .map((e) => DeteccionPeligro.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(
          'Error al filtrar detecciones: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al filtrar detecciones');
    }
  }

  /// Obtiene el listado de áreas activas para selects.
  @Deprecated('Las áreas fueron reemplazadas por contrato_codigo. Usar AuthProvider.contratosUsuario.')
  Future<List<Map<String, dynamic>>> fetchAreas() async {
    try {
      final res = await _db
          .from('areas')
          .select('id, nombre')
          .order('nombre', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al cargar áreas: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al cargar áreas');
    }
  }

  /// Obtiene el turno del trabajador asociado al perfil actual.
  Future<String?> fetchTurnoDelTrabajador(String perfilId) async {
    try {
      final res = await _db
          .from('perfiles')
          .select('trabajador_id')
          .eq('id', perfilId)
          .maybeSingle();
      if (res == null) return null;
      final trabajadorId = res['trabajador_id'] as int?;
      if (trabajadorId == null) return null;

      final trabajador = await _db
          .from('trabajadores')
          .select('turno')
          .eq('id', trabajadorId)
          .maybeSingle();
      if (trabajador == null) return null;
      return trabajador['turno'] as String?;
    } catch (e) {
      return null; // Silencioso: el turno es un campo secundario
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // OPERACIONES DE ESCRITURA
  // ═══════════════════════════════════════════════════════════════

  /// Inserta una nueva detección de peligro.
  /// Retorna el ID del registro creado.
  Future<int> insertDeteccion(DeteccionPeligro deteccion) async {
    try {
      final res = await _db
          .from('detecciones_peligro')
          .insert(deteccion.toJson())
          .select('id')
          .single();
      return res['id'] as int;
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al crear detección: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al crear detección');
    }
  }

  /// Sube una foto a Supabase Storage y retorna la URL pública.
  Future<String> uploadFoto({
    required String filePath,
    required String bucketPath,
  }) async {
    try {
      // El path incluirá un identificador único para evitar colisiones
      final file = File(filePath);
      await _db.storage
          .from(_storageBucket)
          .upload(bucketPath, file);

      // Obtener URL pública
      final publicUrl = _db.storage
          .from(_storageBucket)
          .getPublicUrl(bucketPath);

      return publicUrl;
    } on StorageException catch (e) {
      // Si el archivo ya existe (409), reemplazar
      if (e.statusCode == '409') {
        final file = File(filePath);
        await _db.storage
            .from(_storageBucket)
            .update(bucketPath, file);
        final publicUrl = _db.storage
            .from(_storageBucket)
            .getPublicUrl(bucketPath);
        return publicUrl;
      }
      throw DatabaseException('Error al subir foto: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al subir foto');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // RPCs (Remote Procedure Calls)
  // ═══════════════════════════════════════════════════════════════

  /// RPC 1: Inicia la ejecución del plan para eliminar el peligro.
  /// Actualiza estatus a 'En Ejecución', asigna supervisor,
  /// guarda plan_accion y fecha_compromiso_eliminacion.
  Future<void> callIniciarEjecucion({
    required int deteccionId,
    required int supervisorId,
    required String planAccion,
    required DateTime fechaCompromiso,
  }) async {
    try {
      await _db.rpc('iniciar_ejecucion_peligro', params: {
        'p_deteccion_id': deteccionId,
        'p_supervisor_id': supervisorId,
        'p_plan_accion': planAccion,
        'p_fecha_compromiso':
            '${fechaCompromiso.year.toString().padLeft(4, '0')}-${fechaCompromiso.month.toString().padLeft(2, '0')}-${fechaCompromiso.day.toString().padLeft(2, '0')}',
      });
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al iniciar ejecución: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al iniciar ejecución');
    }
  }

  /// RPC 2: Cierra el caso de peligro.
  /// Actualiza estatus a 'Eliminada', guarda resumen_cierre y
  /// foto_cierre_url, y estampa atómicamente fecha_cierre con NOW().
  Future<void> callCerrarPeligro({
    required int deteccionId,
    required String resumenCierre,
    String? fotoCierreUrl,
  }) async {
    try {
      await _db.rpc('cerrar_peligro', params: {
        'p_deteccion_id': deteccionId,
        'p_resumen_cierre': resumenCierre,
        // ignore: use_null_aware_elements
        if (fotoCierreUrl != null) 'p_foto_cierre_url': fotoCierreUrl,
      });
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al cerrar caso: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al cerrar caso');
    }
  }

  /// Obtiene la lista de supervisores (trabajadores con cargo supervisor)
  /// para el selector de supervisor responsable.
  Future<List<Map<String, dynamic>>> fetchSupervisores() async {
    try {
      final res = await _db
          .from('trabajadores')
          .select('id, nombre, apellido_paterno, apellido_materno, cargo')
          .ilike('cargo', '%supervisor%')
          .eq('estado_trabajador', 'ACTIVO')
          .order('apellido_paterno', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } on PostgrestException catch (e) {
      throw DatabaseException('Error al cargar supervisores: ${e.message}');
    } catch (e) {
      throw NetworkException('Error de conexión al cargar supervisores');
    }
  }
}