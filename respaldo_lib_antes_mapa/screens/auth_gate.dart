import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/espacios_provider.dart';
import 'home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final EspaciosProvider _provider;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _provider = EspaciosProvider()..iniciar();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _provider.actualizarSesion(),
      onError: (Object error) =>
          debugPrint('No se pudo observar el estado de sesión: $error'),
    );
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Se conserva el mismo Provider al iniciar/cerrar sesión. Así, al volver
    // del login el flujo pendiente de reserva continúa con la sesión nueva.
    return ChangeNotifierProvider<EspaciosProvider>.value(
      value: _provider,
      child: const HomeScreen(),
    );
  }
}
