class Parqueadero {
  // 1. Atributos base
  final String id;
  final String direccion;
  final double latitud;
  final double longitud;
  
  // 2. Encapsulamiento: variable privada para proteger el estado del sensor/cámara
  bool _estaOcupado; 

  // 3. Constructor principal
  Parqueadero({
    required this.id,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    bool ocupado = false,
  }) : _estaOcupado = ocupado;

  // 4. Getter para acceder al estado de forma segura
  bool get estaOcupado => _estaOcupado;

  // 5. Setter controlado para cuando OpenCV / la API detecte un cambio de vehículo
  void actualizarEstado(bool nuevoEstado) {
    _estaOcupado = nuevoEstado;
  }

  // 6. Factory Constructor: Prepara el molde para convertir los datos JSON de tu Supabase en objetos Dart
  factory Parqueadero.fromJson(Map<String, dynamic> json) {
    return Parqueadero(
      id: json['id'].toString(),
      direccion: json['direccion'] ?? 'Ubicación desconocida',
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      ocupado: json['is_occupied'] ?? false,
    );
  }
}