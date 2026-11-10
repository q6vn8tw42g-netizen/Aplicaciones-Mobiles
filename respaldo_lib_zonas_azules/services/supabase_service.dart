import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/espacio.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  Future<List<Espacio>> obtenerEspacios() async {
    final datos = await _client.from('espacios').select();
    return (datos as List)
        .map((fila) => Espacio.fromMap(fila as Map<String, dynamic>))
        .toList();
  }

  /// RF7: se suscribe a cambios en la tabla espacios (los publica Realtime
  /// automáticamente cada vez que la API o el servicio de visión hacen un UPDATE).
  RealtimeChannel suscribirseAEspacios(void Function(Espacio) alCambiar) {
    return _client
        .channel('espacios-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'espacios',
          callback: (payload) {
            alCambiar(Espacio.fromMap(payload.newRecord));
          },
        )
        .subscribe();
  }

  Future<Map<String, dynamic>?> obtenerMiPerfil() async {
    final usuario = _client.auth.currentUser;
    if (usuario == null) return null;
    return await _client
        .from('perfiles')
        .select()
        .eq('id', usuario.id)
        .single();
  }
}
