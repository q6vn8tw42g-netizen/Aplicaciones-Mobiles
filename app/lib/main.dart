import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'providers/espacios_provider.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
  url: 'https://pkvmkejunsvjhabysmpo.supabase.co',
  anonKey: 'sb_publishable_lHbfYIGef_HcKcAw9rF4gw_LuhSkfAV' 
);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => EspaciosProvider()..iniciar(),
        ),
      ],
      child: const EstacionaYaApp(),
    ),
  );
}

class EstacionaYaApp extends StatelessWidget {
  const EstacionaYaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EstacionaYa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1D9E75),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}