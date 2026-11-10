import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/espacio.dart';
import '../providers/espacios_provider.dart';
import '../services/navigation_service.dart';
import '../theme/estacionaya_theme.dart';
import '../widgets/mapa_espacios.dart';
import 'login_screen.dart';

/// Primera etapa urbana de EstacionaYa: Tulcán y Montúfar.
/// Solo muestra espacios reales recibidos del proveedor. No ofrece reservas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Ciudad { tulcan, montufar }

class _HomeScreenState extends State<HomeScreen> {
  static const _centroTulcan = ll.LatLng(0.80525, -77.73434);
  // Referencia para San Gabriel, cabecera cantonal de Montúfar.
  static const _centroMontufar = ll.LatLng(0.59354, -77.83066);
  static const _distancia = ll.Distance();
  static const _radioConsultaMetros = 12000.0;

  _Ciudad _ciudad = _Ciudad.tulcan;
  String? _espacioSeleccionadoId;
  int _tabIndex = 0;
  String _estadoFiltro = 'TODOS';

  ll.LatLng get _centro =>
      _ciudad == _Ciudad.tulcan ? _centroTulcan : _centroMontufar;

  String get _nombreCiudad => _ciudad == _Ciudad.tulcan ? 'Tulcán' : 'Montúfar';

  List<Espacio> _espaciosCiudad(List<Espacio> espacios) {
    final cercanos = espacios.where((espacio) {
      if (espacio.latitud == null || espacio.longitud == null) return false;
      final metros = _distancia.as(
        ll.LengthUnit.Meter,
        _centro,
        ll.LatLng(espacio.latitud!, espacio.longitud!),
      );
      return metros <= _radioConsultaMetros;
    });
    final filtrados = cercanos.where((espacio) {
      return _estadoFiltro == 'TODOS' || espacio.estado == _estadoFiltro;
    }).toList();
    filtrados.sort((a, b) {
      if (a.id == _espacioSeleccionadoId) return -1;
      if (b.id == _espacioSeleccionadoId) return 1;
      return a.nombre.compareTo(b.nombre);
    });
    return filtrados;
  }

