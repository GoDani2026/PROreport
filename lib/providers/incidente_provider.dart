import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/solicitud_levantamiento_model.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../config/supabase_config.dart';

class IncidenteProvider extends ChangeNotifier {
  final SupabaseClient _client;
  late final SupabaseService _supabaseService;
  late final StorageService _storageService;

  IncidenteProvider(this._client) {
    _supabaseService = SupabaseService(_client);
    _storageService = StorageService(_client);
  }

  // --- Estado del formulario ---
  String _descripcion = '';
  List<XFile> _selectedImages = [];
  List<Uint8List> _webImagesBytes = [];
  TipoIncidente? _tipoIncidente;
  Area? _area;
  Perfil? _supervisor;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // --- Datos de catálogos ---
  List<TipoIncidente> _tiposIncidente = [];
  List<Area> _areas = [];
  List<Perfil> _supervisores = [];

  // --- Getters ---
  String get descripcion => _descripcion;
  List<XFile> get selectedImages => _selectedImages;
  List<Uint8List> get webImagesBytes => _webImagesBytes;
  TipoIncidente? get tipoIncidente => _tipoIncidente;
  Area? get area => _area;
  Perfil? get supervisor => _supervisor;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<TipoIncidente> get tiposIncidente => _tiposIncidente;
  List<Area> get areas => _areas;
  List<Perfil> get supervisores => _supervisores;
  int get imageCount => _selectedImages.length + _webImagesBytes.length;

