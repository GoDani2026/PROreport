class Perfil {
  final String id;
  final String nombreCompleto;
  final String rol;
  final String? avatarUrl;

  Perfil({
    required this.id,
    required this.nombreCompleto,
    required this.rol,
    this.avatarUrl,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      id: json['id'] as String,
      nombreCompleto: json['nombre_completo'] as String? ?? '',
      rol: json['rol'] as String? ?? 'colaborador',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre_completo': nombreCompleto,
      'rol': rol,
      'avatar_url': avatarUrl,
    };
  }

  @override
  String toString() => nombreCompleto;
}
