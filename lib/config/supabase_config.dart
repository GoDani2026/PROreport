class SupabaseConfig {
  // Project URL and publishable key.
  // These values are safe to expose in client apps.
  static const String supabaseUrl = 'https://inleckebqssizgeovgov.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_6XdOZiVUVFL1qDTOQfulbQ_Sta0McXC';

  // Service Role Key (necesaria solo para scripts/administración).
  // NUNCA uses esta clave en una app de cliente.
  // Para producción, reemplázala por una variable de entorno segura.
  static const String supabaseServiceRoleKey =
      'TU_SERVICE_ROLE_KEY_AQUI';

  // Bucket names
  static const String storageBucket = 'incidentes_storage';

  // Table names
  static const String tableIncidentes = 'incidentes';
  static const String tableTiposIncidente = 'tipos_incidente';
  static const String tableAreas = 'areas';
  static const String tablePerfiles = 'perfiles';
}
