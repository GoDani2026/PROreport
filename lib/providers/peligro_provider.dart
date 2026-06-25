// ================================================================
// PROreport - PeligroProvider
// ----------------------------------------------------------------
// ChangeNotifier que maneja el estado del formulario de creación
// y el flujo de seguimiento/cierre de detecciones de peligro.
// ================================================================

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/deteccion_peligro_model.dart';
import '../services/peligros_service.dart';

class PeligroProvider extends ChangeNotifier {
  final PeligrosService _service;

  PeligroProvider(PeligrosService service) : _service = service;

  // ═══════════════════════════════════════════════════════════════
  // ESTADO - Catálogos
  // ═══════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> get areas => _areas;

  List<Map<String, dynamic>> _supervisores = [];
  List<Map<String, dynamic>> get supervisores => _supervisores;

  List<DeteccionPeligro> _detecciones = [];
  List<DeteccionPeligro> get detecciones => _detecciones;

  bool _isLoadingCatalogos = false;
  bool get isLoadingCatalogos => _isLoadingCatalogos;

  // ═══════════════════════════════════════════════════════════════
  // ESTADO - Formulario de Creación
  // ═══════════════════════════════════════════════════════════════

  int? _selectedAreaId;
  int? get selectedAreaId => _selectedAreaId;

  String _lugarExacto = '';
  String get lugarExacto => _lugarExacto;

  XFile? _fotoEvidencia;
  XFile? get fotoEvidencia => _fotoEvidencia;

  String? _fotoEvidenciaUrl;
  String? get fotoEvidenciaUrl => _fotoEvidenciaUrl;

  String? _nivelAtencionLgf;
  String? get nivelAtencionLgf => _nivelAtencionLgf;

  String _descripcionHallazgo = '';
  String get descripcionHallazgo => _descripcionHallazgo;

  String _accionInmediata = '';
  String get accionInmediata => _accionInmediata;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ═══════════════════════════════════════════════════════════════
  // ESTADO - Flujo de Seguimiento/Cierre
  // ═══════════════════════════════════════════════════════════════

  DeteccionPeligro? _deteccionActual;
  DeteccionPeligro? get deteccionActual => _deteccionActual;

  bool _isLoadingDeteccion = false;
  bool get isLoadingDeteccion => _isLoadingDeteccion;

  // ═══════════════════════════════════════════════════════════════
  // MÉTODOS - Carga de Catálogos
  // ═══════════════════════════════════════════════════════════════

  Future<void> loadCatalogos() async {
    _isLoadingCatalogos = true;
    notifyListeners();

    try {
      _areas = await _service.fetchAreas();
      _supervisores = await _service.fetchSupervisores();
    } catch (e) {
      _errorMessage = 'Error al cargar catálogos: $e';
    }

    _isLoadingCatalogos = false;
    notifyListeners();
  }

