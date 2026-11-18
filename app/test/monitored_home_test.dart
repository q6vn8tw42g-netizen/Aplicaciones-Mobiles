import 'dart:async';

import 'package:estacionaya/providers/espacios_provider.dart';
import 'package:estacionaya/screens/home_screen.dart';
import 'package:estacionaya/theme/estacionaya_theme.dart';
import 'package:estacionaya/widgets/availability_strip.dart';
import 'package:estacionaya/widgets/mapa_espacios.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Resumen estrecho con texto grande y datos pendientes',
      (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SizedBox(
                    width: 280,
                    child: AvailabilityStrip(
                        total: 3,
                        libres: 1,
                        ocupados: 1,
                        confirmado: false))))));
    expect(find.text('—'), findsNWidgets(3));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Inicio, detalle abierto y conteos siguen los cambios del provider',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final filas = StreamController<List<Map<String, dynamic>>>();
    final senales = StreamController<List<Map<String, dynamic>>>();
    final provider = EspaciosProvider(
        espaciosStream: filas.stream, heartbeatStream: senales.stream);
    await provider.iniciar();
    addTearDown(() async {
      await filas.close();
      await senales.close();
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(1000, 760);
    await t.pumpWidget(MaterialApp(
        theme: EstacionaYaTheme.light,
        home: ChangeNotifierProvider(
            create: (_) => provider, child: const HomeScreen())));
    final ahora = DateTime.now().toUtc().toIso8601String();
    final fila = {
      'id': 'a',
      'codigo': 'ANT-001',
      'camara_id': 'CAM-005',
      'estado': 'LIBRE',
      'updated_at': ahora
    };
    senales.add([
      {'camara_id': 'CAM-005', 'ultimo_contacto': ahora}
    ]);
    filas.add([fila]);
    await t.pump();
    await t.pump();
    expect(find.text('Estacionamientos disponibles'), findsOneWidget);
    expect(find.text('Zonas azules'), findsNothing);
    expect(t.widget<MapaEspacios>(find.byType(MapaEspacios)).espacios, isEmpty);
    expect(
        t.widget<AvailabilityStrip>(find.byType(AvailabilityStrip)).libres, 1);
    await t.tap(find.text('ANT-001'));
    await t.pumpAndSettle();
    expect(find.text('Última actualización'), findsOneWidget);
    filas.add([
      {...fila, 'estado': 'OCUPADO'}
    ]);
    await t.pump();
    await t.pumpAndSettle();
    expect(find.text('Ocupado'), findsNWidgets(2));
    expect(t.widget<AvailabilityStrip>(find.byType(AvailabilityStrip)).ocupados,
        1);
    senales.add([]);
    await t.pump();
    await t.pumpAndSettle();
    expect(find.text('Sin señal vigente'), findsNWidgets(2));
    expect(t.widget<AvailabilityStrip>(find.byType(AvailabilityStrip)).ocupados,
        0);
    Navigator.of(t.element(find.text('Última actualización'))).pop();
    await t.pumpAndSettle();
    filas.add([
      {...fila, 'lat': 0.80525, 'lng': -77.73434},
      {
        ...fila,
        'id': 'b',
        'codigo': 'ANT-002',
        'lat': 0.80525,
        'lng': -77.73434
      }
    ]);
    await t.pump();
    await t.pumpAndSettle();
    await t.tap(
        find.byTooltip('Estacionamientos Antisana · toca para ver cada plaza'));
    await t.pumpAndSettle();
    expect(find.text('Estacionamientos Antisana'), findsOneWidget);
    filas.add([]);
    await t.pump();
    await t.pumpAndSettle();
    expect(
        find.text('Ya no hay plazas visibles en este grupo.'), findsOneWidget);
    Navigator.of(t.element(find.text('Estacionamientos Antisana'))).pop();
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(320, 640);
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Tulcán'), findsNothing);
    expect(find.text('Montúfar'), findsNothing);
    expect(find.text('Catálogo de calles'), findsNothing);
    expect(find.text('Calles documentadas'), findsNothing);
    expect(find.text('Estacionamientos disponibles'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
}

