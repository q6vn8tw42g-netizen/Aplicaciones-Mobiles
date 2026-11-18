import 'package:estacionaya/models/espacio.dart';
import 'package:estacionaya/providers/espacios_provider.dart';
import 'package:estacionaya/screens/home_screen.dart';
import 'package:estacionaya/services/navigation_service.dart';
import 'package:estacionaya/widgets/mapa_espacios.dart';
import 'package:estacionaya/widgets/parking_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Gps extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async => permission;
  @override
  Future<Position> getCurrentPosition(
          {LocationSettings? locationSettings}) async =>
      Position(
          longitude: -77.7341,
          latitude: .8051,
          timestamp: DateTime.now(),
          accuracy: 8,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0);
}

class _Plazas extends EspaciosProvider {
  void ocupar() {
    espacios = espacios.map((e) => e.copyWith(estado: 'OCUPADO')).toList();
    notifyListeners();
  }
}

void main() {
  final ejemplo = Espacio(
      id: 'ejemplo',
      nombre: 'ANT-001',
      camaraId: 'CAM-005',
      estado: 'LIBRE',
      latitud: .80525,
      longitud: -77.73434,
      actualizadoEn: DateTime.utc(2026));

  Future<_Plazas> inicio(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1040, 780);
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    final p = _Plazas()
      ..cargando = false
      ..espacios = [ejemplo];
    await t.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<EspaciosProvider>(
            create: (_) => p, child: const HomeScreen())));
    await t.pumpAndSettle();
    return p;
  }

  testWidgets('Mi ubicación centra el mapa y la selección centra la plaza',
      (t) async {
    final antes = GeolocatorPlatform.instance;
    final gps = _Gps();
    GeolocatorPlatform.instance = gps;
    addTearDown(() => GeolocatorPlatform.instance = antes);
    await inicio(t);
    MapaEspacios mapa() => t.widget(find.byType(MapaEspacios));
    gps.enabled = false;
    await t.tap(find.text('Mi ubicación'));
    await t.pumpAndSettle();
    expect(mapa().ubicacionUsuario, isNull);
    expect(find.textContaining('Activa el GPS'), findsOneWidget);
    gps.enabled = true;
    gps.permission = LocationPermission.denied;
    await t.tap(find.text('Mi ubicación'));
    await t.pumpAndSettle();
    expect(mapa().ubicacionUsuario, isNull);
    gps.permission = LocationPermission.whileInUse;
    await t.tap(find.text('Mi ubicación'));
    await t.pumpAndSettle();
    expect(mapa().ubicacionUsuario?.latitude, .8051);
    expect(mapa().foco, mapa().ubicacionUsuario);
    expect(
        t
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!
            .camera
            .center
            .latitude,
        closeTo(.8051, .000001));
    expect(find.textContaining('aprox. en línea recta'), findsOneWidget);
    await t.tap(find.text('ANT-001'));
    await t.pumpAndSettle();
    expect(mapa().foco?.longitude, ejemplo.longitud);
    expect(
        t
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!
            .camera
            .center
            .longitude,
        closeTo(ejemplo.longitud!, .000001));
    expect(find.text('Navegar'), findsOneWidget);
  });

  testWidgets('Una plaza ocupada durante la elección desactiva ambos destinos',
      (t) async {
    final p = await inicio(t);
    await t.tap(find.text('ANT-001'));
    await t.pumpAndSettle();
    await t.tap(find.text('Navegar'));
    await t.pumpAndSettle();
    for (final nombre in ['Google Maps', 'Waze']) {
      expect(t.widget<ListTile>(find.widgetWithText(ListTile, nombre)).enabled,
          isTrue);
    }
    p.ocupar();
    await t.pumpAndSettle();
    for (final nombre in ['Google Maps', 'Waze']) {
      expect(t.widget<ListTile>(find.widgetWithText(ListTile, nombre)).onTap,
          isNull);
    }
  });

  testWidgets(
      'Los dos navegadores usan las coordenadas exactas en su alternativa web',
      (t) async {
    const canal = MethodChannel('plugins.flutter.io/url_launcher');
    final urls = <Uri>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const android = MethodChannel('estacionaya/navigation');
    messenger.setMockMethodCallHandler(android, (call) async => false);
    addTearDown(() => messenger.setMockMethodCallHandler(android, null));
    messenger.setMockMethodCallHandler(canal, (call) async {
      if (call.method == 'canLaunch') return false;
      urls.add(Uri.parse(call.arguments['url'] as String));
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(canal, null));
    await NavigationService.abrirGoogleMaps(
        latitud: ejemplo.latitud!, longitud: ejemplo.longitud!);
    await NavigationService.abrirWaze(
        latitud: ejemplo.latitud!, longitud: ejemplo.longitud!);
    expect(urls.first.queryParameters['destination'], '0.80525,-77.73434');
    expect(urls.last.queryParameters['ll'], '0.80525,-77.73434');
    expect(urls.last.queryParameters['navigate'], 'yes');
  });

  testWidgets(
      'La opción Google Maps envía el destino seleccionado al host Android',
      (t) async {
    const channel = MethodChannel('estacionaya/navigation');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? enviada;
    messenger.setMockMethodCallHandler(channel, (call) async {
      enviada = call;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await inicio(t);
    await t.tap(find.text('ANT-001'));
    await t.pumpAndSettle();
    await t.tap(find.text('Navegar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Google Maps'));
    await t.pumpAndSettle();
    expect(enviada?.method, 'openGoogleMaps');
    expect(enviada?.arguments['latitude'], ejemplo.latitud);
    expect(enviada?.arguments['longitude'], ejemplo.longitud);
  });

  test('Una señal insuficiente nunca presenta una plaza como libre', () {
    expect(estadoVisible(ejemplo, sincronizado: false), 'NO_VERIFICADO');
    expect(
        estadoVisible(ejemplo.copyWith(visionEnLinea: false),
            sincronizado: true),
        'SIN_SERVICIO');
    final sinEvidencia = Espacio(
        id: 'otro',
        nombre: 'Prueba',
        camaraId: 'CAM-999',
        estado: 'LIBRE',
        actualizadoEn: DateTime.utc(2026));
    expect(estadoVisible(sinEvidencia, sincronizado: true), 'NO_VERIFICADO');
  });
}
