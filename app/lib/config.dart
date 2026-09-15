/// Configuración de la app. Los valores por defecto apuntan a un backend
/// local visto desde el emulador Android (10.0.2.2 = localhost del host).
/// Para un dispositivo físico, usa la IP de tu PC en la red local.
///
/// Puedes sobreescribir estos valores al compilar, por ejemplo:
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://10.0.2.2:54321',
  );

  // Llave "Publishable" (sb_publishable_...) de `supabase status`.
  // Es segura para incluir en la app: no permite saltarse RLS.
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'coloca-aqui-tu-sb_publishable_...',
  );
}
