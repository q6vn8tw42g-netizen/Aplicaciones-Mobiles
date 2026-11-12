class Espacio {
  final String id;
  final String nombre;
  final String camaraId;
  final String estado; // LIBRE | OCUPADO | RESERVADO | SIN_SERVICIO
  final double? latitud;
  final double? longitud;
  final String tipoVehiculo; // MOTO | AUTO | CAMIONETA | MIXTO
  final String? vehiculoDetectado;
  final DateTime? expiracionReserva;
  final DateTime actualizadoEn;
  final bool visionEnLinea;

  Espacio({
    required this.id,
    required this.nombre,
    required this.camaraId,
    required this.estado,
    required this.actualizadoEn,
    this.visionEnLinea = true,
    this.latitud,
    this.longitud,
    this.tipoVehiculo = 'MIXTO',
    this.vehiculoDetectado,
    this.expiracionReserva,
  });

  factory Espacio.fromMap(Map<String, dynamic> map) {
    return Espacio(
      id: map['id'].toString(),
      nombre:
          (map['codigo'] ?? map['nombre'] ?? 'Espacio sin nombre').toString(),
      camaraId: map['camara_id'] as String,
      estado: (map['estado'] ?? map['estado_reserva'] ?? 'SIN_SERVICIO').toString(),
      actualizadoEn: DateTime.parse(
        (map['updated_at'] ?? map['actualizado_en']).toString(),
      ),
      latitud: ((map['lat'] ?? map['latitud']) as num?)?.toDouble(),
      longitud: ((map['lng'] ?? map['longitud']) as num?)?.toDouble(),
      tipoVehiculo: (map['tipo_vehiculo'] ?? 'MIXTO').toString(),
      vehiculoDetectado: map['vehiculo_detectado']?.toString(),
      expiracionReserva: map['expiracion_reserva'] == null
          ? null
          : DateTime.tryParse(map['expiracion_reserva'].toString()),
    );
  }

  Espacio copyWith({
    String? estado,
    DateTime? actualizadoEn,
    bool? visionEnLinea,
    String? vehiculoDetectado,
    DateTime? expiracionReserva,
    bool limpiarExpiracionReserva = false,
  }) {
    return Espacio(
      id: id,
      nombre: nombre,
      camaraId: camaraId,
      estado: estado ?? this.estado,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      visionEnLinea: visionEnLinea ?? this.visionEnLinea,
      latitud: latitud,
      longitud: longitud,
      tipoVehiculo: tipoVehiculo,
      vehiculoDetectado: vehiculoDetectado ?? this.vehiculoDetectado,
      expiracionReserva: limpiarExpiracionReserva
          ? null
          : expiracionReserva ?? this.expiracionReserva,
    );
  }
}
