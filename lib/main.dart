import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import 'core/router/app_router.dart';
import 'features/cuentas_corrientes/providers/cuentas_corrientes_provider.dart';
import 'features/comprobantes_prov/providers/orden_pago_provider.dart';
import 'features/comprobantes_cli/providers/cobranzas_clientes_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_AR', null);

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: SAOApp(),
    ),
  );
}

class SAOApp extends ConsumerStatefulWidget {
  const SAOApp({super.key});

  @override
  ConsumerState<SAOApp> createState() => _SAOAppState();
}

class _SAOAppState extends ConsumerState<SAOApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Si la pestaña estuvo inactiva, el refresh automático del token
      // puede no haberse disparado a tiempo (throttling de timers en
      // background). Forzamos un refresh proactivo para evitar que la
      // sesión se pierda y el usuario sea expulsado de un formulario.
      _refreshSessionSilently();

      // Al recuperar el foco (cambio de pestaña, vuelta a la ventana):
      // invalida todas las instancias cacheadas de los providers de datos clave.
      ref.invalidate(cuentasCorrientesPorSocioProvider);
      ref.invalidate(saldoSocioProvider);
      ref.invalidate(saldoProfesionalProvider);
      ref.invalidate(cuentasCorrientesSearchProvider);
      ref.invalidate(comprobantesPendientesProveedorProvider);
      ref.invalidate(saldoProveedorProvider);
      ref.invalidate(comprobantesPendientesClienteProvider);
      ref.invalidate(saldoClienteProvider);
    }
  }

  Future<void> _refreshSessionSilently() async {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {
      // Si falla (sin sesión, refresh token inválido, sin red), el guard
      // de cambios sin guardar / redirect a login se encargan del resto.
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Sistema de Gestion Sociedad Argentina de Oftalmologia',
      debugShowCheckedModeBanner: AppConfig.isDev,
      locale: const Locale('es', 'AR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'AR'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
        scrollbarTheme: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(true),
          trackVisibility: WidgetStateProperty.all(true),
          thickness: WidgetStateProperty.all(8),
          radius: const Radius.circular(4),
          crossAxisMargin: 2,
        ),
      ),
      routerConfig: router,
    );
  }
}
