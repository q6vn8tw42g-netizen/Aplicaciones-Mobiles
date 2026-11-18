import 'package:flutter/material.dart';

import '../models/espacio.dart';
import '../theme/estacionaya_theme.dart';
import 'camera_connection_badge.dart';
import 'parking_status.dart';

/// Presentation only; destination validation and actions remain with the caller.
class ParkingSummaryCard extends StatelessWidget {
  final Espacio espacio;
  final Color color;
  final String estado;
  final String? distancia;
  final bool tieneDestino;
  final VoidCallback onTap;
  final bool cargando;
  final bool errorSincronizacion;
  const ParkingSummaryCard(
      {super.key,
      required this.espacio,
      required this.color,
      required this.estado,
      this.distancia,
      required this.tieneDestino,
      required this.onTap,
      this.cargando = false,
      this.errorSincronizacion = false});

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final icon = iconoEstado(estadoVisible(espacio,
        sincronizado: !cargando && !errorSincronizacion));
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: EstacionaYaTokens.softShadow),
            child: Material(
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                    side: const BorderSide(color: EstacionaYaTokens.outline),
                    borderRadius: BorderRadius.circular(18)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: onTap,
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                AnimatedContainer(
                                    duration: duration,
                                    width: 42,
                                    height: 46,
                                    decoration: BoxDecoration(
                                        color: color.withValues(alpha: .08),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Icon(icon, color: color, size: 24)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(espacio.nombre,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 6),
                                      AnimatedSwitcher(
                                          duration: duration,
                                          child: Container(
                                              key: ValueKey(estado),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                  color: color.withValues(
                                                      alpha: .08),
                                                  borderRadius:
                                                      BorderRadius.circular(6)),
                                              child: Text(estado,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: color,
                                                      fontWeight:
                                                          FontWeight.w700)))),
                                    ])),
                                const Icon(Icons.chevron_right_rounded,
                                    color: EstacionaYaTokens.muted),
                              ]),
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider()),
                              Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    CameraConnectionBadge(
                                        cameraId: espacio.camaraId,
                                        visionEnLinea: espacio.visionEnLinea,
                                        cargando: cargando,
                                        errorSincronizacion:
                                            errorSincronizacion),
                                    if (distancia != null)
                                      Text(distancia!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    if (!tieneDestino)
                                      Text('Ubicación pendiente',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    if (espacio.tipoVehiculo != 'MIXTO')
                                      Text('Admite: ${espacio.tipoVehiculo}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    if (espacio.vehiculoDetectado != null)
                                      Text(
                                          'Detectado: ${espacio.vehiculoDetectado}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                  ]),
                            ]))))));
  }
}
