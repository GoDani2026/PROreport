import 'dart:typed_data';
import 'dart:html' show AnchorElement, Blob, Url;

/// Descarga un archivo en el navegador usando Blob + AnchorElement
void descargarArchivo(Uint8List bytes, String fileName) {
  final blob = Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = Url.createObjectUrl(blob);
  final anchor = AnchorElement(href: url)
    ..target = 'blank'
    ..download = fileName;
  anchor.click();
  Url.revokeObjectUrl(url);
}