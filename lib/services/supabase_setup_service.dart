// ================================================================
// SERVICIO DE AUTO-CONFIGURACIÓN DE SUPABASE
// ----------------------------------------------------------------
// Detecta si faltan tablas o el bucket de storage y los crea
// automáticamente usando la Management API de Supabase.
// ================================================================

import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/supabase_config.dart';

class SupabaseSetupService {
  /// Intenta crear las tablas y el bucket si no existen.
  /// Retorna true si todo está listo, false si hubo error.
  static Future<bool> ensureSetup() async {
    try {
      // 1. Intentar crear las tablas vía la SQL Management API
      await _createTablesIfNotExist();

      // 2. Intentar crear el bucket de storage si no existe
      await _createBucketIfNotExist();

      return true;
    } catch (e) {
      // Si falla la auto-configuración, la app continuará con
      // los datos de ejemplo definidos en IncidenteProvider
      return false;
    }
  }

  /// Crea las tablas ejecutando SQL vía la Management API
  static Future<void> _createTablesIfNotExist() async {
    final sql = '''
CREATE TABLE IF NOT EXISTS tipos_incidente (
  id serial PRIMARY KEY,
  nombre text NOT NULL
);

INSERT INTO tipos_incidente (nombre) VALUES
  ('Acto Inseguro'),
  ('Condición Insegura'),
  ('Casi Accidente')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS areas (
  id serial PRIMARY KEY,
  nombre text NOT NULL
);

INSERT INTO areas (nombre) VALUES
  ('Mina - Tajo Abierto'),
  ('Planta de Procesos'),
  ('Mantenimiento'),
  ('Oficinas Administrativas'),
  ('Almacén'),
  ('Laboratorio')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS perfiles (
  id uuid REFERENCES auth.users PRIMARY KEY,
  nombre_completo text,
  rol text DEFAULT 'colaborador' CHECK (rol IN ('colaborador', 'supervisor', 'admin')),
  avatar_url text,
  created_at timestamp DEFAULT now()
);

CREATE TABLE IF NOT EXISTS incidentes (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  fecha date DEFAULT current_date NOT NULL,
  descripcion text NOT NULL,
  tipo_incidente_id int REFERENCES tipos_incidente(id),
  area_id int REFERENCES areas(id),
  supervisor_id uuid REFERENCES perfiles(id),
  fotos_urls text[] DEFAULT '{}',
  usuario_id uuid REFERENCES auth.users(id),
  created_at timestamp DEFAULT now()
);

ALTER TABLE incidentes ENABLE ROW LEVEL SECURITY;
ALTER TABLE perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipos_incidente ENABLE ROW LEVEL SECURITY;
ALTER TABLE areas ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "Permitir todo a usuarios anonimos"
  ON public.incidentes FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "Usuarios autenticados pueden insertar incidentes"
  ON incidentes FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "Usuarios autenticados pueden ver todos los incidentes"
  ON incidentes FOR SELECT TO authenticated USING (true);

CREATE POLICY IF NOT EXISTS "Perfiles visibles para todos los usuarios autenticados"
  ON perfiles FOR SELECT TO authenticated USING (true);

CREATE POLICY IF NOT EXISTS "Catálogos visibles para usuarios autenticados"
  ON tipos_incidente FOR SELECT TO authenticated USING (true);

CREATE POLICY IF NOT EXISTS "Catálogos visibles para usuarios autenticados"
  ON areas FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS \$\$
BEGIN
  INSERT INTO public.perfiles (id, nombre_completo, rol)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'nombre_completo', 'Usuario'),
    'colaborador'
  );
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

CREATE INDEX IF NOT EXISTS idx_incidentes_fecha ON incidentes(fecha DESC);
CREATE INDEX IF NOT EXISTS idx_incidentes_usuario ON incidentes(usuario_id);

NOTIFY pgrst, 'reload schema';
''';

    await _executeSql(sql);
  }

  /// Crea el bucket de storage si no existe
  static Future<void> _createBucketIfNotExist() async {
    final url =
        'https://${Uri.parse(SupabaseConfig.supabaseUrl).host}/storage/v1/bucket';

    // Primero verificar si ya existe
    final checkResponse = await http.get(
      Uri.parse('$url/${SupabaseConfig.storageBucket}'),
      headers: {
        'Authorization': 'Bearer ${SupabaseConfig.supabaseServiceRoleKey}',
        'apiKey': SupabaseConfig.supabasePublishableKey,
      },
    );

    if (checkResponse.statusCode == 404) {
      // No existe, crearlo
      final createResponse = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${SupabaseConfig.supabaseServiceRoleKey}',
          'apiKey': SupabaseConfig.supabasePublishableKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': SupabaseConfig.storageBucket,
          'name': SupabaseConfig.storageBucket,
          'public': true,
          'file_size_limit': 5242880, // 5 MB
          'allowed_mime_types': ['image/jpeg', 'image/png', 'image/webp'],
        }),
      );

      if (createResponse.statusCode == 201 || createResponse.statusCode == 200) {
        // Crear la carpeta incidentes/ dentro del bucket
        await http.post(
          Uri.parse('$url/${SupabaseConfig.storageBucket}/objects/upload'),
          headers: {
            'Authorization':
                'Bearer ${SupabaseConfig.supabaseServiceRoleKey}',
            'apiKey': SupabaseConfig.supabasePublishableKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'bucketId': SupabaseConfig.storageBucket,
            'path': 'incidentes/.folder',
            'contentType': 'application/octet-stream',
            'cacheControl': '3600',
          }),
        );
      }
    }
    // Si ya existe (200) no hacemos nada
  }

  /// Ejecuta SQL vía la Management API de Supabase
  static Future<void> _executeSql(String sql) async {
    // Extraer el project ref de la URL de Supabase
    // Ej: https://inleckebqssizgeovgov.supabase.co -> inleckebqssizgeovgov
    final projectRef =
        Uri.parse(SupabaseConfig.supabaseUrl).host.split('.').first;

    final url =
        'https://api.supabase.com/v1/projects/$projectRef/sql';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization':
            'Bearer ${SupabaseConfig.supabaseServiceRoleKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'query': sql,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Error al ejecutar SQL: ${response.statusCode} ${response.body}');
    }
  }
}