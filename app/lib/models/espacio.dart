class Espacio {
  final String id;
  final String nombre;
  final String camaraId;
  final String estado; // LIBRE | OCUPADO | RESERVADO | SIN_SERVICIO
  final double? latitud;
  final double? longitud;
  final DateTime actualizadoEn;

  Espacio({
    required this.id,
    required this.nombre,
    required this.camaraId,
    required this.estado,
    required this.actualizadoEn,
    this.latitud,
    this.longitud,
  });

  factory Espacio.fromMap(Map<String, dynamic> map) {
    return Espacio(
      id: map['id'] as String,
      nombre: map['codigo'] as String,
      camaraId: map['camara_id'] as String,
      estado: map['estado'] as String,
      actualizadoEn: DateTime.parse(map['updated_at'] as String),
      latitud: (map['lat'] as num?)?.toDouble(),
      longitud: (map['lng'] as num?)?.toDouble(),
    );
  }

  Espacio copyWith({String? estado, DateTime? actualizadoEn}) {
    return Espacio(
      id: id,
      nombre: nombre,
      camaraId: camaraId,
      estado: estado ?? this.estado,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      latitud: latitud,
      longitud: longitud,
    );
  }
}
