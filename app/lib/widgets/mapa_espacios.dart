import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/espacio.dart';
import '../data/tramos_geometria.dart';
import '../theme/estacionaya_theme.dart';

class MapaEspacios extends StatefulWidget {
  final List<Espacio> espacios;
  final ll.LatLng? centroInicial;
  final List<TramoGeo> tramosAzules;
  final ValueChanged<TramoGeo>? onTramoSeleccionado;

  /// Cuando se cartografÃ­a un tramo, los toques aÃ±aden vÃ©rtices.
  final bool modoDibujo;
  final List<ll.LatLng> puntosBorrador;
  final ValueChanged<ll.LatLng>? onPuntoDibujo;
  final String? espacioSeleccionadoId;
  final ValueChanged<Espacio>? onEspacioSeleccionado;

  const MapaEspacios({
    super.key,
    required this.espacios,
    this.centroInicial,
    this.tramosAzules = const [],
    this.onTramoSeleccionado,
    this.modoDibujo = false,
    this.puntosBorrador = const [],
    this.onPuntoDibujo,
    this.espacioSeleccionadoId,
    this.onEspacioSeleccionado,
  });

  @override
  State<MapaEspacios> createState() => _MapaEspaciosState();
}

class _MapaEspaciosState extends State<MapaEspacios> {
  // Punto central del campus UPEC en TulcÃƒÂ¡n (referencia cartogrÃƒÂ¡fica pÃƒÂºblica).
  static const _centroUpec = ll.LatLng(0.80525, -77.73434);
  static const _calculadorDistancia = ll.Distance();

  late final MapController _controller;
  double _zoom = 17;

  @override
  void initState() {
    super.initState();
    _controller = MapController();
  }

