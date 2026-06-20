import 'dart:io';
import 'dart:typed_data';
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
