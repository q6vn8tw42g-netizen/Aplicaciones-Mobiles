import 'dart:convert';

import 'package:latlong2/latlong.dart' as ll;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/tramos_geometria.dart';

/// Guarda geometrías dibujadas manualmente EN ESTE DISPOSITIVO.
/// Para compartir con todos los usuarios, exportar y revisar las coordenadas
/// antes de incorporarlas a GeometriasZonaAzul.tramos en el código fuente.
class TramosLocalesService {
  static const _clave = 'estacionaya_tramos_georreferenciados_v1';

  static Future<List<TramoGeo>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clave);
    if (raw == null || raw.isEmpty) return [];
    try {
      final parsed = jsonDecode(raw) as List<dynamic>;
      return parsed.map((item) {
        final map = item as Map<String, dynamic>;
        return TramoGeo(
          id: map['id'] as String,
          localidad: map['localidad'] as String,
          calle: map['calle'] as String,
          puntos: (map['puntos'] as List<dynamic>)
              .map((v) => ll.LatLng((v[0] as num).toDouble(),
                  (v[1] as num).toDouble()))
              .toList(),
        );
      }).where((t) => t.puntos.length >= 2).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> guardar(List<TramoGeo> tramos) async {
    final prefs = await SharedPreferences.getInstance();
    final data = tramos.map((t) => {
      'id': t.id,
      'localidad': t.localidad,
      'calle': t.calle,
      'puntos': t.puntos.map((p) => [p.latitude, p.longitude]).toList(),
    }).toList();
    await prefs.setString(_clave, jsonEncode(data));
  }

  /// Texto Dart que puedes pegar en la lista GeometriasZonaAzul.tramos.
  static String exportarDart(List<TramoGeo> tramos) => tramos.map((t) {
    final puntos = t.puntos.map((p) =>
      'll.LatLng(${p.latitude.toStringAsFixed(7)}, ${p.longitude.toStringAsFixed(7)})'
    ).join(', ');
    return 'TramoGeo(id: ${jsonEncode(t.id)}, '
           'localidad: ${jsonEncode(t.localidad)}, '
           'calle: ${jsonEncode(t.calle)}, puntos: [$puntos]),';
  }).join('\n');
}
