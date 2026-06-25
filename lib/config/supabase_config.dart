import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  /// Project URL — se carga desde .env
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';

  /// Publishable key (segura para exponer en cliente Flutter) — .env
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';

  /// Storage bucket name — .env
  static String get storageBucket =>
      dotenv.env['STORAGE_BUCKET'] ?? 'documentos_hse';

  // Table names (constantes de aplicación, no sensibles)
  static const String tableIncidentes = 'incidentes';
  static const String tableTiposIncidente = 'tipos_incidente';
  static const String tableAreas = 'areas';
  static const String tablePerfiles = 'perfiles';
  static const String tableDocumentosHse = 'documentos_hse';
  static const String tableCumplimiento = 'cumplimiento';
  static const String tableDeteccionesPeligro = 'detecciones_peligro';
}