import 'package:flutter/material.dart';

import '../models/espacio.dart';
import 'parking_status.dart';
import '../theme/estacionaya_theme.dart';

/// Read-only presentation of the heartbeat-derived flag from EspaciosProvider.
/// Other camera IDs default to true in Espacio and therefore cannot prove life.
class CameraConnectionBadge extends StatelessWidget {
  final String cameraId;
  final bool visionEnLinea;
  final bool cargando;
  final bool errorSincronizacion;

  const CameraConnectionBadge({
    super.key,
    required this.cameraId,
    required this.visionEnLinea,
    this.cargando = false,
    this.errorSincronizacion = false,
  });

  @override
  Widget build(BuildContext context) {
    final verificada =
        camaraVerificable(cameraId) && !cargando && !errorSincronizacion;
    final activa = verificada && visionEnLinea;
    final texto = activa
        ? 'Cámara activa'
        : verificada
            ? 'Sin señal vigente'
            : 'Conexión no verificada';
    final color =
        activa ? EstacionaYaTokens.available : EstacionaYaTokens.offline;
    return Tooltip(
      message: activa
          ? '$cameraId: señal de monitoreo reciente.'
          : 'No se dispone de una señal vigente verificable para $cameraId. '
              'La disponibilidad puede haber cambiado.',
      child: Semantics(
        label: '$cameraId. $texto',
        excludeSemantics: true,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          children: [
            Icon(activa ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                size: 15, color: color),
            Text(texto,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class CameraConnectionOverview extends StatelessWidget {
  final List<Espacio> espacios;
  final bool cargando;
  final bool errorSincronizacion;
  const CameraConnectionOverview(
      {super.key,
      required this.espacios,
      required this.cargando,
      required this.errorSincronizacion});

  @override
  Widget build(BuildContext context) {
    final camaras = <String, bool>{};
    for (final e in espacios) {
      camaras.update(e.camaraId, (actual) => actual && e.visionEnLinea,
          ifAbsent: () => e.visionEnLinea);
    }
    if (camaras.isEmpty) {
      return const CameraConnectionBadge(
          cameraId: '', visionEnLinea: false, cargando: true);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Señal de cámaras · esta vista',
          style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 6),
      Wrap(spacing: 16, runSpacing: 8, children: [
        for (final entry in camaras.entries)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.key, style: Theme.of(context).textTheme.bodySmall),
            CameraConnectionBadge(
                cameraId: entry.key,
                visionEnLinea: entry.value,
                cargando: cargando,
                errorSincronizacion: errorSincronizacion),
          ]),
      ]),
    ]);
  }
}
