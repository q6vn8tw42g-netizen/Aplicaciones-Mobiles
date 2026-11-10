import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/tramos_geometria.dart';
import '../data/zonas_azules_oficiales.dart';
import '../models/espacio.dart';
import '../providers/espacios_provider.dart';
import '../services/navigation_service.dart';
import '../theme/estacionaya_theme.dart';
import '../widgets/mapa_espacios.dart';
import 'login_screen.dart';

/// Inicio urbano sin reservas. El catálogo documental y la disponibilidad real
/// se muestran por separado para no confundir tramos con plazas libres.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Ciudad { tulcan, montufar }
enum _Vista { catalogo, monitoreados }

class _HomeScreenState extends State<HomeScreen> {
  static const _tulcan = ll.LatLng(0.80525, -77.73434);
  static const _montufar = ll.LatLng(0.59354, -77.83066);
  static const _dist = ll.Distance();
  static const _radioMetros = 12000.0;

  final _buscar = TextEditingController();
  _Ciudad _ciudad = _Ciudad.tulcan;
  _Vista _vista = _Vista.catalogo;
  ll.LatLng? _ubicacion;
  bool _buscandoUbicacion = false;
  String _consulta = '';
  int _tab = 0;
  String? _seleccionado;
  bool _soloCercanos = false;

  bool get _esMontufar => _ciudad == _Ciudad.montufar;
  String get _nombreCiudad => _esMontufar ? 'Montúfar' : 'Tulcán';
  ll.LatLng get _centro => _esMontufar ? _montufar : _tulcan;
  List<TramoZonaAzul> get _catalogo => _esMontufar
      ? CatalogoZonasAzules.montufar
      : CatalogoZonasAzules.tulcan;
  List<TramoGeo> get _geometrias => GeometriasZonaAzul.tramos
      .where((t) => t.localidad == _nombreCiudad && t.puntos.length >= 2)
      .toList();

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  void _cambiarCiudad(_Ciudad ciudad) {
    if (ciudad == _ciudad) return;
    setState(() {
      _ciudad = ciudad;
      _seleccionado = null;
      _soloCercanos = false;
      _consulta = '';
      _buscar.clear();
    });
  }

  List<Espacio> _espacios(List<Espacio> registros) {
    final filtrados = registros.where((e) {
      if (e.latitud == null || e.longitud == null) return false;
      final punto = ll.LatLng(e.latitud!, e.longitud!);
      if (_dist.as(ll.LengthUnit.Meter, _centro, punto) > _radioMetros) {
        return false;
      }
      if (_soloCercanos && _ubicacion != null &&
          _dist.as(ll.LengthUnit.Meter, _ubicacion!, punto) > 2000) {
        return false;
      }
      final texto = '${e.nombre} ${e.camaraId}'.toLowerCase();
      return texto.contains(_consulta.toLowerCase().trim());
    }).toList();
    if (_ubicacion != null) {
      filtrados.sort((a, b) {
        final da = _dist.as(ll.LengthUnit.Meter, _ubicacion!,
            ll.LatLng(a.latitud!, a.longitud!));
        final db = _dist.as(ll.LengthUnit.Meter, _ubicacion!,
            ll.LatLng(b.latitud!, b.longitud!));
        return da.compareTo(db);
      });
    }
    return filtrados;
  }

  List<TramoZonaAzul> get _tramosFiltrados {
    final q = _consulta.toLowerCase().trim();
    return _catalogo.where((t) =>
      '${t.calle} ${t.desde} ${t.hasta}'.toLowerCase().contains(q)).toList();
  }