  @override
  Widget build(BuildContext context) {
    final puntos = widget.espacios
        .where((espacio) => espacio.latitud != null && espacio.longitud != null)
        .toList();
    final grupos = _agrupar(puntos, _zoom);

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.centroInicial ?? _centroUpec,
        initialZoom: 17,
        maxZoom: 18,
        onMapEvent: _alCambiarCamara,
        onTap: (tapPosition, point) {
          if (widget.modoDibujo) widget.onPuntoDibujo?.call(point);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.estacionaya',
        ),
        if (widget.tramosAzules.isNotEmpty)
          PolylineLayer(
            polylines: [
              for (final tramo in widget.tramosAzules)
                if (tramo.puntos.length >= 2)
                  Polyline(
                    points: tramo.puntos,
                    color: EstacionaYaTokens.primary,
                    strokeWidth: 7,
                  ),
            ],
          ),
        if (widget.puntosBorrador.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points: widget.puntosBorrador,
              color: Colors.orange,
              strokeWidth: 7,
            )
          ]),
        MarkerLayer(markers: [
          ...grupos.map(_construirMarcador),
          for (final tramo in widget.tramosAzules)
            if (tramo.puntos.length >= 2) _marcadorTramo(tramo),
          ...widget.puntosBorrador.map((p) => Marker(
                point: p,
                width: 22,
                height: 22,
                child: const Icon(Icons.circle, size: 18, color: Colors.orange),
              )),
        ]),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap', onTap: () {}),
          ],
          showFlutterMapAttribution: false,
        ),
      ],
    );
  }

  Marker _marcadorTramo(TramoGeo tramo) {
    // El punto estÃ¡ sobre la geometrÃ­a validada por quien la cartografiÃ³.
    final centro = tramo.puntos[tramo.puntos.length ~/ 2];
    return Marker(
      point: centro,
      width: 36,
      height: 40,
      child: Tooltip(
        message: '${tramo.calle} Â· zona azul documentada',
        child: InkWell(
          onTap: widget.modoDibujo
              ? null
              : () => widget.onTramoSeleccionado?.call(tramo),
          child: Container(
            decoration: BoxDecoration(
              color: EstacionaYaTokens.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x40000000), blurRadius: 5)
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.local_parking_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  void _alCambiarCamara(MapEvent evento) {
    if (evento is! MapEventMoveEnd ||
        (evento.camera.zoom - _zoom).abs() < 0.3) {
      return;
    }
    final zoom = evento.camera.zoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _zoom = zoom);
    });
  }

  List<_GrupoEspacios> _agrupar(List<Espacio> puntos, double zoom) {
    final radioMetros = 90 * math.pow(2, 14 - zoom).toDouble();
    final pendientes = List<Espacio>.of(puntos);
    final grupos = <_GrupoEspacios>[];

    while (pendientes.isNotEmpty) {
      final base = pendientes.removeAt(0);
      final miembros = <Espacio>[base];
      final baseLatLng = ll.LatLng(base.latitud!, base.longitud!);
      for (var i = pendientes.length - 1; i >= 0; i--) {
        final candidato = pendientes[i];
        final distancia = _calculadorDistancia.as(
          ll.LengthUnit.Meter,
          baseLatLng,
          ll.LatLng(candidato.latitud!, candidato.longitud!),
        );
        if (distancia <= radioMetros) miembros.add(pendientes.removeAt(i));
      }
      grupos.add(_GrupoEspacios(miembros));
    }
    return grupos;
  }

  Marker _construirMarcador(_GrupoEspacios grupo) {
    final centro = grupo.centro;
    if (!grupo.esCluster) {
      final espacio = grupo.espacios.single;
      final estado = espacio.visionEnLinea ? espacio.estado : 'SIN_SERVICIO';
      final color = _colorEstado(estado);
      final seleccionado = espacio.id == widget.espacioSeleccionadoId;

      return Marker(
        point: centro,
        width: 40,
        height: 44,
        alignment: Alignment.bottomCenter,
        child: Tooltip(
          message: '${espacio.nombre} Ã‚Â· ${_nombreEstado(estado)}',
          child: InkResponse(
            radius: 24,
            onTap: () => widget.onEspacioSeleccionado?.call(espacio),
            child: AnimatedScale(
              scale: seleccionado ? 1.08 : 1,
              duration: const Duration(milliseconds: 160),
              child: SizedBox(
                width: 40,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 42,
                      color: color,
                      shadows: const [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 7,
                      child: Text(
                        'P',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final libres = grupo.espacios
        .where((e) => e.visionEnLinea && e.estado == 'LIBRE')
        .length;
    final sinServicio = grupo.espacios.every(
      (e) => !e.visionEnLinea || e.estado == 'SIN_SERVICIO',
    );
    final color = sinServicio
        ? EstacionaYaTokens.offline
        : libres > 0
            ? EstacionaYaTokens.available
            : EstacionaYaTokens.occupied;

    // Los tres espacios ANTIZANA comparten un punto de acceso GPS.
    // El marcador agrupado abre una lista, en lugar de superponer tres pines.
    final esGrupoAntizana = grupo.espacios.length > 1 &&
        grupo.espacios.every((e) =>
            e.camaraId == 'CAM-005' &&
            const {'ANT-001', 'ANT-002', 'ANT-003'}.contains(e.nombre));

    return Marker(
      point: centro,
      width: 42,
      height: 42,
      child: Tooltip(
        message: esGrupoAntizana
            ? 'Estacionamientos Antisana · toca para ver cada plaza'
            : '${grupo.espacios.length} espacios cercanos. Toca para acercar el mapa.',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: esGrupoAntizana
                ? () => _mostrarPlazasAntizana(grupo.espacios)
                : () => _controller.move(centro, math.min(_zoom + 2, 18)),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330F172A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: esGrupoAntizana
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_parking_rounded,
                              color: Colors.white, size: 15),
                          Text('${grupo.espacios.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              )),
                        ],
                      )
                    : Text(
                        '${grupo.espacios.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarPlazasAntizana(List<Espacio> espacios) {
    if (widget.modoDibujo) return;
    final plazas = List<Espacio>.of(espacios)
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Estacionamientos Antisana',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Tulcán · Cámara CAM-005 · Acceso compartido',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 14),
              for (final plaza in plazas)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _colorEstado(
                        plaza.visionEnLinea ? plaza.estado : 'SIN_SERVICIO',
                      ).withValues(alpha: .14),
                      child: Icon(Icons.local_parking_rounded,
                          color: _colorEstado(
                            plaza.visionEnLinea ? plaza.estado : 'SIN_SERVICIO',
                          )),
                    ),
                    title: Text(plaza.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_nombreEstado(
                      plaza.visionEnLinea ? plaza.estado : 'SIN_SERVICIO',
                    )),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onEspacioSeleccionado?.call(plaza);
                    },
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Los tres espacios comparten un punto de acceso. '
                'Sus posiciones individuales aún no están georreferenciadas.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'LIBRE':
        return EstacionaYaTokens.available;
      case 'OCUPADO':
        return EstacionaYaTokens.occupied;
      default:
        return EstacionaYaTokens.offline;
    }
  }

  String _nombreEstado(String estado) {
    switch (estado) {
      case 'LIBRE':
        return 'LIBRE';
      case 'OCUPADO':
        return 'OCUPADO';
      default:
        return 'SIN SERVICIO';
    }
  }
}

class _GrupoEspacios {
  final List<Espacio> espacios;
  const _GrupoEspacios(this.espacios);

  bool get esCluster => espacios.length > 1;

  ll.LatLng get centro => ll.LatLng(
        espacios.map((e) => e.latitud!).reduce((a, b) => a + b) /
            espacios.length,
        espacios.map((e) => e.longitud!).reduce((a, b) => a + b) /
            espacios.length,
      );
}
