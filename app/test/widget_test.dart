import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estacionaya/models/espacio.dart';
import 'package:estacionaya/widgets/espacio_card.dart';

void main() {
  testWidgets('muestra el estado del espacio y oculta controles de validador',
      (WidgetTester tester) async {
    final espacio = Espacio(
      id: 'a6241890-e1ac-4b86-8a2f-bdb01f9fcb50',
      nombre: 'Parque Central de Tulcán',
      camaraId: 'CAM-001',
      estado: 'LIBRE',
      latitud: 0.8119,
      longitud: -77.7173,
      actualizadoEn: DateTime.utc(2026, 10, 24),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EspacioCard(espacio: espacio, onReportar: (_) {})),
    ));
    expect(find.text('Parque Central de Tulcán'), findsOneWidget);
    expect(find.text('Libre'), findsOneWidget);
    expect(find.text('Navegar'), findsOneWidget);
    expect(find.text('Me estacioné'), findsOneWidget);
    expect(find.text('Forzar estado'), findsNothing);
  });

  testWidgets('muestra CAM-001 en gris cuando no recibe heartbeat',
      (WidgetTester tester) async {
    final espacio = Espacio(
      id: 'a6241890-e1ac-4b86-8a2f-bdb01f9fcb50',
      nombre: 'Parque Central de Tulcán',
      camaraId: 'CAM-001',
      estado: 'OCUPADO',
      latitud: 0.8119,
      longitud: -77.7173,
      actualizadoEn: DateTime.utc(2026, 10, 24),
      visionEnLinea: false,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: EspacioCard(espacio: espacio, onReportar: (_) {})),
    ));
    expect(find.text('Sin servicio'), findsOneWidget);
    expect(find.text('Cámara sin conexión; estado no actualizado.'),
        findsOneWidget);
  });
}