  Future<void> loadDetecciones() async {
    try {
      _detecciones = await _service.fetchAll();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cargar detecciones: $e';
      notifyListeners();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTODOS - Formulario de Creación
  // ═══════════════════════════════════════════════════════════════

  void setAreaId(int? id) {
    _selectedAreaId = id;
    notifyListeners();
  }

  void setLugarExacto(String value) {
    _lugarExacto = value;
  }

  void setNivelAtencion(String? nivel) {
    _nivelAtencionLgf = nivel;
    notifyListeners();
  }

  void setDescripcion(String value) {
    _descripcionHallazgo = value;
  }

  void setAccionInmediata(String value) {
    _accionInmediata = value;
  }

  /// Captura o selecciona una foto de evidencia usando ImagePicker.
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

  /// Limpia la foto de evidencia seleccionada.
  void clearFotoEvidencia() {
    _fotoEvidencia = null;
    _fotoEvidenciaUrl = null;
    notifyListeners();
  }

  /// Valida que los campos obligatorios del formulario estén completos.
  String? validateForm() {
    if (_selectedAreaId == null) return 'Debe seleccionar un área.';
    if (_lugarExacto.trim().isEmpty) return 'Debe indicar el lugar exacto.';
    if (_nivelAtencionLgf == null) {
      return 'Debe seleccionar el nivel de atención LGF.';
    }
    if (_fotoEvidencia == null && _fotoEvidenciaUrl == null) {
      return 'Debe capturar una foto de evidencia.';
    }
    return null;
  }

  /// Envía el reporte de detección de peligro.
  Future<bool> submitReport(String usuarioReportanteId, String turno) async {
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
      // 1. Subir foto de evidencia si existe
      String? fotoUrl = _fotoEvidenciaUrl;
      if (_fotoEvidencia != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = _fotoEvidencia!.name.split('.').last;
        final bucketPath =
            'detecciones_peligro/evidencia/${usuarioReportanteId}_$timestamp.$extension';
        fotoUrl = await _service.uploadFoto(
          filePath: _fotoEvidencia!.path,
          bucketPath: bucketPath,
        );
      }

      // 2. Crear modelo de detección
      final deteccion = DeteccionPeligro(
        usuarioReportanteId: usuarioReportanteId,
        areaId: _selectedAreaId!,
        turno: turno,
        lugarExacto: _lugarExacto.trim(),
        fotoEvidenciaUrl: fotoUrl,
        descripcionHallazgo: _descripcionHallazgo.trim().isEmpty
            ? null
            : _descripcionHallazgo.trim(),
        nivelAtencionLgf: _nivelAtencionLgf!,
        accionInmediata: _accionInmediata.trim().isEmpty
            ? null
            : _accionInmediata.trim(),
      );

      // 3. Insertar en base de datos
      await _service.insertDeteccion(deteccion);

      // 4. Limpiar formulario
      resetForm();
      return true;
    } catch (e) {
      _errorMessage = 'Error al enviar reporte: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Resetea el formulario de creación.
  void resetForm() {
    _selectedAreaId = null;
    _lugarExacto = '';
    _fotoEvidencia = null;
    _fotoEvidenciaUrl = null;
    _nivelAtencionLgf = null;
    _descripcionHallazgo = '';
    _accionInmediata = '';
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════
  // MÉTODOS - Flujo de Seguimiento/Cierre
  // ═══════════════════════════════════════════════════════════════

  /// Carga una detección específica por ID para vista de detalle.
  Future<void> loadDeteccion(int id) async {
    _isLoadingDeteccion = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _deteccionActual = await _service.fetchById(id);
    } catch (e) {
      _errorMessage = 'Error al cargar detección: $e';
    }

    _isLoadingDeteccion = false;
    notifyListeners();
  }

  /// RPC 1: Inicia la ejecución del plan para eliminar el peligro.
  Future<bool> iniciarEjecucion({
    required int deteccionId,
    required int supervisorId,
    required String planAccion,
    required DateTime fechaCompromiso,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.callIniciarEjecucion(
        deteccionId: deteccionId,
        supervisorId: supervisorId,
        planAccion: planAccion,
        fechaCompromiso: fechaCompromiso,
      );

      // Recargar la detección para reflejar cambios
      await loadDeteccion(deteccionId);
      return true;
    } catch (e) {
      _errorMessage = 'Error al iniciar ejecución: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// RPC 2: Cierra el caso de peligro.
  Future<bool> cerrarCaso({
    required int deteccionId,
    required String resumenCierre,
    String? fotoCierrePath,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Subir foto de cierre si existe
      String? fotoCierreUrl;
      if (fotoCierrePath != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = fotoCierrePath.split('.').last;
        final bucketPath =
            'detecciones_peligro/cierre/${deteccionId}_$timestamp.$extension';
        fotoCierreUrl = await _service.uploadFoto(
          filePath: fotoCierrePath,
          bucketPath: bucketPath,
        );
      }

      await _service.callCerrarPeligro(
        deteccionId: deteccionId,
        resumenCierre: resumenCierre,
        fotoCierreUrl: fotoCierreUrl,
      );

      // Recargar la detección para reflejar cambios
      await loadDeteccion(deteccionId);
      return true;
    } catch (e) {
      _errorMessage = 'Error al cerrar caso: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Limpia el mensaje de error.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpia la detección actual de la vista de detalle.
  void clearDeteccionActual() {
    _deteccionActual = null;
    notifyListeners();
  }
}