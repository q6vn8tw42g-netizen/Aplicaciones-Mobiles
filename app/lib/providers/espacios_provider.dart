import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/espacio.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

class EspaciosProvider extends ChangeNotifier {
  EspaciosProvider({Stream<List<Map<String, dynamic>>>? espaciosStream})
      : _espaciosStream = espaciosStream;

  final Stream<List<Map<String, dynamic>>>? _espaciosStream;
  final ApiService _apiService = ApiService();
  StreamSubscription<List<Espacio>>? _suscripcion;
  bool _disposed = false;

  List<Espacio> espacios = [];
  int puntosKarma = 0;
  bool cargando = true;
  String? error;

  Future<void> iniciar() async {
    if (_disposed || _suscripcion != null) return;
    cargando = true;
    error = null;
    notifyListeners();

    try {
      final stream = _espaciosStream ??
          Supabase.instance.client
              .from('espacios')
              .stream(primaryKey: ['id']).order('camara_id');
      _suscripcion =
          stream.map((filas) => filas.map(Espacio.fromMap).toList()).listen(
        (actualizados) {
          if (_disposed) return;
          // Lista completa tras INSERT, UPDATE o DELETE.
          espacios = actualizados;
          cargando = false;
          error = null;
          notifyListeners();
        },
        onError: (Object e, StackTrace stackTrace) => _mostrarError(e),
        onDone: () => _suscripcion = null,
      );
    } catch (e) {
      _mostrarError(e);
    }
    unawaited(_cargarPerfil());
  }

  void _mostrarError(Object e) {
    if (_disposed) return;
    cargando = false;
    error = 'No se pudieron sincronizar los espacios. '
        'Revisa la conexión y la configuración de Supabase.';
    debugPrint('Error al sincronizar espacios: $e');
    notifyListeners();
  }

  Future<void> _cargarPerfil() async {
    // Un fallo del perfil no debe bloquear la sincronización del mapa.
    try {
      final perfil = await SupabaseService().obtenerMiPerfil();
      if (_disposed || perfil == null) return;
      puntosKarma = perfil['puntos_karma'] as int? ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo cargar el perfil: $e');
    }
  }

  Future<void> reportar(Espacio espacio, String tipo) async {
    await _verificarPermisoUbicacion();
    final posicion = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    await _apiService.reportar(
      espacioId: espacio.id,
      tipo: tipo,
      latitud: posicion.latitude,
      longitud: posicion.longitude,
    );
    if (_disposed) return;
    if (tipo == 'VOY_A_SALIR') {
      puntosKarma += 10;
      notifyListeners();
    }
  }

  Future<void> _verificarPermisoUbicacion() async {
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw Exception('Necesitas dar permiso de ubicación para reportar.');
    }
    if (permiso == LocationPermission.deniedForever) {
      throw Exception('El permiso de ubicación está bloqueado. '
          'Actívalo desde la configuración del dispositivo.');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final suscripcion = _suscripcion;
    _suscripcion = null;
    if (suscripcion != null) unawaited(suscripcion.cancel());
    super.dispose();
  }
}