  // --- Inicialización ---
  Future<void> loadCatalogos() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _supabaseService.getTiposIncidente(),
        _supabaseService.getAreas(),
        _supabaseService.getSupervisores(),
      ]);

      _tiposIncidente = results[0] as List<TipoIncidente>;
      _areas = results[1] as List<Area>;
      _supervisores = results[2] as List<Perfil>;

      // Si Supabase devuelve listas vacías, usamos datos de ejemplo
      if (_tiposIncidente.isEmpty) {
        _tiposIncidente = [
          TipoIncidente(id: 1, nombre: 'Acto Inseguro'),
          TipoIncidente(id: 2, nombre: 'Condición Insegura'),
          TipoIncidente(id: 3, nombre: 'Casi Accidente'),
        ];
      }
      if (_areas.isEmpty) {
        _areas = [
          Area(id: 1, nombre: 'Mina - Tajo Abierto'),
          Area(id: 2, nombre: 'Planta de Procesos'),
          Area(id: 3, nombre: 'Mantenimiento'),
          Area(id: 4, nombre: 'Oficinas Administrativas'),
        ];
      }
      if (_supervisores.isEmpty) {
        _supervisores = [
          Perfil(id: '1', nombreCompleto: 'Maron Batom', rol: 'supervisor'),
          Perfil(id: '2', nombreCompleto: 'Ana García', rol: 'supervisor'),
          Perfil(id: '3', nombreCompleto: 'Carlos López', rol: 'supervisor'),
        ];
      }
    } catch (e) {
      _errorMessage = 'Error al cargar datos: ${e.toString()}';
      // Datos de ejemplo para desarrollo sin Supabase
      _tiposIncidente = [
        TipoIncidente(id: 1, nombre: 'Acto Inseguro'),
        TipoIncidente(id: 2, nombre: 'Condición Insegura'),
        TipoIncidente(id: 3, nombre: 'Casi Accidente'),
      ];
      _areas = [
        Area(id: 1, nombre: 'Mina - Tajo Abierto'),
        Area(id: 2, nombre: 'Planta de Procesos'),
        Area(id: 3, nombre: 'Mantenimiento'),
        Area(id: 4, nombre: 'Oficinas Administrativas'),
      ];
      _supervisores = [
        Perfil(
            id: '1',
            nombreCompleto: 'Maron Batom',
            rol: 'supervisor'),
        Perfil(
            id: '2',
            nombreCompleto: 'Korina Santos',
            rol: 'supervisor'),
        Perfil(
            id: '3',
            nombreCompleto: 'Carlos Matamba',
            rol: 'supervisor'),
      ];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Métodos del formulario ---
  void setDescripcion(String value) {
    _descripcion = value;
    notifyListeners();
  }

  void setTipoIncidente(TipoIncidente? tipo) {
    _tipoIncidente = tipo;
    notifyListeners();
  }

  void setArea(Area? area) {
    _area = area;
    notifyListeners();
  }

  void setSupervisor(Perfil? supervisor) {
    _supervisor = supervisor;
    notifyListeners();
  }

  // --- Métodos de imágenes (Móvil) ---
  Future<void> pickImagesFromGallery() async {
    final picker = ImagePicker();
    final maxImages = 5;
    final currentCount = imageCount;
    final remaining = maxImages - currentCount;

    if (remaining <= 0) {
      _errorMessage = 'Máximo 5 archivos permitidos';
      notifyListeners();
      return;
    }

    try {
      final images = await picker.pickMultiImage(
        imageQuality: 70,
        limit: remaining,
      );

      if (images.isNotEmpty) {
        _selectedImages.addAll(images);
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al seleccionar imágenes';
      notifyListeners();
    }
  }

  Future<void> pickImageFromCamera() async {
    final picker = ImagePicker();
    final maxImages = 5;
    final currentCount = imageCount;

    if (currentCount >= maxImages) {
      _errorMessage = 'Máximo 5 archivos permitidos';
      notifyListeners();
      return;
    }

    try {
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image != null) {
        _selectedImages.add(image);
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al tomar foto';
      notifyListeners();
    }
  }

  // --- Métodos de imágenes (Web) ---
  Future<void> pickFilesForWeb() async {
    final maxImages = 5;
    final currentCount = imageCount;
    final remaining = maxImages - currentCount;

    if (remaining <= 0) {
      _errorMessage = 'Máximo 5 archivos permitidos';
      notifyListeners();
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files.take(remaining)) {
          if (file.bytes != null) {
            _webImagesBytes.add(file.bytes!);
          }
        }
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Error al seleccionar archivos';
      notifyListeners();
    }
  }

  // --- Eliminar imagen ---
  void removeImage(int index) {
    if (index < _selectedImages.length) {
      _selectedImages.removeAt(index);
    } else {
      final webIndex = index - _selectedImages.length;
      if (webIndex < _webImagesBytes.length) {
        _webImagesBytes.removeAt(webIndex);
      }
    }
    notifyListeners();
  }

  // --- Enviar formulario ---
  Future<bool> submitReport() async {
    // Validación
    if (_descripcion.trim().isEmpty) {
      _errorMessage = 'La descripción es requerida';
      notifyListeners();
      return false;
    }
    if (_tipoIncidente == null) {
      _errorMessage = 'Debe seleccionar un tipo de incidente';
      notifyListeners();
      return false;
    }
    if (_area == null) {
      _errorMessage = 'Debe seleccionar un área';
      notifyListeners();
      return false;
    }
    if (_supervisor == null) {
      _errorMessage = 'Debe seleccionar un supervisor';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Subir imágenes
      List<String> fotosUrls = [];

      try {
        // Subir imágenes de móvil
        if (_selectedImages.isNotEmpty) {
          for (final image in _selectedImages) {
            final fileName =
                '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
            final url = await _storageService
                .uploadImage(image.path, fileName);
            fotosUrls.add(url);
          }
        }

        // Subir imágenes de web
        if (_webImagesBytes.isNotEmpty) {
          for (final bytes in _webImagesBytes) {
            final fileName =
                '${DateTime.now().millisecondsSinceEpoch}_web.jpg';
            final url = await _storageService
                .uploadImageFromBytes(bytes, fileName);
            fotosUrls.add(url);
          }
        }
      } catch (e) {
        // Si falla la subida de imágenes, continuamos sin ellas
        // En producción podrías manejar esto diferente
      }

      // El supervisor seleccionado es un trabajador (id integer), no un usuario UUID
      final supervisorTrabajadorId = int.tryParse(_supervisor!.id);

      // Crear registro del incidente (alineado con nuevo esquema)
      final incidente = Incidente(
        titulo: '${_tipoIncidente!.nombre} - ${_area!.nombre}',
        descripcion: _descripcion.trim(),
        tipoIncidenteId: _tipoIncidente!.id,
        areaId: _area!.id,
        supervisorTrabajadorId: supervisorTrabajadorId,
        fotos: fotosUrls,
        usuarioReportanteId: _client.auth.currentUser?.id,
      );

      await _client
          .from(SupabaseConfig.tableIncidentes)
          .insert(incidente.toJson());

      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al enviar reporte: ${e.toString()}';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  // --- Resetear formulario ---
  void resetForm() {
    _descripcion = '';
    _selectedImages = [];
    _webImagesBytes = [];
    _tipoIncidente = null;
    _area = null;
    _supervisor = null;
    _errorMessage = null;
    notifyListeners();
  }
}
