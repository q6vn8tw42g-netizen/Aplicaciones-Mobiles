import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/espacio.dart';
import '../providers/espacios_provider.dart';
import '../services/navigation_service.dart';
import '../theme/estacionaya_theme.dart';
import '../widgets/mapa_espacios.dart';
import '../widgets/availability_strip.dart';
import '../widgets/camera_connection_badge.dart';
import '../widgets/parking_summary_card.dart';
import '../widgets/parking_status.dart';
import '../widgets/estacionaya_components.dart';
import 'login_screen.dart';

/// Mapa y disponibilidad de espacios monitoreados.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Navegador { googleMaps, waze }

class _HomeScreenState extends State<HomeScreen> {
  static const _tulcan = ll.LatLng(0.80525, -77.73434);
  static const _dist = ll.Distance();
  static const _radioMetros = 12000.0;

  final _buscar = TextEditingController();
  bool _mostrarBusqueda = false;
  ll.LatLng? _ubicacion;
  ll.LatLng? _foco;
  int _solicitudFoco = 0;
  final _panelController = DraggableScrollableController();
  bool _buscandoUbicacion = false;
  String _consulta = '';
  int _tab = 0;
  String? _seleccionado;
  bool _soloCercanos = false;
  ll.LatLng get _centro => _tulcan;

  @override
  void dispose() {
    _panelController.dispose();
    _buscar.dispose();
    super.dispose();
  }

  // ANTIZANA pertenece a Tulcán; las plazas sin GPS permanecen en la lista,
  // pero nunca se envían a la capa de marcadores hasta georreferenciarlas.
  List<Espacio> _espacios(List<Espacio> registros) {
    final q = _consulta.toLowerCase().trim();
    final filtrados = registros.where((e) {
      final esAntizana = e.camaraId == 'CAM-005' &&
          const {'ANT-001', 'ANT-002', 'ANT-003'}.contains(e.nombre);
      if (!'${e.nombre} ${e.camaraId}'.toLowerCase().contains(q)) {
        return false;
      }
      if (!_tieneDestino(e)) {
        return esAntizana && !_soloCercanos;
      }
      final punto = ll.LatLng(e.latitud!, e.longitud!);
      if (!_soloCercanos &&
          _dist.as(ll.LengthUnit.Meter, _centro, punto) > _radioMetros) {
        return false;
      }
      if (_soloCercanos &&
          _ubicacion != null &&
          _dist.as(ll.LengthUnit.Meter, _ubicacion!, punto) > 2000) {
        return false;
      }
      return true;
    }).toList();
    if (_ubicacion != null) {
      filtrados.sort((a, b) {
        double distancia(Espacio e) => !_tieneDestino(e)
            ? double.infinity
            : _dist.as(ll.LengthUnit.Meter, _ubicacion!,
                ll.LatLng(e.latitud!, e.longitud!));
        return distancia(a).compareTo(distancia(b));
      });
    } else {
      filtrados.sort((a, b) => a.nombre.compareTo(b.nombre));
    }
    return filtrados;
  }

