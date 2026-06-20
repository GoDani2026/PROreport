import 'dart:typed_data';

/// Stub para plataformas no-web
void descargarArchivo(Uint8List bytes, String fileName) {
  throw UnsupportedError('Descarga directa no disponible en esta plataforma');
}