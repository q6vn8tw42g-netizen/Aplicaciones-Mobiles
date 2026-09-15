import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/espacio.dart';

class MapaEspacios extends StatelessWidget {
  final List<Espacio> espacios;

  const MapaEspacios({super.key, required this.espacios});

  @override
  Widget build(BuildContext context) {
    final conUbicacion = espacios
        .where((e) => e.latitud != null && e.longitud != null)
        .toList();

    // Tulcán, Ecuador como respaldo si aún no hay espacios cargados.
    final centro = conUbicacion.isNotEmpty
        ? ll.LatLng(conUbicacion.first.latitud!, conUbicacion.first.longitud!)
        : const ll.LatLng(0.812, -77.712);

    return FlutterMap(
      options: MapOptions(initialCenter: centro, initialZoom: 17),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.estacionaya.app',
        ),
        MarkerLayer(
          markers: conUbicacion.map((espacio) {
            final color = espacio.estado == 'LIBRE' ? Colors.green : Colors.red;
            return Marker(
              point: ll.LatLng(espacio.latitud!, espacio.longitud!),
              width: 36,
              height: 36,
              child: Icon(Icons.local_parking, color: color, size: 32),
            );
          }).toList(),
        ),
      ],
    );
  }
}
