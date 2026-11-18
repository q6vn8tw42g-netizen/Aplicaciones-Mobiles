import 'dart:io';

import 'package:estacionaya/models/espacio.dart';
import 'package:estacionaya/screens/login_screen.dart';
import 'package:estacionaya/screens/register_screen.dart';
import 'package:estacionaya/theme/estacionaya_theme.dart';
import 'package:estacionaya/widgets/camera_connection_badge.dart';
import 'package:estacionaya/widgets/availability_strip.dart';
import 'package:estacionaya/widgets/parking_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> badge(WidgetTester tester, String cameraId, bool online,
      {bool error = false, bool loading = false}) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CameraConnectionBadge(
                cameraId: cameraId,
                visionEnLinea: online,
                cargando: loading,
                errorSincronizacion: error))));
  }

  testWidgets('An unknown camera never inherits an active connection',
      (t) async {
    await badge(t, 'CAM-999', true);
    expect(find.text('Conexión no verificada'), findsOneWidget);
    expect(find.text('Cámara activa'), findsNothing);
  });

  testWidgets('Verified heartbeat flags are the only source of active status',
      (t) async {
    for (final id in ['CAM-001', 'CAM-005']) {
      await badge(t, id, true);
      expect(find.text('Cámara activa'), findsOneWidget);
      await badge(t, id, false);
      expect(find.text('Sin señal vigente'), findsOneWidget);
    }
  });

  testWidgets('Loading or synchronization errors invalidate a green badge',
      (t) async {
    await badge(t, 'CAM-005', true, error: true);
    expect(find.text('Conexión no verificada'), findsOneWidget);
    await badge(t, 'CAM-005', true, loading: true);
    expect(find.text('Conexión no verificada'), findsOneWidget);
  });

  testWidgets(
      'Cards remain usable at 320px with large text and preserve their action',
      (t) async {
    await t.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    var taps = 0;
    final espacio = Espacio(
        id: 'local-test',
        nombre: 'Espacio con nombre largo de prueba',
        camaraId: 'CAM-005',
        estado: 'LIBRE',
        visionEnLinea: true,
        actualizadoEn: DateTime(2026, 11, 11, 10),
        tipoVehiculo: 'AUTO');
    await t.pumpWidget(MaterialApp(
        theme: EstacionaYaTheme.light,
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
                body: SingleChildScrollView(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ParkingSummaryCard(
                            espacio: espacio,
                            color: EstacionaYaTokens.available,
                            estado: 'DISPONIBLE',
                            tieneDestino: false,
                            onTap: () => taps++)))))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.tap(find.text(espacio.nombre));
    expect(taps, 1);
    expect(find.text('Ubicación pendiente'), findsOneWidget);
  });

  testWidgets('Auth screens fit narrow viewports and a visible keyboard',
      (t) async {
    await t.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => t.binding.setSurfaceSize(null));
    for (final screen in [const LoginScreen(), const RegisterScreen()]) {
      await t.pumpWidget(MaterialApp(
          theme: EstacionaYaTheme.light,
          home: MediaQuery(
              data: const MediaQueryData(
                  textScaler: TextScaler.linear(1.5),
                  viewInsets: EdgeInsets.only(bottom: 280)),
              child: screen)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('Component preview and reduced motion render without overflow',
      (t) async {
    if (const bool.fromEnvironment('UI_PREVIEW')) {
      await t.runAsync(() async {
        final font = File('C:/Windows/Fonts/segoeui.ttf');
        if (await font.exists()) {
          final loader = FontLoader('Roboto')
            ..addFont(font
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)));
          await loader.load();
        }
        final icons = File(
            'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
        if (await icons.exists()) {
          final loader = FontLoader('MaterialIcons')
            ..addFont(icons
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)));
          await loader.load();
        }
      });
    }
    await t.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    Espacio espacio(String id, String estado) => Espacio(
        id: id,
        nombre: id,
        camaraId: 'CAM-005',
        estado: estado,
        actualizadoEn: DateTime(2026, 11, 11, 10));
    await t.pumpWidget(MaterialApp(
        theme: EstacionaYaTheme.light,
        home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
                body: RepaintBoundary(
                    key: const Key('preview'),
                    child: ColoredBox(
                        color: EstacionaYaTokens.canvas,
                        child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              const SizedBox(height: 24),
                              Text('EstacionaYa',
                                  style: EstacionaYaTheme
                                      .light.textTheme.headlineSmall),
                              const Text('Vista previa · datos de prueba'),
                              const SizedBox(height: 20),
                              const AvailabilityStrip(
                                  total: 2,
                                  libres: 1,
                                  ocupados: 1,
                                  confirmado: true),
                              const SizedBox(height: 12),
                              for (final estado in ['LIBRE', 'OCUPADO'])
                                ParkingSummaryCard(
                                    espacio: espacio(
                                        estado == 'LIBRE'
                                            ? 'ANT-001'
                                            : 'ANT-002',
                                        estado),
                                    color: estado == 'LIBRE'
                                        ? EstacionaYaTokens.available
                                        : EstacionaYaTokens.occupied,
                                    estado:
                                        estado == 'LIBRE' ? 'Libre' : 'Ocupado',
                                    tieneDestino: true,
                                    onTap: () {}),
                              const CameraConnectionBadge(
                                  cameraId: 'CAM-999', visionEnLinea: true),
                            ])))))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    if (const bool.fromEnvironment('UI_PREVIEW')) {
      await expectLater(
          find.byKey(const Key('preview')),
          matchesGoldenFile(
              '../../output/ux_conductor/fichas_datos_de_prueba.png'));
    }
  });
}
