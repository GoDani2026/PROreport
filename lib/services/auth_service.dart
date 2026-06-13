import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  // Iniciar sesión
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Registrar nuevo usuario
  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // Obtener usuario actual
  User? get currentUser => _client.auth.currentUser;

  // Verificar si hay sesión activa
  bool get isSignedIn => _client.auth.currentUser != null;

  // Escuchar cambios de autenticación
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
