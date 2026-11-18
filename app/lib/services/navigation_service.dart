import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  const NavigationService._();

  static Future<void> abrirGoogleMaps({
    required double latitud,
    required double longitud,
  }) async {
    final uriWeb = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': '$latitud,$longitud',
        'travelmode': 'driving',
        'dir_action': 'navigate',
      },
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const canal = MethodChannel('estacionaya/navigation');
      try {
        final abierta = await canal.invokeMethod<bool>('openGoogleMaps', {
          'latitude': latitud,
          'longitude': longitud,
        });
        if (abierta == true) return;
      } on PlatformException {
        // Un dispositivo con apertura restringida puede disponer de navegador.
      } on MissingPluginException {
        // Un host sin integración Android también acepta la URL universal.
      }
    }
    await _abrirWeb(uriWeb, 'Google Maps');
  }

  static Future<void> abrirWaze({
    required double latitud,
    required double longitud,
  }) async {
    final uriWeb = Uri.https(
      'waze.com',
      '/ul',
      {
        'll': '$latitud,$longitud',
        'navigate': 'yes',
      },
    );

    final uriAndroid = Uri.parse('waze://?ll=$latitud,$longitud&navigate=yes');
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        if (await canLaunchUrl(uriAndroid) &&
            await launchUrl(
              uriAndroid,
              mode: LaunchMode.externalApplication,
            )) {
          return;
        }
      } on PlatformException {
        // La app puede dejar de estar disponible entre la consulta y la apertura.
        // En ese caso, intentamos el enlace HTTPS.
      }
    }

    await _abrirWeb(uriWeb, 'Waze');
  }

  static Future<void> _abrirWeb(Uri uriWeb, String nombre) async {
    try {
      if (await launchUrl(uriWeb, mode: LaunchMode.externalApplication)) {
        return;
      }
    } on PlatformException {
      throw Exception('No se pudo abrir $nombre.');
    }

    throw Exception('No se pudo abrir $nombre.');
  }
}
