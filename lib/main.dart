import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configuración de Supabase
  await Supabase.initialize(
    url: 'https://ojbdljecdvjgsbthouvf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9qYmRsamVjZHZqZ3NidGhvdXZmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY0OTk0MjksImV4cCI6MjA4MjA3NTQyOX0.GdJ6fBByxx6hlq8njMs0ceZj2xSermSSowzqVSLh7hg',
  );
  
  runApp(
    const ProviderScope(
      child: SAOApp(),
    ),
  );
}

class SAOApp extends ConsumerWidget {
  const SAOApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'SAO 2026 - Sistema Contable',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
