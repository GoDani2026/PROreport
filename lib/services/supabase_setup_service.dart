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
-- ============================================================
-- TABLAS DEL SISTEMA DE INCIDENTES (existente)
-- ============================================================
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

-- ============================================================
-- TABLAS DE GESTIÓN DE PERSONAL (HSE)
-- ============================================================

-- 1. Tabla: trabajadores (Datos fijos del personal)
CREATE TABLE IF NOT EXISTS trabajadores (
  id serial PRIMARY KEY,
  rut text UNIQUE NOT NULL,
  nombre text NOT NULL,
  apellido_paterno text NOT NULL,
  apellido_materno text,
  cargo text NOT NULL,
  nacionalidad text DEFAULT 'Chilena',
  vencimiento_residencia text,
  sexo text CHECK (sexo IN ('M', 'F', 'Otro')),
  turno text NOT NULL,
  estado_trabajador text NOT NULL DEFAULT 'ACTIVO' CHECK (estado_trabajador IN ('ACTIVO', 'DESVINCULADO', 'LICENCIA')),
  contrato_codigo text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- 2. Tabla: requisitos_hse (Catálogo dinámico de documentos/exámenes)
CREATE TABLE IF NOT EXISTS requisitos_hse (
  id serial PRIMARY KEY,
  nombre_requisito text NOT NULL,
  requiere_vencimiento boolean NOT NULL DEFAULT false
);

-- Poblar catálogo con los 12 requisitos exactos del Excel
INSERT INTO requisitos_hse (nombre_requisito, requiere_vencimiento) VALUES
  ('Exámenes Ocupacionales / Pre-Ocupacionales (AG/AF)', true),
  ('Examen Alcohol y drogas', true),
  ('Examen Psicosensometrico', true),
  ('Fecha Vencimiento Inducción SQM', true),
  ('Protocolo SQM (ODI)', false),
  ('CTTA(ODI)', false),
  ('Certificación (Soldadores, electricos, riggers, op.Maquinaria, etc)', false),
  ('Licencia Interna SQM', false),
  ('Difusión Procedimientos', false),
  ('Difusión Plan y Sub Planes SQM', false),
  ('Difusión Plan y Sub Planes Cttas', false),
  ('Difusión HDS', false)
ON CONFLICT DO NOTHING;

-- 3. Tabla: cumplimiento_trabajadores (Matriz vertical de estados y fechas)
CREATE TABLE IF NOT EXISTS cumplimiento_trabajadores (
  id serial PRIMARY KEY,
  trabajador_id integer NOT NULL REFERENCES trabajadores(id) ON DELETE CASCADE,
  requisito_id integer NOT NULL REFERENCES requisitos_hse(id) ON DELETE RESTRICT,
  valor_estado text NOT NULL CHECK (valor_estado IN ('VIGENTE', 'SI', 'NO', 'N/A', 'VENCIDO')),
  fecha_vencimiento date,
  documento_url text,
  updated_at timestamp with time zone DEFAULT now(),
  UNIQUE(trabajador_id, requisito_id)
);

-- TRIGGER: Actualizar updated_at automáticamente en trabajadores
CREATE OR REPLACE FUNCTION public.handle_updated_at_trabajadores()
RETURNS trigger AS \$\$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_trabajadores_updated ON trabajadores;
CREATE OR REPLACE TRIGGER on_trabajadores_updated
  BEFORE UPDATE ON trabajadores
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_trabajadores();

-- Trigger para cumplimiento_trabajadores
CREATE OR REPLACE FUNCTION public.handle_updated_at_cumplimiento()
RETURNS trigger AS \$\$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_cumplimiento_updated ON cumplimiento_trabajadores;
CREATE OR REPLACE TRIGGER on_cumplimiento_updated
  BEFORE UPDATE ON cumplimiento_trabajadores
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at_cumplimiento();

-- Políticas de seguridad RLS
ALTER TABLE trabajadores ENABLE ROW LEVEL SECURITY;
ALTER TABLE requisitos_hse ENABLE ROW LEVEL SECURITY;
ALTER TABLE cumplimiento_trabajadores ENABLE ROW LEVEL SECURITY;

-- Políticas para trabajadores
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver trabajadores" ON trabajadores;
CREATE POLICY "Usuarios autenticados pueden ver trabajadores"
  ON trabajadores FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar trabajadores" ON trabajadores;
CREATE POLICY "Usuarios autenticados pueden insertar trabajadores"
  ON trabajadores FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar trabajadores" ON trabajadores;
CREATE POLICY "Usuarios autenticados pueden actualizar trabajadores"
  ON trabajadores FOR UPDATE
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar trabajadores" ON trabajadores;
CREATE POLICY "Usuarios autenticados pueden eliminar trabajadores"
  ON trabajadores FOR DELETE
  TO authenticated
  USING (true);

-- Políticas para requisitos_hse
DROP POLICY IF EXISTS "Requisitos HSE visibles para usuarios autenticados" ON requisitos_hse;
CREATE POLICY "Requisitos HSE visibles para usuarios autenticados"
  ON requisitos_hse FOR SELECT
  TO authenticated
  USING (true);

-- Políticas para cumplimiento_trabajadores
DROP POLICY IF EXISTS "Usuarios autenticados pueden ver cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden ver cumplimiento"
  ON cumplimiento_trabajadores FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden insertar cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden insertar cumplimiento"
  ON cumplimiento_trabajadores FOR INSERT
  TO authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden actualizar cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden actualizar cumplimiento"
  ON cumplimiento_trabajadores FOR UPDATE
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "Usuarios autenticados pueden eliminar cumplimiento" ON cumplimiento_trabajadores;
CREATE POLICY "Usuarios autenticados pueden eliminar cumplimiento"
  ON cumplimiento_trabajadores FOR DELETE
  TO authenticated
  USING (true);

-- Políticas para acceso público anon (para debugging)
DROP POLICY IF EXISTS "Acceso anon a trabajadores" ON trabajadores;
CREATE POLICY "Acceso anon a trabajadores"
  ON trabajadores FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS "Acceso anon a requisitos_hse" ON requisitos_hse;
CREATE POLICY "Acceso anon a requisitos_hse"
  ON requisitos_hse FOR SELECT
  TO anon
  USING (true);

DROP POLICY IF EXISTS "Acceso anon a cumplimiento_trabajadores" ON cumplimiento_trabajadores;
CREATE POLICY "Acceso anon a cumplimiento_trabajadores"
  ON cumplimiento_trabajadores FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- Índices para optimizar consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_trabajadores_rut ON trabajadores(rut);
CREATE INDEX IF NOT EXISTS idx_trabajadores_estado ON trabajadores(estado_trabajador);
CREATE INDEX IF NOT EXISTS idx_trabajadores_contrato ON trabajadores(contrato_codigo);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_trabajador ON cumplimiento_trabajadores(trabajador_id);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_requisito ON cumplimiento_trabajadores(requisito_id);
CREATE INDEX IF NOT EXISTS idx_cumplimiento_estado ON cumplimiento_trabajadores(valor_estado);

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