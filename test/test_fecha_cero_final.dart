// Test exacto de Validators.parsearFechaCsv con la versión actualizada
class Validators {
  static String parsearFechaCsv(String raw) {
    final v = raw.trim();
    if (v.isEmpty || v == 'N/A' || v == 'n/a') return '';
    try {
      // Si ya viene en formato ISO (yyyy-MM-dd), validar mes y día
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
        final partesIso = v.split('-');
        if (partesIso.length == 3) {
          final mes = int.parse(partesIso[1]);
          final dia = int.parse(partesIso[2]);
          if (mes < 1 || mes > 12) return '';
          if (dia < 1 || dia > 31) return '';
        }
        return v;
      }

      List<String> partes;
      if (v.contains('/')) {
        partes = v.split('/');
      } else if (v.contains('-')) {
        partes = v.split('-');
      } else {
        return '';
      }
      if (partes.length == 3) {
        final p1 = int.parse(partes[0]);
        final p2 = int.parse(partes[1]);
        final anio = int.parse(partes[2]);
        if (anio > 1900 && anio < 2100) {
          int mes, dia;
          if (p1 > 12) {
            dia = p1;
            mes = p2;
          } else {
            mes = p1;
            dia = p2;
          }
          if (mes < 1 || mes > 12) return '';
          if (dia < 1 || dia > 31) return '';
          return '$anio-${mes.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}';
        }
      }
    } catch (_) {}
    return '';
  }
}

void main() {
  // print("=== Test fecha con ceros y valores inválidos (Validators REAL) ===\n");
  final casos = [
    "0-01-2027",      // mes 0 → inválido
    "00-01-2027",     // mes 0 → inválido
    "0/01/2027",      // mes 0 → inválido
    "2027-00-01",     // ISO con mes 00 → inválido (validación nueva)
    "32/01/2027",     // día 32 → inválido
    "01/32/2027",     // día 32 → inválido
    "13/01/2027",     // día 13 mes 1 → válido
    "01/01/2027",     // válido
    "15/07/2024",     // válido (dd/MM)
    "07/15/2024",     // válido (MM/dd)
    "30/06/2026",     // válido
    "2026-06-30",     // ISO válido
    "2024-02-30",     // ISO día 30 en febrero → pasa (validación simple)
    "N/A",            // N/A
    "SI",             // SI
    "Permanencia definitiva", // texto libre
  ];
  for (final caso in casos) {
    final parsed = Validators.parsearFechaCsv(caso);
    final esISO = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(parsed); // ignore: unused_local_variable

    // Lógica exacta de carga_masiva_screen.dart
    if (caso.isNotEmpty) {
      final pareceFecha = RegExp(r'\d').hasMatch(caso) && (caso.contains('/') || caso.contains('-'));
      if (pareceFecha) {
        final rawUpper = caso.toUpperCase().trim(); // ignore: unused_local_variable
        // errorFecha = !(esISO && DateTime.tryParse(parsed) != null) && !(rawUpper == 'N/A' || rawUpper == 'NA')
      }
    }

    // print('INPUT: "$caso"');
    // print('  → PARSE: "$parsed"');
    // if (esISO) {
    //   print('  → ERROR: $errorFecha  ✓ DETECTADA' );
    // } else if (parsed.isEmpty && caso.isNotEmpty) {
    //   print('  → ERROR: $errorFecha  ✓ RECHAZADA' );
    // } else {
    //   print('  → ERROR: $errorFecha' );
    // }
    // print('');
  }
}