import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/tipo_incidente.dart';
import '../models/area.dart';
import '../models/perfil.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // Tipos de Incidente
  Future<List<TipoIncidente>> getTiposIncidente() async {
    final response = await _client
        .from(SupabaseConfig.tableTiposIncidente)
        .select()
        .order('id');
    return (response as List)
        .map((json) => TipoIncidente.fromJson(json))
        .toList();
  }

  // Áreas
  Future<List<Area>> getAreas() async {
    final response =
        await _client.from(SupabaseConfig.tableAreas).select().order('id');
    return (response as List)
        .map((json) => Area.fromJson(json))
        .toList();
  }

  // Supervisores
  Future<List<Perfil>> getSupervisores() async {
    final response = await _client
        .from(SupabaseConfig.tablePerfiles)
        .select()
        .eq('rol', 'supervisor')
        .order('nombre_completo');
    return (response as List)
        .map((json) => Perfil.fromJson(json))
        .toList();
  }

  // Perfil del usuario actual
  Future<Perfil?> getPerfilActual() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from(SupabaseConfig.tablePerfiles)
        .select()
        .eq('id', user.id)
        .single();

    return Perfil.fromJson(response);
  }
}
