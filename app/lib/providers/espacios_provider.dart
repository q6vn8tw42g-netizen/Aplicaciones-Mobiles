import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/espacio.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

class EspaciosProvider extends ChangeNotifier {
  final _supabaseService = SupabaseService();
  final _apiService = ApiService();

  List<Espacio> espacios = [];
  int puntosKarma = 0;
  bool cargando = true;
  String? error;

  Future<void> iniciar() async {
    await _cargarEspacios();
    await _cargarPerfil();
    _supabaseService.suscribirseAEspacios(_actualizarEspacio);
  }

  Future<void> _cargarEspacios() async {
    cargando = true;
    notifyListeners();
    try {
      espacios = await _supabaseService.obtenerEspacios();
      error = null;
    } catch (_) {
      error = 'No se pudieron cargar los espacios. Revisa tu conexión.';
    }
    cargando = false;
    notifyListeners();
  }

  Future<void> _cargarPerfil() async {
    final perfil = await _supabaseService.obtenerMiPerfil();
    if (perfil != null) {
      puntosKarma = perfil['puntos_karma'] as int? ?? 0;
      notifyListeners();
    }
  }

  void _actualizarEspacio(Espacio actualizado) {
    final indice = espacios.indexWhere((e) => e.id == actualizado.id);
    if (indice != -1) {
      espacios[indice] = actualizado;
      notifyListeners();
    }
  }

  /// RF6: exige la ubicación real del dispositivo antes de reportar.
  Future<void> reportar(Espacio espacio, String tipo) async {
    final permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      final solicitado = await Geolocator.requestPermission();
      if (solicitado == LocationPermission.denied ||
          solicitado == LocationPermission.deniedForever) {
        throw Exception('Necesitas dar permiso de ubicación para reportar.');
      }
    }

    final posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await _apiService.reportar(
      espacioId: espacio.id,
      tipo: tipo,
      latitud: posicion.latitude,
      longitud: posicion.longitude,
    );

    if (tipo == 'VOY_A_SALIR') {
      puntosKarma += 10;
      notifyListeners();
    }
  }
}