  Future<void> _localizar() async {
    if (_buscandoUbicacion) return;
    setState(() => _buscandoUbicacion = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) _aviso('Activa el GPS y vuelve a tocar Mi ubicación.');
        return;
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.deniedForever ||
          permiso == LocationPermission.denied) {
        if (mounted) {
          _aviso(permiso == LocationPermission.deniedForever
              ? 'Puedes habilitar la ubicación en los ajustes de EstacionaYa.'
              : 'Puedes seguir explorando el mapa sin compartir tu ubicación.');
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15));
      if (!mounted || _tab != 0) return;
      setState(() {
        _ubicacion = ll.LatLng(pos.latitude, pos.longitude);
        _foco = _ubicacion;
        _solicitudFoco++;
        _soloCercanos = true;
        _seleccionado = null;
      });
      HapticFeedback.selectionClick();
    } on TimeoutException {
      if (mounted) {
        _aviso('No se obtuvo posición a tiempo. Vuelve a intentarlo.');
      }
    } catch (_) {
      if (mounted) {
        _aviso(
            'No se pudo obtener tu ubicación. Puedes seguir usando el mapa.');
      }
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  void _aviso(String mensaje) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(mensaje)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _tab == 0 ? EstacionaYaTokens.surface : EstacionaYaTokens.canvas,
      body: _tab == 0
          ? SafeArea(
              bottom: false,
              child: Column(children: [
                _encabezado(),
                Expanded(child: _mapaPrincipal()),
              ]))
          : TweenAnimationBuilder<double>(
              key: ValueKey(_tab),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              tween: Tween(begin: 0, end: 1),
              curve: Curves.easeOut,
              builder: (_, value, child) =>
                  Opacity(opacity: value, child: child),
              child: _paginaSecundaria()),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: EstacionaYaTokens.surface,
          border: Border(top: BorderSide(color: EstacionaYaTokens.outline)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Mapa'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Ajustes'),
          ],
        ),
      ),
    );
  }

  Widget _mapaPrincipal() => Consumer<EspaciosProvider>(
        builder: (context, provider, _) {
          final espacios = _espacios(provider.espaciosVisibles);

          // Solo los espacios georreferenciados se dibujan en el mapa.
          // Los demás siguen apareciendo en la lista En vivo.
          final espaciosMapa =
              espacios.where(_tieneDestino).toList(growable: false);

          final ancho = MediaQuery.sizeOf(context).width;
          final esWebAncha = ancho >= 900;
          final mapa = Stack(children: [
            Positioned.fill(
                child: MapaEspacios(
              key: ValueKey(provider.cargando),
              centroInicial: espaciosMapa.isNotEmpty
                  ? ll.LatLng(
                      espaciosMapa.first.latitud!, espaciosMapa.first.longitud!)
                  : _centro,
              espacios: espaciosMapa,
              ubicacionUsuario: _ubicacion,
              sincronizado: !provider.cargando && provider.error == null,
              foco: _foco,
              solicitudFoco: _solicitudFoco,
              espacioSeleccionadoId: _seleccionado,
              onEspacioSeleccionado: _seleccionarEspacio,
            )),
            Positioned(
                top: 16,
                left: 16,
                child: FloatingActionButton.extended(
                    heroTag: 'mi-ubicacion',
                    backgroundColor: Colors.white,
                    foregroundColor: EstacionaYaTokens.primary,
                    elevation: 2,
                    highlightElevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side:
                            const BorderSide(color: EstacionaYaTokens.outline)),
                    extendedPadding: const EdgeInsets.symmetric(horizontal: 16),
                    extendedTextStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    tooltip: 'Centrar el mapa en mi ubicación',
                    onPressed: _buscandoUbicacion ? null : _localizar,
                    icon: _buscandoUbicacion
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location_rounded, size: 19),
                    label: Text(
                        _buscandoUbicacion ? 'Localizando…' : 'Mi ubicación'))),
          ]);
          if (esWebAncha) {
            return Row(children: [
              SizedBox(
                  width: 430, child: _panel(provider, espacios, web: true)),
              Expanded(child: mapa),
            ]);
          }
          return Stack(children: [
            Positioned.fill(
                child: FractionallySizedBox(
                    alignment: Alignment.topCenter,
                    heightFactor: .82,
                    child: mapa)),
            DraggableScrollableSheet(
              controller: _panelController,
              initialChildSize: .36,
              minChildSize: .19,
              maxChildSize: .95,
              snap: !MediaQuery.disableAnimationsOf(context),
              snapAnimationDuration: MediaQuery.disableAnimationsOf(context)
                  ? null
                  : const Duration(milliseconds: 420),
              builder: (context, scroll) =>
                  _panel(provider, espacios, scroll: scroll),
            ),
          ]);
        },
      );

  Widget _encabezado() {
    return Material(
        color: EstacionaYaTokens.surface,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const EstacionaYaMark(),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('EstacionaYa',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: EstacionaYaTokens.night,
                                  fontSize: 20,
                                  letterSpacing: -.7)),
                      Text('Encuentra tu espacio',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 11)),
                    ])),
                IconButton(
                    tooltip: 'Mi perfil',
                    style: IconButton.styleFrom(
                        foregroundColor: EstacionaYaTokens.night,
                        backgroundColor: EstacionaYaTokens.canvas,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: () => setState(() => _tab = 1),
                    icon: const Icon(Icons.person_outline_rounded)),
              ]),
            ])));
  }

  Widget _panel(EspaciosProvider provider, List<Espacio> espacios,
      {bool web = false, ScrollController? scroll}) {
    final disponibles =
        espacios.where((e) => _estadoActual(e, provider) == 'LIBRE').length;
    return Container(
      decoration: BoxDecoration(
        color: EstacionaYaTokens.surface,
        borderRadius: web
            ? null
            : const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
        boxShadow: EstacionaYaTokens.softShadow,
      ),
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          if (!web)
            Center(
                child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                        color: EstacionaYaTokens.outline,
                        borderRadius: BorderRadius.circular(6)))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Estacionamientos disponibles',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 18)),
                  const SizedBox(height: 3),
                  Text('Encuentra tu lugar ideal para estacionar',
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
            const SizedBox(width: 8),
            IconButton(
                tooltip: 'Buscar',
                isSelected: _mostrarBusqueda,
                style: IconButton.styleFrom(
                    foregroundColor: EstacionaYaTokens.primary,
                    backgroundColor: EstacionaYaTokens.primarySoft,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: () => setState(() {
                      _mostrarBusqueda = !_mostrarBusqueda;
                      if (!_mostrarBusqueda) {
                        _buscar.clear();
                        _consulta = '';
                      }
                    }),
                icon: const Icon(Icons.search_rounded)),
          ]),
          const SizedBox(height: 16),
          if (_mostrarBusqueda)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                    controller: _buscar,
                    autofocus: true,
                    onChanged: (s) => setState(() => _consulta = s),
                    decoration: const InputDecoration(
                        labelText: 'Buscar espacio',
                        prefixIcon: Icon(Icons.search)))),
          AvailabilityStrip(
              total: espacios.length,
              libres: disponibles,
              ocupados: espacios
                  .where((e) => _estadoActual(e, provider) == 'OCUPADO')
                  .length,
              confirmado: !provider.cargando && provider.error == null),
          const SizedBox(height: 12),
          if (provider.error != null)
            _nota(
                'No se pudo actualizar la disponibilidad. Revisa tu conexión.'),
          if (_soloCercanos)
            InputChip(
              label: const Text('A menos de 2 km de mí'),
              avatar: const Icon(Icons.my_location, size: 18),
              onDeleted: () => setState(() => _soloCercanos = false),
            ),
          if (provider.cargando)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: BorderRadius.all(Radius.circular(3))),
                      const SizedBox(height: 8),
                      Text('Consultando disponibilidad…',
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
          if (espacios.isEmpty && !provider.cargando && provider.error == null)
            ParkingEmptyState(
                title: _consulta.isNotEmpty || _soloCercanos
                    ? 'Sin coincidencias'
                    : 'Sin espacios en esta zona',
                message: _consulta.isNotEmpty || _soloCercanos
                    ? 'Amplía el área o cambia la búsqueda.'
                    : 'Consulta los espacios monitoreados o activa Mi ubicación.'),
          for (final e in espacios) _tarjetaEspacio(e, provider),
        ],
      ),
    );
  }

  Widget _nota(String texto) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: EstacionaYaTokens.occupiedSoft,
            border: Border.all(
                color: EstacionaYaTokens.occupied.withValues(alpha: .15)),
            borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded,
              color: EstacionaYaTokens.occupied, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 12))),
        ]),
      );

  String _estadoActual(Espacio e, EspaciosProvider provider) => estadoVisible(e,
      sincronizado: !provider.cargando && provider.error == null);

  void _seleccionarEspacio(Espacio espacio) {
    HapticFeedback.selectionClick();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _seleccionado = espacio.id;
      if (_tieneDestino(espacio)) {
        _foco = ll.LatLng(espacio.latitud!, espacio.longitud!);
        _solicitudFoco++;
      }
    });
    if (_panelController.isAttached && _panelController.size > .36) {
      _panelController.jumpTo(.36);
    }
    _detalleEspacio(espacio);
  }

  bool _tieneDestino(Espacio e) =>
      e.latitud != null &&
      e.longitud != null &&
      e.latitud!.isFinite &&
      e.longitud!.isFinite &&
      e.latitud! >= -90 &&
      e.latitud! <= 90 &&
      e.longitud! >= -180 &&
      e.longitud! <= 180;

  bool _navegable(Espacio? espacio, EspaciosProvider provider) =>
      espacio != null &&
      _tieneDestino(espacio) &&
      _estadoActual(espacio, provider) == 'LIBRE';

  Future<void> _elegirNavegador(String id, EspaciosProvider provider) async {
    Espacio? actual() => provider.espacios.where((e) => e.id == id).firstOrNull;
    final opcion = await showModalBottomSheet<_Navegador>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => ListenableBuilder(
            listenable: provider,
            builder: (_, __) {
              final plaza = actual();
              final disponible = _navegable(plaza, provider);
              return SafeArea(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Navegar',
                                style: Theme.of(ctx).textTheme.headlineSmall),
                            const SizedBox(height: 6),
                            Text(disponible
                                ? 'Elige cómo llegar a ${plaza!.nombre}.'
                                : 'Este destino ya no tiene disponibilidad confirmada.'),
                            const SizedBox(height: 12),
                            for (final app in _Navegador.values)
                              Card(
                                  child: ListTile(
                                      enabled: disponible,
                                      leading: CircleAvatar(
                                          backgroundColor:
                                              EstacionaYaTokens.primarySoft,
                                          child: Icon(
                                              app == _Navegador.googleMaps
                                                  ? Icons.map_outlined
                                                  : Icons.navigation_outlined,
                                              color:
                                                  EstacionaYaTokens.primary)),
                                      title: Text(app == _Navegador.googleMaps
                                          ? 'Google Maps'
                                          : 'Waze'),
                                      trailing: const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 18),
                                      onTap: disponible
                                          ? () => Navigator.pop(ctx, app)
                                          : null)),
                            const Text(
                                'La disponibilidad puede cambiar durante el trayecto.',
                                style:
                                    TextStyle(color: EstacionaYaTokens.muted)),
                          ])));
            }));
    if (!mounted || opcion == null) return;
    final plaza = actual();
    if (!_navegable(plaza, provider)) {
      _aviso('La disponibilidad del espacio cambió.');
      return;
    }
    final abrir = opcion == _Navegador.googleMaps
        ? NavigationService.abrirGoogleMaps
        : NavigationService.abrirWaze;
    try {
      await abrir(latitud: plaza!.latitud!, longitud: plaza.longitud!);
    } catch (_) {
      if (mounted) {
        _aviso(
            'No se pudo abrir la aplicación de navegación ni el enlace web.');
      }
    }
  }

  Widget _tarjetaEspacio(Espacio e, EspaciosProvider provider) {
    final valor = _estadoActual(e, provider);
    final color = colorEstado(valor);
    final estado = etiquetaEstado(valor);
    String? distancia;
    if (_ubicacion != null && _tieneDestino(e)) {
      final metros = _dist.as(
          ll.LengthUnit.Meter, _ubicacion!, ll.LatLng(e.latitud!, e.longitud!));
      distancia = metros < 1000
          ? '${metros.round()} m aprox. en línea recta'
          : '${(metros / 1000).toStringAsFixed(1)} km aprox. en línea recta';
    }
    return ParkingSummaryCard(
      key: ValueKey(e.id),
      espacio: e,
      color: color,
      estado: estado,
      distancia: distancia,
      tieneDestino: _tieneDestino(e),
      onTap: () => _seleccionarEspacio(e),
      cargando: provider.cargando,
      errorSincronizacion: provider.error != null,
    );
  }

  void _detalleEspacio(Espacio seleccionado) {
    final provider = context.read<EspaciosProvider>();
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => ListenableBuilder(
            listenable: provider,
            builder: (ctx, _) {
              final espacio = provider.espacios
                  .where((e) => e.id == seleccionado.id)
                  .firstOrNull;
              if (espacio == null) {
                return const SafeArea(
                    child: ListTile(
                        leading: Icon(Icons.location_off_outlined),
                        title: Text('Este espacio ya no está disponible.')));
              }
              final valor = _estadoActual(espacio, provider);
              final color = colorEstado(valor);
              final gps = _tieneDestino(espacio);
              final fecha = espacio.actualizadoEn.toLocal();
              final formato = MaterialLocalizations.of(ctx);
              return SafeArea(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(espacio.nombre,
                                style: Theme.of(ctx).textTheme.headlineSmall),
                            const SizedBox(height: 12),
                            Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(16)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(etiquetaEstado(valor),
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 6),
                                      CameraConnectionBadge(
                                          cameraId: espacio.camaraId,
                                          visionEnLinea: espacio.visionEnLinea,
                                          cargando: provider.cargando,
                                          errorSincronizacion:
                                              provider.error != null),
                                    ])),
                            ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.history_rounded),
                                title: const Text('Última actualización'),
                                subtitle: Text(
                                    '${formato.formatCompactDate(fecha)} · ${formato.formatTimeOfDay(TimeOfDay.fromDateTime(fecha))}')),
                            if (espacio.tipoVehiculo != 'MIXTO' ||
                                espacio.vehiculoDetectado != null)
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading:
                                      const Icon(Icons.directions_car_outlined),
                                  title: Text(espacio.vehiculoDetectado != null
                                      ? 'Vehículo detectado'
                                      : 'Tipo de vehículo'),
                                  subtitle: Text(espacio.vehiculoDetectado ??
                                      espacio.tipoVehiculo)),
                            Text(
                                gps
                                    ? 'La ocupación puede cambiar durante el trayecto.'
                                    : 'Las coordenadas de esta plaza están pendientes.',
                                style: Theme.of(ctx).textTheme.bodySmall),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                                onPressed: _navegable(espacio, provider)
                                    ? () =>
                                        _elegirNavegador(espacio.id, provider)
                                    : null,
                                icon: const Icon(Icons.navigation_rounded),
                                label: const Text('Navegar')),
                          ])));
            }));
  }

  Widget _paginaSecundaria() {
    final session = Supabase.instance.client.auth.currentSession;
    final perfil = _tab == 1;
    final theme = Theme.of(context);
    return SafeArea(
        child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: ListView(
                    key: ValueKey(_tab),
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                    children: [
                      Text('ESTACIONAYA', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 8),
                      Text(perfil ? 'Mi perfil' : 'Ajustes',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(
                          perfil
                              ? 'Tu espacio en EstacionaYa.'
                              : 'Conoce cómo funciona EstacionaYa.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: EstacionaYaTokens.muted)),
                      const SizedBox(height: 24),
                      if (perfil) ...[
                        EstacionaYaProfileCard(
                            title: session == null
                                ? 'Modo visitante'
                                : 'Sesión iniciada',
                            description: session?.user.email ??
                                'Puedes consultar el mapa y la disponibilidad de espacios.'),
                        const SizedBox(height: 20),
                        Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: EstacionaYaTokens.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: EstacionaYaTokens.outline)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.shield_outlined,
                                        color: EstacionaYaTokens.primary,
                                        size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text('Acceso a tu cuenta',
                                            style:
                                                theme.textTheme.titleMedium)),
                                  ]),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                      onPressed: _sesion,
                                      icon: Icon(
                                          session == null
                                              ? Icons.login_rounded
                                              : Icons.logout_rounded,
                                          size: 20),
                                      label: Text(session == null
                                          ? 'Iniciar sesión'
                                          : 'Cerrar sesión')),
                                ])),
                      ] else ...[
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const EstacionaYaMark(size: 48),
                                      const SizedBox(height: 20),
                                      Text('Acerca de EstacionaYa',
                                          style: theme.textTheme.titleLarge),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Disponibilidad de parqueos en tiempo real',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                  color:
                                                      EstacionaYaTokens.muted)),
                                    ]))),
                        const SizedBox(height: 12),
                        Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text('MAPA Y DISPONIBILIDAD',
                                style: theme.textTheme.labelSmall)),
                        const Card(
                            child: Column(children: [
                          EstacionaYaInfoTile(
                              icon: Icons.sensors_outlined,
                              title: 'Información de monitoreo',
                              description:
                                  '«Cámara activa» indica que se recibió una señal reciente. Una plaza libre puede ocuparse durante el trayecto.'),
                          Padding(
                              padding: EdgeInsets.symmetric(horizontal: 18),
                              child: Divider()),
                          EstacionaYaInfoTile(
                              icon: Icons.my_location_rounded,
                              title: 'Tu ubicación',
                              description:
                                  'Se consulta al tocar Mi ubicación. Las distancias se muestran en línea recta.'),
                        ])),
                      ],
                    ]))));
  }

  Future<void> _sesion() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
    } else {
      await auth.signOut();
    }
    if (mounted) setState(() {});
  }
}
