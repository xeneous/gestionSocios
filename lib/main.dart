import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configuración de Supabase
  // IMPORTANTE: Usando service_role key para bypasear RLS
  // La aplicación Flutter maneja su propia autenticación y permisos
  await Supabase.initialize(
    url: 'https://ojbdljecdvjgsbthouvf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9qYmRsamVjZHZqZ3NidGhvdXZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NjQ5OTQyOSwiZXhwIjoyMDgyMDc1NDI5fQ.xFWbeJCQXlxb29ENj7wG9fMCR1ZPkfhV1ac2hOgxtpM',
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
