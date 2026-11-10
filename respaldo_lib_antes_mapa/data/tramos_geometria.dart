import 'package:latlong2/latlong.dart' as ll;

/// Geometrías verificadas de tramos de zona azul.
/// No añadir coordenadas estimadas: se deben obtener de cartografía municipal
/// o levantamientos GPS y confirmar que la regulación siga vigente.
class TramoGeo {
  final String id;
  final String localidad; // 'Tulcán' o 'Montúfar'
  final String calle;
  final List<ll.LatLng> puntos;
  const TramoGeo({
    required this.id,
    required this.localidad,
    required this.calle,
    required this.puntos,
  });
}

abstract final class GeometriasZonaAzul {
  // Agregar aquí tramos confirmados con al menos dos puntos por segmento.
  // El mapa los dibujará automáticamente en azul.
  static const tramos = <TramoGeo>[];
}
