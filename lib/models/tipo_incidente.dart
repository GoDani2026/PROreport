class TipoIncidente {
  final int id;
  final String nombre;

  TipoIncidente({
    required this.id,
    required this.nombre,
  });

  factory TipoIncidente.fromJson(Map<String, dynamic> json) {
    return TipoIncidente(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
    };
  }

  @override
  String toString() => nombre;
}
