import 'dart:async';

import 'package:estacionaya/models/espacio.dart';
import 'package:estacionaya/providers/espacios_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fila({String estado = 'LIBRE'}) => {
      'id': '12ef96b1-6ba5-4f08-9826-39e85cf09637',
      'codigo': 'Parque Central de Tulcán',
      'camara_id': 'CAM-001',
      'estado': estado,
      'lat': 0.8119,
      'lng': -77.7173,
      'updated_at': '2026-09-17T12:00:00Z',
    };

Future<void> emitir(
  StreamController<List<Map<String, dynamic>>> controller,
  List<Map<String, dynamic>> filas,
) async {
  controller.add(filas);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('mapea UUID, nombres SQL, coordenadas numéricas y fecha UTC', () {
    final espacio = Espacio.fromMap({...fila(), 'lat': 0});
    expect(espacio.id, fila()['id']);
    expect(espacio.nombre, 'Parque Central de Tulcán');
    expect(espacio.latitud, 0.0);
    expect(espacio.longitud, -77.7173);
    expect(espacio.actualizadoEn.isUtc, isTrue);
    expect(espacio.copyWith(estado: 'OCUPADO').id, espacio.id);
  });

  test('notifica carga inicial, actualización, inserción y eliminación',
      () async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    final provider = EspaciosProvider(espaciosStream: controller.stream);
    var notificaciones = 0;
    provider.addListener(() => notificaciones++);
    await provider.iniciar();
    await provider.iniciar(); // No crea una segunda escucha.
    expect(provider.cargando, isTrue);
    await emitir(controller, [fila()]);
    expect(provider.espacios.single.estado, 'LIBRE');
    expect(provider.cargando, isFalse);
    await emitir(controller, [fila(estado: 'OCUPADO')]);
    expect(provider.espacios.single.estado, 'OCUPADO');
    await emitir(controller, [
      fila(),
      {...fila(), 'id': 'otro-uuid'}
    ]);
    expect(provider.espacios.length, 2);
    await emitir(controller, []);
    expect(provider.espacios, isEmpty);
    expect(notificaciones, 5);
    provider.dispose();
    expect(controller.hasListener, isFalse);
    await controller.close();
  });

  test('expone errores y se recupera cuando llegan nuevos datos', () async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    final provider = EspaciosProvider(espaciosStream: controller.stream);
    await provider.iniciar();
    await emitir(controller, [fila()]);
    controller.addError(StateError('Conexión interrumpida'));
    await Future<void>.delayed(Duration.zero);
    expect(provider.error, isNotNull);
    expect(provider.cargando, isFalse);
    expect(provider.espacios.length, 1);
    await emitir(controller, [fila(estado: 'RESERVADO')]);
    expect(provider.error, isNull);
    expect(provider.espacios.single.estado, 'RESERVADO');
    provider.dispose();
    await controller.close();
  });

  test('un registro inválido se informa como error de sincronización',
      () async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    final provider = EspaciosProvider(espaciosStream: controller.stream);
    await provider.iniciar();
    await emitir(controller, [
      {...fila(), 'updated_at': 'fecha inválida'}
    ]);
    expect(provider.error, isNotNull);
    expect(provider.cargando, isFalse);
    await emitir(controller, [fila()]);
    expect(provider.error, isNull);
    provider.dispose();
    await controller.close();
  });
}
