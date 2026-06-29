void main() {
  final casos = [
    "0-01-2027",
    "00-01-2027",
    "0/01/2027",
    "2027-00-01",
    "32/01/2027",
  ];

  for (final caso in casos) {
    final v = caso.trim();
    if (v.isNotEmpty) {
      final pareceFecha = RegExp(r'\d').hasMatch(v) && (v.contains('/') || v.contains('-'));
      if (pareceFecha) {
        final rawUpper = v.toUpperCase().trim();
        // Misma lógica de parsearFechaCsv
        String fechaStr = "";
        if (v.contains('/') || v.contains('-')) {
          try {
            List<String> partes;
            if (v.contains('/')) {
              partes = v.split('/');
            } else {
              partes = v.split('-');
            }
            if (partes.length == 3) {
              final p1 = int.parse(partes[0]);
              final p2 = int.parse(partes[1]);
              final anio = int.parse(partes[2]);
              if (anio > 1900 && anio < 2100) {
                if (p1 > 12) {
                  fechaStr = "$anio-${p2.toString().padLeft(2, '0')}-${p1.toString().padLeft(2, '0')}";
                } else {
                  fechaStr = "$anio-${p1.toString().padLeft(2, '0')}-${p2.toString().padLeft(2, '0')}";
                }
              }
            }
          } catch (_) {}
        }

        if (fechaStr.isNotEmpty &&
            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaStr) &&
            DateTime.tryParse(fechaStr) != null) {
          // fecha válida
        } else if (rawUpper == 'N/A' || rawUpper == 'NA') {
          // N/A
        }
        // else: errorFecha = true (intencionalmente no se usa la variable)
      }
    }
  }
}