  void _cambiarCiudad(_Ciudad ciudad) {
    if (_ciudad == ciudad) return;
    setState(() {
      _ciudad = ciudad;
      _espacioSeleccionadoId = null;
      _estadoFiltro = 'TODOS';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabIndex == 0
          ? _pantallaMapa(context)
          : _pantallaSecundaria(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Zonas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  Widget _pantallaMapa(BuildContext context) {
    return Consumer<EspaciosProvider>(
      builder: (context, provider, _) {
        final espacios = _espaciosCiudad(provider.espaciosVisibles);
        final disponibles = espacios
            .where((e) => e.estado == 'LIBRE' && e.visionEnLinea)
            .length;

        return Stack(
          fit: StackFit.expand,
          children: [
            MapaEspacios(
              key: ValueKey(_ciudad),
              espacios: espacios,
              centroInicial: _centro,
              espacioSeleccionadoId: _espacioSeleccionadoId,
              onEspacioSeleccionado: (espacio) {
                setState(() => _espacioSeleccionadoId = espacio.id);
                _detalleEspacio(context, espacio);
              },
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: EstacionaYaTokens.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.local_parking_rounded,
                                  color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('EstacionaYa',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18)),
                                  Text('Zonas azules · Carchi',
                                      style: TextStyle(
                                          color: EstacionaYaTokens.muted,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Mi perfil',
                              onPressed: () => setState(() => _tabIndex = 1),
                              icon: const Icon(Icons.person_outline_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<_Ciudad>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                                value: _Ciudad.tulcan,
                                label: Text('Tulcán'),
                                icon: Icon(Icons.location_city_rounded)),
                            ButtonSegment(
                                value: _Ciudad.montufar,
                                label: Text('Montúfar'),
                                icon: Icon(Icons.place_outlined)),
                          ],
                          selected: {_ciudad},
                          onSelectionChanged: (values) =>
                              _cambiarCiudad(values.first),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.circle,
                                size: 10, color: EstacionaYaTokens.available),
                            const SizedBox(width: 6),
                            Text('$disponibles disponibles',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: EstacionaYaTokens.available)),
                            const Spacer(),
                            Text(_nombreCiudad,
                                style: const TextStyle(
                                    color: EstacionaYaTokens.muted,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.32,
              minChildSize: 0.19,
              maxChildSize: 0.78,
              snap: true,
              snapSizes: const [0.32, 0.78],
              builder: (context, controller) => Container(
                decoration: const BoxDecoration(
                  color: EstacionaYaTokens.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x260F172A),
                        blurRadius: 20,
                        offset: Offset(0, -4))
                  ],
                ),
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    Center(
                        child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                                color: EstacionaYaTokens.outline,
                                borderRadius: BorderRadius.circular(4)))),
                    const SizedBox(height: 18),
                    Text('Estacionamientos · $_nombreCiudad',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                        '${espacios.length} registros cercanos en la base de datos',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _filtro('TODOS', 'Todos'),
                        _filtro('LIBRE', 'Libres'),
                        _filtro('OCUPADO', 'Ocupados'),
                        _filtro('SIN_SERVICIO', 'Sin servicio'),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    if (provider.cargando) const LinearProgressIndicator(),
                    if (provider.error != null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                            'No se pudieron actualizar los datos. Revisa la conexión.'),
                      ),
                    if (espacios.isEmpty && !provider.cargando)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(children: [
                          const Icon(Icons.location_off_outlined,
                              size: 38, color: EstacionaYaTokens.muted),
                          const SizedBox(height: 8),
                          Text(
                              'Sin espacios registrados cerca de $_nombreCiudad',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          const Text(
                              'El mapa muestra datos reales; aún no se han cargado zonas azules verificadas para este sector.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: EstacionaYaTokens.muted,
                                  fontSize: 12)),
                        ]),
                      ),
                    for (final espacio in espacios)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _tarjetaEspacio(context, espacio),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _filtro(String estado, String etiqueta) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(etiqueta),
        selected: _estadoFiltro == estado,
        onSelected: (_) => setState(() => _estadoFiltro = estado),
      ),
    );
  }

  Widget _tarjetaEspacio(BuildContext context, Espacio espacio) {
    final enLinea = espacio.visionEnLinea;
    final estado = enLinea ? espacio.estado : 'SIN_SERVICIO';
    final color = estado == 'LIBRE'
        ? EstacionaYaTokens.available
        : estado == 'OCUPADO'
            ? EstacionaYaTokens.occupied
            : EstacionaYaTokens.offline;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() => _espacioSeleccionadoId = espacio.id);
          _detalleEspacio(context, espacio);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(Icons.local_parking_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(espacio.nombre,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(enLinea ? estado.replaceAll('_', ' ') : 'SIN CONEXIÓN',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            )),
            const Icon(Icons.chevron_right_rounded,
                color: EstacionaYaTokens.muted),
          ]),
        ),
      ),
    );
  }

  Future<void> _detalleEspacio(BuildContext context, Espacio espacio) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(espacio.nombre,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                  'Estado: ${espacio.visionEnLinea ? espacio.estado : 'SIN CONEXIÓN'}'),
              const SizedBox(height: 12),
              const Text(
                  'La disponibilidad es informativa y puede cambiar. No se realizan reservas desde esta aplicación.',
                  style:
                      TextStyle(fontSize: 12, color: EstacionaYaTokens.muted)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: (espacio.latitud == null || espacio.longitud == null)
                    ? null
                    : () async {
                        Navigator.pop(modalContext);
                        await _opcionesNavegacion(context, espacio);
                      },
                icon: const Icon(Icons.directions_rounded),
                label: const Text('Cómo llegar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _opcionesNavegacion(
      BuildContext context, Espacio espacio) async {
    if (espacio.latitud == null || espacio.longitud == null) return;
    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
          child: Wrap(children: [
        ListTile(title: Text('Cómo llegar a ${espacio.nombre}')),
        ListTile(
            leading: const Icon(Icons.map_rounded),
            title: const Text('Google Maps'),
            onTap: () => Navigator.pop(c, 'google')),
        ListTile(
            leading: const Icon(Icons.navigation_rounded),
            title: const Text('Waze'),
            onTap: () => Navigator.pop(c, 'waze')),
      ])),
    );
    if (opcion == null) return;
    try {
      if (opcion == 'google') {
        await NavigationService.abrirGoogleMaps(
            latitud: espacio.latitud!, longitud: espacio.longitud!);
      } else {
        await NavigationService.abrirWaze(
            latitud: espacio.latitud!, longitud: espacio.longitud!);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir la ruta: $error')));
      }
    }
  }

  Widget _pantallaSecundaria(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (_tabIndex == 1) {
      return SafeArea(
          child: Center(
              child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircleAvatar(
                radius: 32, child: Icon(Icons.person_rounded, size: 32)),
            const SizedBox(height: 16),
            Text(session?.user.email ?? 'Modo visitante',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text('Consulta las zonas azules de Tulcán y Montúfar.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _sesion(context),
              icon: Icon(session == null ? Icons.login : Icons.logout),
              label: Text(session == null ? 'Iniciar sesión' : 'Cerrar sesión'),
            ),
          ]),
        )),
      )));
    }
    return SafeArea(
        child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Ajustes', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const Card(
            child: ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('Acerca de EstacionaYa'),
          subtitle: Text(
              'Información de estacionamientos urbanos en Tulcán y Montúfar.'),
        )),
        const Card(
            child: ListTile(
          leading: Icon(Icons.shield_outlined),
          title: Text('Disponibilidad'),
          subtitle: Text(
              'Consulta informativa basada en datos del sistema. No incluye reservas.'),
        )),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _sesion(context),
          icon: Icon(session == null ? Icons.login : Icons.logout),
          label: Text(session == null ? 'Iniciar sesión' : 'Cerrar sesión'),
        ),
      ],
    ));
  }

  Future<void> _sesion(BuildContext context) async {
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
