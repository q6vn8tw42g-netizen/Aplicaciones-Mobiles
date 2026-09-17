import 'package:flutter/material.dart';

import '../models/espacio.dart';

class EspacioCard extends StatelessWidget {
  final Espacio espacio;
  final void Function(String tipo) onReportar;
  final VoidCallback? onNavegar;

  const EspacioCard({
    super.key,
    required this.espacio,
    required this.onReportar,
    this.onNavegar,
  });

  @override
  Widget build(BuildContext context) {
    final estadoVisual = _obtenerEstadoVisual(
      espacio.estado,
    );

    final puedeEstacionarse =
        espacio.estado == 'LIBRE';

    final puedeSalir =
        espacio.estado == 'OCUPADO';

    final puedeNavegar =
        espacio.latitud != null &&
        espacio.longitud != null &&
        onNavegar != null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              espacio.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(
                estadoVisual.icono,
                size: 16,
                color: estadoVisual.colorTexto,
              ),
              label: Text(
                estadoVisual.texto,
              ),
              backgroundColor:
                  estadoVisual.colorFondo,
              labelStyle: TextStyle(
                color: estadoVisual.colorTexto,
                fontSize: 12,
              ),
              visualDensity:
                  VisualDensity.compact,
              materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Abrir ruta',
                  icon: const Icon(
                    Icons.navigation,
                  ),
                  onPressed:
                      puedeNavegar ? onNavegar : null,
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: puedeEstacionarse
                      ? 'Me estacioné aquí'
                      : 'No disponible para estacionarse',
                  icon: const Icon(
                    Icons.local_parking,
                  ),
                  onPressed: puedeEstacionarse
                      ? () => onReportar(
                            'ME_ESTACIONE',
                          )
                      : null,
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: puedeSalir
                      ? 'Voy a salir'
                      : 'No existe una sesión activa',
                  icon: const Icon(
                    Icons.directions_car,
                  ),
                  onPressed: puedeSalir
                      ? () => onReportar(
                            'VOY_A_SALIR',
                          )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _EstadoVisual _obtenerEstadoVisual(
    String estado,
  ) {
    switch (estado) {
      case 'LIBRE':
        return _EstadoVisual(
          texto: 'Libre',
          colorFondo: Colors.green.shade100,
          colorTexto: Colors.green.shade800,
          icono: Icons.check_circle,
        );

      case 'OCUPADO':
        return _EstadoVisual(
          texto: 'Ocupado',
          colorFondo: Colors.red.shade100,
          colorTexto: Colors.red.shade800,
          icono: Icons.cancel,
        );

      case 'RESERVADO':
        return _EstadoVisual(
          texto: 'Reservado',
          colorFondo: Colors.amber.shade100,
          colorTexto: Colors.amber.shade900,
          icono: Icons.schedule,
        );

      case 'SIN_SERVICIO':
        return _EstadoVisual(
          texto: 'Sin servicio',
          colorFondo: Colors.grey.shade300,
          colorTexto: Colors.grey.shade800,
          icono: Icons.warning_amber,
        );

      default:
        return _EstadoVisual(
          texto: 'Desconocido',
          colorFondo: Colors.grey.shade300,
          colorTexto: Colors.grey.shade800,
          icono: Icons.help_outline,
        );
    }
  }
}

class _EstadoVisual {
  final String texto;
  final Color colorFondo;
  final Color colorTexto;
  final IconData icono;

  const _EstadoVisual({
    required this.texto,
    required this.colorFondo,
    required this.colorTexto,
    required this.icono,
  });
}