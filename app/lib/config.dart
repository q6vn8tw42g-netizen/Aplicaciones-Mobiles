class AppConfig {
  // Apunta al backend local usando la IP de tu computadora
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.115:8000', 
  );

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pkvmkejunsvjhabysmpo.supabase.co',
  );

  // Llave pública segura de Supabase
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBrdm1rZWp1bnN2amhhYnlzbXBvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0Mjk0MzMsImV4cCI6MjEwNTAwNTQzM30.bCB9wYKJrwKtPvDde8fH4qJXpRVkVNU8GQmC29kh3KY',
  );
}