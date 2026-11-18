import 'package:estacionaya/providers/espacios_provider.dart';
import 'package:estacionaya/screens/home_screen.dart';
import 'package:estacionaya/screens/login_screen.dart';
import 'package:estacionaya/theme/estacionaya_theme.dart';
import 'package:estacionaya/widgets/estacionaya_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://offline-test.example',
        publishableKey: 'offline-widget-test',
        debug: false,
        httpClient: MockClient((request) async {
          throw StateError('Esta prueba no permite conexiones externas.');
        }),
        authOptions: const FlutterAuthClientOptions(
            localStorage: EmptyLocalStorage(),
            autoRefreshToken: false,
            detectSessionInUri: false));
  });

  tearDownAll(() => Supabase.instance.dispose());

  Future<void> home(WidgetTester tester,
      {double textScale = 1, bool loading = false, String? error}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
        theme: EstacionaYaTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                disableAnimations: true),
            child: child!),
        home: ChangeNotifierProvider<EspaciosProvider>(
            create: (_) => EspaciosProvider()
              ..cargando = loading
              ..error = error,
            child: const HomeScreen())));
    // El provider no se inicia: no hay streams ni conexiones de datos reales.
    if (loading) {
      await tester.pump(const Duration(milliseconds: 200));
    } else {
      await tester.pumpAndSettle();
    }
  }

  testWidgets('Panel conserva arrastre, búsqueda y estado vacío en móvil',
      (tester) async {
    await home(tester);
    final sheet = tester.widget<DraggableScrollableSheet>(
        find.byType(DraggableScrollableSheet));
    expect(sheet.initialChildSize, .36);
    await tester.drag(
        find.text('Estacionamientos disponibles'), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(sheet.controller!.size, greaterThan(.36));
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sin resultados');
    await tester.pumpAndSettle();
    expect(find.text('Sin coincidencias'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Sin espacios en esta zona'), findsOneWidget);
  });

  testWidgets('Perfil y ajustes se adaptan a 320 px con texto ampliado',
      (tester) async {
    await home(tester, textScale: 2);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Modo visitante'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Iniciar sesión'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(LoginScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Acerca de EstacionaYa'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tu ubicación'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Información de monitoreo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('Carga y error no muestran el estado sin resultados',
      (tester) async {
    await home(tester, loading: true);
    tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .controller!
        .jumpTo(.95);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Consultando disponibilidad…'), findsOneWidget);
    expect(find.byType(ParkingEmptyState), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await home(tester, error: 'Sin conexión de prueba');
    tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .controller!
        .jumpTo(.95);
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo actualizar'), findsOneWidget);
    expect(find.byType(ParkingEmptyState), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tarjeta de sesión admite correo largo y movimiento reducido',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const email = 'cuenta.con.nombre.muy.largo@ejemplo.test';
    await tester.pumpWidget(MaterialApp(
        theme: EstacionaYaTheme.light,
        home: const MediaQuery(
            data: MediaQueryData(
                textScaler: TextScaler.linear(2), disableAnimations: true),
            child: Scaffold(
                body: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: EstacionaYaProfileCard(
                        title: 'Sesión iniciada', description: email))))));
    expect(find.text(email), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

