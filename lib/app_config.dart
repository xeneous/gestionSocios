/// Configuración de entorno inyectada vía --dart-define en tiempo de compilación.
///
/// Uso en VS Code: ver .vscode/launch.json
/// Uso en CLI:
///   Dev:  flutter run --dart-define=ENV=dev --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///   Prod: flutter run  (usa los valores por defecto)
class AppConfig {
  static const String env = String.fromEnvironment('ENV', defaultValue: 'prod');

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ojbdljecdvjgsbthouvf.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9qYmRsamVjZHZqZ3NidGhvdXZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY0OTk0MjksImV4cCI6MjA4MjA3NTQyOX0.GdJ6fBByxx6hlq8njMs0ceZj2xSermSSowzqVSLh7hg',
  );

  static bool get isDev => env == 'dev';
  static bool get isProd => env == 'prod';
}
