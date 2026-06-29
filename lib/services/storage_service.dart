import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  /// Sube un archivo de imagen al bucket de Supabase y retorna la URL pública
  Future<String> uploadImage(String filePath, String fileName) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    await _client.storage
        .from(SupabaseConfig.storageBucket)
        .uploadBinary(
          'incidentes/$fileName',
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    // Obtener URL pública
    final publicUrl = _client.storage
        .from(SupabaseConfig.storageBucket)
        .getPublicUrl('incidentes/$fileName');

    return publicUrl;
  }

  /// Sube múltiples imágenes y retorna una lista de URLs públicas
  Future<List<String>> uploadMultipleImages(
      List<String> filePaths) async {
    final List<String> urls = [];

    for (int i = 0; i < filePaths.length; i++) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final url = await uploadImage(filePaths[i], fileName);
      urls.add(url);
    }

    return urls;
  }

  /// Sube un archivo desde bytes (útil para web)
  Future<String> uploadImageFromBytes(
      Uint8List bytes, String fileName) async {
    await _client.storage
        .from(SupabaseConfig.storageBucket)
        .uploadBinary(
          'incidentes/$fileName',
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final publicUrl = _client.storage
        .from(SupabaseConfig.storageBucket)
        .getPublicUrl('incidentes/$fileName');

    return publicUrl;
  }

  /// Sube una foto de evidencia al bucket 'evidencias' dentro de una subcarpeta por módulo.
  /// [folderName] es el nombre del módulo (ej: 'gestion_personal', 'inspecciones', etc.)
  /// Acepta XFile (compatible con web y móvil) o bytes directamente.
  Future<String> uploadEvidencia(XFile imageFile, String folderName) async {
    try {
      final fileExtension = imageFile.name.split('.').last.toLowerCase();
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$userId.$fileExtension';
      final filePath = '$folderName/$fileName';

      // Determinar contentType según la extensión real del archivo
      final contentType = _getContentType(fileExtension);

      await _client.storage
          .from('evidencias')
          .uploadBinary(
            filePath,
            await imageFile.readAsBytes(),
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      return _client.storage.from('evidencias').getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Error al subir evidencia a "$folderName": $e');
    }
  }

  /// Retorna el MIME type según la extensión del archivo
  String _getContentType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }

  /// Sube múltiples imágenes desde bytes (útil para web)
  Future<List<String>> uploadMultipleImagesFromBytes(
      List<Uint8List> imageBytesList) async {
    final List<String> urls = [];

    for (int i = 0; i < imageBytesList.length; i++) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final url =
          await uploadImageFromBytes(imageBytesList[i], fileName);
      urls.add(url);
    }

    return urls;
  }
}
