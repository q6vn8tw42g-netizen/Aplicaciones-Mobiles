import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/espacio.dart';

class MapaEspacios extends StatelessWidget {
  final List<Espacio> espacios;

  const MapaEspacios({
    super.key,
    required this.espacios,
  });

  @override
  Widget build(BuildContext context) {
    final espaciosConUbicacion = espacios.where(
      (espacio) {
        return espacio.latitud != null &&
            espacio.longitud != null;
      },
    ).toList();

    const centroTulcan = ll.LatLng(
      0.8150,
      -77.7150,
    );

    return ClipRect(
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: centroTulcan,
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:
                'com.example.estacionaya',
          ),
          MarkerLayer(
            markers: espaciosConUbicacion.map(
              (espacio) {
                final visual = _obtenerVisual(
                  espacio.estado,
                );

                return Marker(
                  point: ll.LatLng(
                    espacio.latitud!,
                    espacio.longitud!,
                  ),
                  width: 48,
                  height: 48,
                  child: Tooltip(
                    message:
                        '${espacio.nombre}\n${visual.texto}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: visual.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        visual.icono,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  _VisualMarcador _obtenerVisual(
    String estado,
  ) {
    switch (estado) {
      case 'LIBRE':
        return const _VisualMarcador(
          texto: 'Libre',
          color: Colors.green,
          icono: Icons.local_parking,
        );

      case 'OCUPADO':
        return const _VisualMarcador(
          texto: 'Ocupado',
          color: Colors.red,
          icono: Icons.local_parking,
        );

      case 'RESERVADO':
        return const _VisualMarcador(
          texto: 'Reservado',
          color: Colors.amber,
          icono: Icons.schedule,
        );

      case 'SIN_SERVICIO':
        return const _VisualMarcador(
          texto: 'Sin servicio',
          color: Colors.grey,
          icono: Icons.warning_amber,
        );

      default:
        return const _VisualMarcador(
          texto: 'Estado desconocido',
          color: Colors.grey,
          icono: Icons.help_outline,
        );
    }
  }
}

class _VisualMarcador {
  final String texto;
  final Color color;
  final IconData icono;

  const _VisualMarcador({
    required this.texto,
    required this.color,
    required this.icono,
  });
}