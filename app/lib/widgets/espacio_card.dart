import 'dart:async';

import 'package:flutter/material.dart';

import '../models/espacio.dart';
import '../theme/estacionaya_theme.dart';

class EspacioCard extends StatelessWidget {
  final Espacio espacio;
  final VoidCallback? onNavegar;
  final bool puedeAdministrar;
  final bool seleccionado;
  final VoidCallback? onSeleccionar;
  final VoidCallback? onVerHistorial;
  final VoidCallback? onForzar;
  final VoidCallback? onReservar;
  final VoidCallback? onCancelarReserva;

  const EspacioCard({
    super.key,
    required this.espacio,
    this.onNavegar,
    this.puedeAdministrar = false,
    this.seleccionado = false,
    this.onSeleccionar,
    this.onVerHistorial,
    this.onForzar,
    this.onReservar,
    this.onCancelarReserva,
  });

  @override
  Widget build(BuildContext context) {
    final estadoVisual = espacio.visionEnLinea
        ? _obtenerEstadoVisual(espacio.estado)
        : _obtenerEstadoVisual('SIN_SERVICIO');

    final puedeNavegar = espacio.latitud != null &&
        espacio.longitud != null &&
        espacio.estado == 'LIBRE' &&
        espacio.visionEnLinea &&
        onNavegar != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EstacionaYaTokens.radius20),
        side: BorderSide(
          color: seleccionado
              ? EstacionaYaTokens.primary
              : EstacionaYaTokens.outline,
          width: seleccionado ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSeleccionar,
        child: Padding(
          padding: const EdgeInsets.all(EstacionaYaTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          espacio.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: EstacionaYaTokens.space4),
                        Text(
                          espacio.camaraId,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: EstacionaYaTokens.space8),
                  _EstadoBadge(
                    texto: estadoVisual.texto,
                    color: estadoVisual.colorTexto,
                    fondo: estadoVisual.colorFondo,
                    icono: estadoVisual.icono,
                  ),
                ],
              ),
              if (!espacio.visionEnLinea && espacio.camaraId == 'CAM-001') ...[
                const SizedBox(height: EstacionaYaTokens.space8),
                Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 15, color: EstacionaYaTokens.offline),
                    const SizedBox(width: EstacionaYaTokens.space4),
                    Expanded(
                      child: Text(
                        'Cámara sin conexión; estado no actualizado.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (espacio.tipoVehiculo != 'MIXTO' ||
                  espacio.vehiculoDetectado != null) ...[
                const SizedBox(height: EstacionaYaTokens.space8),
                Text(
                  espacio.vehiculoDetectado != null
                      ? 'Detectado: ${_nombreVehiculo(espacio.vehiculoDetectado!)}'
                      : 'Admite: ${_nombreVehiculo(espacio.tipoVehiculo)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (espacio.estado == 'RESERVADO') ...[
                const SizedBox(height: EstacionaYaTokens.space8),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 16, color: EstacionaYaTokens.reserved),
                    const SizedBox(width: EstacionaYaTokens.space4),
                    Expanded(
                      child: _ReservaCuentaRegresiva(
                        expiracion: espacio.expiracionReserva,
                      ),
                    ),
                    if (onCancelarReserva != null)
                      TextButton.icon(
                        onPressed: onCancelarReserva,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Liberar espacio'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: EstacionaYaTokens.space12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: puedeNavegar ? onNavegar : null,
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Navegar'),
                ),
              ),
              if (espacio.estado == 'LIBRE' && espacio.visionEnLinea) ...[
                const SizedBox(height: EstacionaYaTokens.space8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onReservar,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Reservar por 5 min'),
                  ),
                ),
              ],
              if (puedeAdministrar) ...[
                const SizedBox(height: EstacionaYaTokens.space8),
                Wrap(
                  spacing: EstacionaYaTokens.space8,
                  runSpacing: EstacionaYaTokens.space4,
                  children: [
                    TextButton.icon(
                      onPressed: onVerHistorial,
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Historial'),
                    ),
                    TextButton.icon(
                      onPressed: onForzar,
                      icon: const Icon(Icons.admin_panel_settings_rounded),
                      label: const Text('Forzar estado'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _EstadoVisual _obtenerEstadoVisual(
    String estado,
  ) {
    switch (estado) {
      case 'LIBRE':
        return const _EstadoVisual(
          texto: 'Libre',
          colorFondo: Color(0xFFE8F5E9),
          colorTexto: EstacionaYaTokens.available,
          icono: Icons.check_circle_rounded,
        );

      case 'OCUPADO':
        return const _EstadoVisual(
          texto: 'Ocupado',
          colorFondo: Color(0xFFFEE4E2),
          colorTexto: EstacionaYaTokens.occupied,
          icono: Icons.directions_car_filled_rounded,
        );

      case 'RESERVADO':
        return const _EstadoVisual(
          texto: 'Reservado',
          colorFondo: Color(0xFFFFF1D6),
          colorTexto: EstacionaYaTokens.reserved,
          icono: Icons.schedule_rounded,
        );

      case 'SIN_SERVICIO':
        return const _EstadoVisual(
          texto: 'Sin servicio',
          colorFondo: Color(0xFFE2E8F0),
          colorTexto: EstacionaYaTokens.offline,
          icono: Icons.wifi_off_rounded,
        );

      default:
        return const _EstadoVisual(
          texto: 'Desconocido',
          colorFondo: Color(0xFFE2E8F0),
          colorTexto: EstacionaYaTokens.offline,
          icono: Icons.help_outline_rounded,
        );
    }
  }

  String _nombreVehiculo(String tipo) {
    switch (tipo) {
      case 'MOTO':
        return 'Moto';
      case 'AUTO':
        return 'Auto';
      case 'CAMIONETA':
        return 'Camioneta';
      default:
        return 'Todo tipo';
    }
  }
}

class _ReservaCuentaRegresiva extends StatefulWidget {
  final DateTime? expiracion;

  const _ReservaCuentaRegresiva({required this.expiracion});

  @override
  State<_ReservaCuentaRegresiva> createState() =>
      _ReservaCuentaRegresivaState();
}

class _ReservaCuentaRegresivaState extends State<_ReservaCuentaRegresiva> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarTimer();
  }

  @override
  void didUpdateWidget(covariant _ReservaCuentaRegresiva oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiracion != widget.expiracion) _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    if (widget.expiracion == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (widget.expiracion!.difference(DateTime.now()).inSeconds <= 0) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expiracion = widget.expiracion;
    if (expiracion == null) {
      return const Text('Reserva activa');
    }
    final segundos =
        expiracion.difference(DateTime.now()).inSeconds.clamp(0, 299);
    final minutos = (segundos ~/ 60).toString().padLeft(2, '0');
    final restantes = (segundos % 60).toString().padLeft(2, '0');
    return Text(
      'Reserva vence en $minutos:$restantes',
      style: const TextStyle(
        color: EstacionaYaTokens.reserved,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String texto;
  final Color color;
  final Color fondo;
  final IconData icono;

  const _EstadoBadge({
    required this.texto,
    required this.color,
    required this.fondo,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              texto,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
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
