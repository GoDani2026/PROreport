import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _client;
  User? _user;
  bool _isLoading = false;

  // ── Estado Global de Contratos ──
  List<String> _contratosUsuario = [];
  String _contratoSeleccionadoContexto = '';
  String _rolUsuario = '';
  int? _trabajadorId;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  List<String> get contratosUsuario => _contratosUsuario;
  String get contratoSeleccionadoContexto => _contratoSeleccionadoContexto;
  String get rolUsuario => _rolUsuario;
  int? get trabajadorId => _trabajadorId;

  AuthProvider(this._client) {
    _user = _client.auth.currentUser;
    // Escuchar cambios de autenticación
    _client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _cargarContratosDelTrabajador();
      } else {
        _contratosUsuario = [];
        _contratoSeleccionadoContexto = '';
        _rolUsuario = '';
        _trabajadorId = null;
        notifyListeners();
      }
    });

    // Si ya hay sesión activa al iniciar la app, cargar contratos inmediatamente
    if (_user != null) {
      _cargarContratosDelTrabajador();
    }
  }

  /// Cambia el contrato activo global para toda la app.
  void actualizarContratoGlobal(String nuevoContrato) {
    _contratoSeleccionadoContexto = nuevoContrato;
    notifyListeners();
  }

  /// Carga los contratos del usuario logueado.
  /// - Si es superadmin o no tiene trabajador_id, obtiene TODOS los contratos.
  /// - Si es trabajador común, obtiene solo sus contratos asignados.
  Future<void> _cargarContratosDelTrabajador() async {
    final uid = _user?.id;
    if (uid == null) return;

    try {
      // 1. Obtener perfil del usuario (rol + trabajador_id)
      final perfil = await _client
          .from('perfiles')
          .select('rol, trabajador_id')
          .eq('id', uid)
          .maybeSingle();

      _rolUsuario = (perfil?['rol'] as String?) ?? '';
      _trabajadorId = (perfil != null ? perfil['trabajador_id'] as int? : null);

      debugPrint('=== AUTH DIAGNOSTICO ===');
      debugPrint('Uid: $uid');
      debugPrint('Rol: $_rolUsuario');
      debugPrint('TrabajadorId: $_trabajadorId');

      List<String> contratos = [];

      if (_rolUsuario == 'superadmin') {
        // 2a. SuperAdmin: obtiene TODOS los contratos
        final res = await _client
            .from('contratos')
            .select('codigo, estado')
            .order('codigo', ascending: true);
        
        contratos = (res as List)
            .map((r) => (r['codigo'] as String?) ?? '')
            .where((c) => c.isNotEmpty)
            .toList();
      } else if (_trabajadorId != null) {
        // 2b. Trabajador común: solo sus contratos asignados
        final trabajadorId = _trabajadorId!;
        final res = await _client
            .from('trabajador_contratos')
            .select('contrato_codigo')
            .eq('trabajador_id', trabajadorId)
            .order('contrato_codigo', ascending: true);
        contratos = (res as List)
            .map((r) => (r['contrato_codigo'] as String?) ?? '')
            .where((c) => c.isNotEmpty)
            .toList();
      }

      _contratosUsuario = contratos;

      debugPrint('Contratos cargados: $contratos');
      debugPrint('ContratosUsuario count: ${contratos.length}');

      // 3. Inicializar contrato por defecto
      if (contratos.length == 1) {
        _contratoSeleccionadoContexto = contratos.first;
      } else if (contratos.isNotEmpty) {
        _contratoSeleccionadoContexto = contratos.first;
      } else {
        _contratoSeleccionadoContexto = '';
      }

      debugPrint('ContratoSeleccionadoContexto: $_contratoSeleccionadoContexto');
    } catch (e) {
      debugPrint('Error al cargar contratos del usuario: $e');
      _contratosUsuario = [];
      _contratoSeleccionadoContexto = '';
    }

    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      _user = _client.auth.currentUser;
      // Cargar contratos después del login exitoso
      if (_user != null) {
        await _cargarContratosDelTrabajador();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      // Después del registro, el usuario también está logueado
      _user = _client.auth.currentUser;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _client.auth.signOut();
      _user = null;
      _contratosUsuario = [];
      _contratoSeleccionadoContexto = '';
      _rolUsuario = '';
      _trabajadorId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verificar si hay una sesión activa
  bool hasActiveSession() {
    return _client.auth.currentSession != null;
  }
}
