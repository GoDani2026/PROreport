import 'dart:typed_data';

/// Stub para plataformas que no sean web (Android, iOS, etc.)
void descargarArchivoWeb(Uint8List bytes, String fileName) {
  throw UnsupportedError('La descarga web solo está disponible en navegadores');
}