  Future<void> _localizar() async {
    if (_buscandoUbicacion) return;
    setState(() => _buscandoUbicacion = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Activa la ubicación del dispositivo.');
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        throw Exception('No se concedió acceso a la ubicación.');
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _ubicacion = ll.LatLng(pos.latitude, pos.longitude);
          _soloCercanos = true;
          _vista = _Vista.monitoreados;
        });
        _aviso('Se muestran espacios monitoreados a menos de 2 km.');
      }
    } catch (e) {
      if (mounted) _aviso('$e');
    } finally {
      if (mounted) setState(() => _buscandoUbicacion = false);
    }
  }

  void _aviso(String mensaje) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(mensaje)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tab == 0 ? _mapaPrincipal() : _paginaSecundaria(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map), label: 'Zonas'),
          NavigationDestination(icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person), label: 'Perfil'),
          NavigationDestination(icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }

  Widget _mapaPrincipal() => Consumer<EspaciosProvider>(
    builder: (context, provider, _) {
      final espacios = _espacios(provider.espaciosVisibles);
      final ancho = MediaQuery.sizeOf(context).width;
      final esWebAncha = ancho >= 900;
      final mapa = Stack(children: [
        Positioned.fill(child: MapaEspacios(
          key: ValueKey(_ciudad),
          centroInicial: _centro,
          espacios: espacios,
          tramosAzules: _geometrias,
          espacioSeleccionadoId: _seleccionado,
          onEspacioSeleccionado: (e) {
            setState(() => _seleccionado = e.id);
            _detalleEspacio(e);
          },
        )),
        Positioned(
          top: 0, left: 12, right: 12,
          child: SafeArea(bottom: false, child: _encabezado()),
        ),
        Positioned(
          right: 14, bottom: esWebAncha ? 24 : 30,
          child: FloatingActionButton.small(
            heroTag: 'ubicar',
            tooltip: 'Buscar espacios monitoreados cercanos',
            onPressed: _buscandoUbicacion ? null : _localizar,
            child: _buscandoUbicacion
                ? const Padding(padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded),
          ),
        ),
        if (_geometrias.isEmpty)
          Positioned(
            left: 12, bottom: esWebAncha ? 24 : 30,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .93),
                borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('Trazados azules pendientes de georreferenciar',
                    style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
      ]);
      if (esWebAncha) {
        return Row(children: [
          SizedBox(width: 430, child: _panel(provider, espacios, web: true)),
          Expanded(child: mapa),
        ]);
      }
      return Stack(children: [
        Positioned.fill(child: mapa),
        DraggableScrollableSheet(
          initialChildSize: .43,
          minChildSize: .19,
          maxChildSize: .88,
          snap: true,
          builder: (context, scroll) => _panel(provider, espacios, scroll: scroll),
        ),
      ]);
    },
  );

  Widget _encabezado() => Card(
    elevation: 3,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: EstacionaYaTokens.primary,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_parking, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EstacionaYa', style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w800)),
              Text('Zonas azules · Carchi',
                  style: TextStyle(fontSize: 12, color: EstacionaYaTokens.muted)),
            ],
          )),
          IconButton(onPressed: () => setState(() => _tab = 1),
            icon: const Icon(Icons.account_circle_outlined)),
        ]),
        const SizedBox(height: 10),
        SegmentedButton<_Ciudad>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _Ciudad.tulcan, label: Text('Tulcán')),
            ButtonSegment(value: _Ciudad.montufar, label: Text('Montúfar')),
          ],
          selected: {_ciudad},
          onSelectionChanged: (val) => _cambiarCiudad(val.first),
        ),
      ]),
    ),
  );

  Widget _panel(EspaciosProvider provider, List<Espacio> espacios,
      {bool web = false, ScrollController? scroll}) {
    final catalogo = _tramosFiltrados;
    final disponibles = espacios.where((e) =>
        e.visionEnLinea && e.estado == 'LIBRE').length;
    return Container(
      decoration: BoxDecoration(
        color: EstacionaYaTokens.surface,
        borderRadius: web ? null : const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Color(0x200F172A), blurRadius: 18)],
      ),
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (!web) Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: EstacionaYaTokens.outline,
              borderRadius: BorderRadius.circular(6)))),
          const SizedBox(height: 12),
          Text('Explora $_nombreCiudad',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${_catalogo.length} tramos de catálogo · ${espacios.length} espacios monitoreados visibles',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _buscar,
            onChanged: (s) => setState(() => _consulta = s),
            decoration: InputDecoration(
              hintText: 'Buscar calle, intersección o espacio',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _consulta.isEmpty ? null : IconButton(
                onPressed: () { _buscar.clear(); setState(() => _consulta = ''); },
                icon: const Icon(Icons.close)),
              filled: true,
              fillColor: EstacionaYaTokens.canvas,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<_Vista>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: _Vista.catalogo, label: Text('Zonas azules')),
              ButtonSegment(value: _Vista.monitoreados, label: Text('En vivo')),
            ],
            selected: {_vista},
            onSelectionChanged: (v) => setState(() => _vista = v.first),
          ),
          const SizedBox(height: 14),
          if (_vista == _Vista.catalogo) ...[
            _nota('Catálogo histórico de calles reguladas. No indica plazas libres. Verifica la señalización vigente.'),
            const SizedBox(height: 8),
            if (catalogo.isEmpty)
              const ListTile(title: Text('No se encontraron calles con ese nombre.')),
            for (final tramo in catalogo) _tarjetaTramo(tramo),
          ] else ...[
            _nota(provider.error != null
                ? 'No se pudo actualizar Supabase. Revisa la conexión.'
                : espacios.isEmpty
                  ? 'No hay datos de ocupación para esta consulta. No significa que las calles estén llenas.'
                  : '$disponibles espacios confirmados libres entre ${espacios.length} registros visibles.'),
            const SizedBox(height: 8),
            if (_soloCercanos)
              InputChip(
                label: const Text('A menos de 2 km de mí'),
                avatar: const Icon(Icons.my_location, size: 18),
                onDeleted: () => setState(() => _soloCercanos = false),
              ),
            if (provider.cargando) const LinearProgressIndicator(),
            if (espacios.isEmpty && !provider.cargando)
              const ListTile(leading: Icon(Icons.wifi_off_outlined),
                  title: Text('Sin espacios monitoreados disponibles')),
            for (final e in espacios) _tarjetaEspacio(e),
          ],
        ],
      ),
    );
  }

  Widget _nota(String texto) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: EstacionaYaTokens.primarySoft,
      borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      const Icon(Icons.info_outline, color: EstacionaYaTokens.primary, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(texto, style: const TextStyle(fontSize: 12))),
    ]),
  );

  Widget _tarjetaTramo(TramoZonaAzul tramo) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: EstacionaYaTokens.primarySoft,
        child: const Icon(Icons.route, color: EstacionaYaTokens.primary)),
      title: Text(tramo.calle, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('Entre ${tramo.desde} y ${tramo.hasta}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _detalleTramo(tramo),
    ),
  );

  void _detalleTramo(TramoZonaAzul tramo) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tramo.calle, style: Theme.of(ctx).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text('Entre ${tramo.desde} y ${tramo.hasta} · ${tramo.localidad}'),
        const SizedBox(height: 18),
        const ListTile(contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.payments_outlined),
          title: Text('Tarifa'), subtitle: Text('Por confirmar con el municipio')),
        const ListTile(contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.schedule_outlined),
          title: Text('Horario'), subtitle: Text('Por confirmar con el municipio')),
        const ListTile(contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('Disponibilidad'), subtitle: Text('Sin monitorización individual')),
        const SizedBox(height: 8),
        const Text('Información referencial basada en ordenanzas anteriores. '
          'Confirma señalización, horarios y tarifas vigentes en la vía.',
          style: TextStyle(fontSize: 12, color: EstacionaYaTokens.muted)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            final uri = Uri.https('www.google.com', '/maps/search/',
                {'api': '1', 'query': tramo.busqueda});
            if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
              _aviso('No se pudo abrir Google Maps.');
            }
          },
          icon: const Icon(Icons.map_outlined),
          label: const Text('Buscar este tramo en Google Maps'),
        ),
      ]),
    )),
  );

  Widget _tarjetaEspacio(Espacio e) {
    final estado = e.visionEnLinea ? e.estado : 'SIN SERVICIO';
    final color = estado == 'LIBRE'
        ? EstacionaYaTokens.available
        : estado == 'OCUPADO'
            ? EstacionaYaTokens.occupied
            : EstacionaYaTokens.offline;
    String? distancia;
    if (_ubicacion != null && e.latitud != null && e.longitud != null) {
      final metros = _dist.as(ll.LengthUnit.Meter, _ubicacion!,
          ll.LatLng(e.latitud!, e.longitud!));
      distancia = metros < 1000
          ? '${metros.round()} m de ti'
          : '${(metros / 1000).toStringAsFixed(1)} km de ti';
    }
    return Card(child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: .12),
          child: Icon(Icons.local_parking, color: color)),
      title: Text(e.nombre),
      subtitle: Text('$estado${distancia == null ? '' : ' · $distancia'}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _detalleEspacio(e),
    ));
  }

  void _detalleEspacio(Espacio e) => showModalBottomSheet<void>(
    context: context, showDragHandle: true,
    builder: (ctx) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(e.nombre, style: Theme.of(ctx).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('Estado: ${e.visionEnLinea ? e.estado : 'SIN CONEXIÓN'}'),
        const SizedBox(height: 10),
        const Text('La ocupación puede cambiar. Esta aplicación no permite reservas.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: (e.latitud == null || e.longitud == null) ? null : () async {
            Navigator.pop(ctx);
            await NavigationService.abrirGoogleMaps(
              latitud: e.latitud!, longitud: e.longitud!);
          },
          icon: const Icon(Icons.directions), label: const Text('Cómo llegar'),
        ),
      ]),
    )),
  );

  Widget _paginaSecundaria() {
    final session = Supabase.instance.client.auth.currentSession;
    return SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        Text(_tab == 1 ? 'Mi perfil' : 'Ajustes',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (_tab == 1) ...[
          Card(child: ListTile(leading: const Icon(Icons.person_outline),
              title: Text(session?.user.email ?? 'Modo visitante'),
              subtitle: const Text('EstacionaYa · Carchi'))),
        ] else ...[
          const Card(child: ListTile(leading: Icon(Icons.info_outline),
              title: Text('Acerca de EstacionaYa'),
              subtitle: Text('Consulta de zonas azules en Tulcán y Montúfar.'))),
          const Card(child: ListTile(leading: Icon(Icons.shield_outlined),
              title: Text('Información responsable'),
              subtitle: Text('No ofrece reservas. Los tramos documentados no implican disponibilidad real.'))),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: _sesion,
          icon: Icon(session == null ? Icons.login : Icons.logout),
          label: Text(session == null ? 'Iniciar sesión' : 'Cerrar sesión')),
      ]),
    )));
  }

  Future<void> _sesion() async {
    final auth = Supabase.instance.client.auth;
    if (auth.currentSession == null) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const LoginScreen()));
    } else {
      await auth.signOut();
    }
    if (mounted) setState(() {});
  }
}
