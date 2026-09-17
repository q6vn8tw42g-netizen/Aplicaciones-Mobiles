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

    await _abrirNavegador(
      uriAndroid: Uri.parse('google.navigation:q=$latitud,$longitud&mode=d'),
      uriWeb: uriWeb,
      nombre: 'Google Maps',
    );
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

    await _abrirNavegador(
      uriAndroid: Uri.parse('waze://?ll=$latitud,$longitud&navigate=yes'),
      uriWeb: uriWeb,
      nombre: 'Waze',
    );
  }

  static Future<void> _abrirNavegador({
    required Uri uriAndroid,
    required Uri uriWeb,
    required String nombre,
  }) async {
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
