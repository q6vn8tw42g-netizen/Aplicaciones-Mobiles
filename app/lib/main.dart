import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/splash_screen.dart';
import 'theme/estacionaya_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.supabasePublishableKey.startsWith('coloca-aqui-')) {
    throw StateError(
      'Define SUPABASE_PUBLISHABLE_KEY con --dart-define antes de ejecutar la app.',
    );
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );

  runApp(const EstacionaYaApp());
}

class EstacionaYaApp extends StatelessWidget {
  const EstacionaYaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EstacionaYa',
      debugShowCheckedModeBanner: false,
      theme: EstacionaYaTheme.light,
      home: const SplashScreen(),
    );
  }
}
