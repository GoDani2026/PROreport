// ================================================================
// SERVICIO DE AUTO-CONFIGURACIÓN DE SUPABASE
// ----------------------------------------------------------------
// Solo verifica la existencia del bucket con la publishable key.
// La CREACIÓN del bucket se debe hacer desde scripts/admin.
// ================================================================

import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';

class SupabaseSetupService {
  /// Verifica si el bucket existe y está accesible con la publishable key.
  /// Si existe retorna true. Si no existe o hay error, retorna false.
  /// La creación del bucket debe realizarse desde scripts administrativos.
  static Future<bool> ensureSetup() async {
    try {
      final bucket = SupabaseConfig.storageBucket;
      final url =
          'https://${Uri.parse(SupabaseConfig.supabaseUrl).host}/storage/v1/bucket/$bucket';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'apikey': SupabaseConfig.supabasePublishableKey,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      // Si el bucket no existe aún o no hay conexión, retorna false.
      // La app debe mostrar un mensaje indicando que contacte al admin.
      return false;
    }
  }

  /// Obtiene el nombre del bucket desde .env
  static String get storageBucket => SupabaseConfig.storageBucket;
}