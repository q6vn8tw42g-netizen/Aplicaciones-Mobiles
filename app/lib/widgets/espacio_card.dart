import 'package:flutter/material.dart';

import '../models/espacio.dart';

class EspacioCard extends StatelessWidget {
  final Espacio espacio;
  final void Function(String tipo) onReportar;

  const EspacioCard({
    super.key,
    required this.espacio,
    required this.onReportar,
  });

  @override
  Widget build(BuildContext context) {
    final esLibre = espacio.estado == 'LIBRE';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    espacio.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Chip(
                    label: Text(esLibre ? 'Libre' : 'Ocupado'),
                    backgroundColor:
                        esLibre ? Colors.green.shade100 : Colors.red.shade100,
                    labelStyle: TextStyle(
                      color: esLibre ? Colors.green.shade800 : Colors.red.shade800,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Me estacioné aquí',
              icon: const Icon(Icons.local_parking),
              onPressed: () => onReportar('ME_ESTACIONE'),
            ),
            IconButton(
              tooltip: 'Voy a salir',
              icon: const Icon(Icons.directions_car),
              onPressed: () => onReportar('VOY_A_SALIR'),
            ),
          ],
        ),
      ),
    );
  }
}
