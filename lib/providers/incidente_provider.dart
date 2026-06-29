import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/solicitud_levantamiento_model.dart';
import '../services/storage_service.dart';
import '../config/supabase_config.dart';

class IncidenteProvider extends ChangeNotifier {
  final SupabaseClient _client;
  final StorageService _storageService;

  IncidenteProvider(this._client, this._storageService);

  // ─── ESTADO - Catálogos ───────────────────────────────────────

  List<TipoIncidente> _tiposIncidente = [];
  List<TipoIncidente> get tiposIncidente => _tiposIncidente;

  List<Area> _areas = [];
  List<Area> get areas => _areas;

  List<Map<String, dynamic>> _trabajadores = [];
  List<Map<String, dynamic>> get trabajadores => _trabajadores;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ─── ESTADO - Formulario ──────────────────────────────────────

  String _descripcion = '';
  String get descripcion => _descripcion;

  TipoIncidente? _tipoIncidente;
  TipoIncidente? get tipoIncidente => _tipoIncidente;

  Area? _area;
  Area? get area => _area;

  int? _supervisorTrabajadorId;
  int? get supervisorTrabajadorId => _supervisorTrabajadorId;

  String? _supervisorNombre;
  String? get supervisorNombre => _supervisorNombre;

  XFile? _fotoEvidencia;
  XFile? get fotoEvidencia => _fotoEvidencia;

  String? _fotoEvidenciaUrl;
  String? get fotoEvidenciaUrl => _fotoEvidenciaUrl;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── MÉTODOS - Carga de Catálogos ────────────────────────────

  Future<void> loadCatalogos() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _client.from('tipos_incidente').select('id, nombre').order('nombre'),
        _client.from('areas').select('id, nombre').order('nombre'),
        _client
            .from('trabajadores')
            .select('id, nombre, apellido_paterno, apellido_materno, cargo')
            .ilike('cargo', '%supervisor%')
            .eq('estado_trabajador', 'ACTIVO')
            .order('apellido_paterno'),
      ]);

      _tiposIncidente = (results[0] as List)
          .map((e) => TipoIncidente.fromJson(e as Map<String, dynamic>))
          .toList();

      _areas = (results[1] as List)
          .map((e) => Area.fromJson(e as Map<String, dynamic>))
          .toList();

      _trabajadores = List<Map<String, dynamic>>.from(results[2]);

      // Fallbacks si no hay datos
      if (_tiposIncidente.isEmpty) {
        _tiposIncidente = [
          TipoIncidente(id: 1, nombre: 'Incidente de Seguridad'),
          TipoIncidente(id: 2, nombre: 'Emergencia Médica'),
          TipoIncidente(id: 3, nombre: 'Incidente Ambiental'),
        ];
      }
      if (_areas.isEmpty) {
        _areas = [
          Area(id: 1, nombre: 'Mina'),
          Area(id: 2, nombre: 'Planta'),
          Area(id: 3, nombre: 'Mantenimiento'),
        ];
      }
    } catch (e) {
      // Fallbacks offline
      _tiposIncidente = [
        TipoIncidente(id: 1, nombre: 'Incidente de Seguridad'),
        TipoIncidente(id: 2, nombre: 'Emergencia Médica'),
        TipoIncidente(id: 3, nombre: 'Incidente Ambiental'),
      ];
      _areas = [
        Area(id: 1, nombre: 'Mina'),
        Area(id: 2, nombre: 'Planta'),
        Area(id: 3, nombre: 'Mantenimiento'),
      ];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── MÉTODOS - Formulario ────────────────────────────────────

  void setDescripcion(String value) {
    _descripcion = value;
  }

  void setTipoIncidente(TipoIncidente? tipo) {
    _tipoIncidente = tipo;
    notifyListeners();
  }

  void setArea(Area? area) {
    _area = area;
    notifyListeners();
  }

  void setSupervisor(int? trabajadorId, String? nombreCompleto) {
    _supervisorTrabajadorId = trabajadorId;
    _supervisorNombre = nombreCompleto;
    notifyListeners();
  }

  Future<void> pickFotoEvidencia({bool useCamera = true}) async {
    try {
      final picker = ImagePicker();
      final source = useCamera ? ImageSource.camera : ImageSource.gallery;
      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (photo != null) {
        _fotoEvidencia = photo;
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al capturar foto: $e';
      notifyListeners();
    }
  }

  void clearFotoEvidencia() {
    _fotoEvidencia = null;
    _fotoEvidenciaUrl = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String? validateForm() {
    if (_descripcion.trim().isEmpty) return 'Debe ingresar una descripción del incidente.';
    if (_tipoIncidente == null) return 'Debe seleccionar un tipo de incidente.';
    if (_area == null) return 'Debe seleccionar un área.';
    if (_supervisorTrabajadorId == null) return 'Debe seleccionar un supervisor responsable.';
    if (_fotoEvidencia == null && _fotoEvidenciaUrl == null) {
      return 'Debe capturar una foto de evidencia.';
    }
    return null;
  }

  // ─── ENVÍO DEL FORMULARIO ────────────────────────────────────

  Future<bool> submitReport() async {
    final validationError = validateForm();
    if (validationError != null) {
      _errorMessage = validationError;
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Subir foto de evidencia al bucket 'evidencias' con subcarpeta 'solicitud_levantamiento'
      String? fotoUrl = _fotoEvidenciaUrl;
      if (_fotoEvidencia != null) {
        fotoUrl = await _storageService.uploadEvidencia(
          _fotoEvidencia!,
          'solicitud_levantamiento',
        );
      }

      // 2. Crear modelo de incidente
      final incidente = Incidente(
        titulo: '${_tipoIncidente!.nombre} - ${_area!.nombre}',
        descripcion: _descripcion.trim(),
        tipoIncidenteId: _tipoIncidente!.id,
        areaId: _area!.id,
        supervisorTrabajadorId: _supervisorTrabajadorId,
        fotos: fotoUrl != null ? [fotoUrl] : [],
        usuarioReportanteId: _client.auth.currentUser?.id,
      );

      // 3. Insertar en base de datos
      await _client
          .from(SupabaseConfig.tableIncidentes)
          .insert(incidente.toJson());

      // 4. Limpiar formulario
      resetForm();
      return true;
    } catch (e) {
      _errorMessage = 'Error al enviar solicitud: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void resetForm() {
    _descripcion = '';
    _tipoIncidente = null;
    _area = null;
    _supervisorTrabajadorId = null;
    _supervisorNombre = null;
    _fotoEvidencia = null;
    _fotoEvidenciaUrl = null;
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }
}