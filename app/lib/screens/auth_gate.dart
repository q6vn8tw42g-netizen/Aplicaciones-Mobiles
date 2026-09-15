import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/espacios_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final haySesion = client.auth.currentSession != null;

        if (!haySesion) {
          return const LoginScreen();
        }

        // El provider solo se crea (y solo entonces pide datos a Supabase)
        // una vez que sabemos que hay una sesión activa.
        return ChangeNotifierProvider(
          create: (_) => EspaciosProvider()..iniciar(),
          child: const HomeScreen(),
        );
      },
    );
  }
}
