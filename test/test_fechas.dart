// Test de Validators.parsearFechaCsv
class Validators {
  static String parsearFechaCsv(String raw) {
    final v = raw.trim();
    if (v.isEmpty || v == "N/A" || v == "n/a") return "";
    try {
      if (RegExp(r"^\d{4}-\d{2}-\d{2}$").hasMatch(v)) return v;
      List<String> partes;
      if (v.contains("/")) {
        partes = v.split("/");
      } else if (v.contains("-")) {
        partes = v.split("-");
      } else {
        return "";
      }
      if (partes.length == 3) {
        final p1 = int.parse(partes[0]);
        final p2 = int.parse(partes[1]);
        final anio = int.parse(partes[2]);
        if (anio > 1900 && anio < 2100) {
          if (p1 > 12) {
            return "$anio-${p2.toString().padLeft(2, "0")}-${p1.toString().padLeft(2, "0")}";
          } else {
            return "$anio-${p1.toString().padLeft(2, "0")}-${p2.toString().padLeft(2, "0")}";
          }
        }
      }
    } catch (_) {}
    return "";
  }

  static String estadoDesdeFecha(String fechaStr) {
    if (fechaStr.isEmpty) return "N/A";
    try {
      final fecha = DateTime.parse(fechaStr);
      return fecha.isAfter(DateTime.now()) ? "VIGENTE" : "VENCIDO";
    } catch (_) {
      return "N/A";
    }
  }
}

void main() {
  // Test 1: parseo de fechas
  final casos = <String>[
    "30/06/2026",
    "06/30/2026",
    "2026-06-30",
    "15/07/2024",
    "N/A",
    "n/a",
    "SI",
    "",
    "Permanencia definitiva",
    "01-01-2025",
    "0",
    "45500",
    "13/13/2026",
    "abc",
  ];

  for (final caso in casos) {
    Validators.parsearFechaCsv(caso);
  }

  // Test 2: N/A en requisitos
  final casosReq = <String>[
    "N/A", "NA", "NO APLICA", "no aplica", "SI", "SÍ", "VENCIDO",
  ];
  for (final caso in casosReq) {
    caso.toUpperCase().trim();
  }

  // Test 3: Venc.Residencia (TEXT)
  final casosRes = <String>[
    "Permanencia definitiva", "PERMANENTE", "30/06/2026",
    "2026-06-30", "", "N/A", "NA",
  ];
  for (final caso in casosRes) {
    String formateada = caso.trim();
    if (formateada.isNotEmpty) {
      final parsed = Validators.parsearFechaCsv(formateada);
      if (parsed.isNotEmpty && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(parsed)) {
        formateada = parsed;
      } else if (formateada.toUpperCase() == 'N/A' || formateada.toUpperCase() == 'NA') {
        formateada = '';
      }
    }
  }
}