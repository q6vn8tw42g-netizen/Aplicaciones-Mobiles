import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

class ApiService {
  String? _token() {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  Map<String, String> _headers() {
    final token = _token();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// RF3/RF4/RF6: reporte de conductor con validación de cercanía en el backend.
  Future<void> reportar({
    required String espacioId,
    required String tipo, // 'ME_ESTACIONE' | 'VOY_A_SALIR'
    required double latitud,
    required double longitud,
  }) async {
    final respuesta = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/espacios/reportar'),
      headers: _headers(),
      body: jsonEncode({
        'espacio_id': espacioId,
        'tipo': tipo,
        'latitud': latitud,
        'longitud': longitud,
      }),
    );

    if (respuesta.statusCode >= 400) {
      throw Exception(_mensajeDeError(respuesta.body));
    }
  }

  /// RF5: solo disponible para usuarios con rol Validador/Admin.
  Future<void> forzarEstado({
    required String espacioId,
    required String estado, // 'LIBRE' | 'OCUPADO'
    int minutosBloqueo = 30,
  }) async {
    final respuesta = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/espacios/$espacioId/forzar-estado'),
      headers: _headers(),
      body: jsonEncode({
        'estado': estado,
        'minutos_bloqueo': minutosBloqueo,
      }),
    );

    if (respuesta.statusCode >= 400) {
      throw Exception(_mensajeDeError(respuesta.body));
    }
  }

  String _mensajeDeError(String cuerpo) {
    try {
      final decodificado = jsonDecode(cuerpo);
      return decodificado['detail']?.toString() ??
          'Ocurrió un error inesperado.';
    } catch (_) {
      return 'Ocurrió un error inesperado.';
    }
  }
}
