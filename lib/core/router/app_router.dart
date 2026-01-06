import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/cuentas/presentation/pages/cuentas_list_page.dart';
import '../../features/cuentas/presentation/pages/cuenta_form_page.dart';
import '../../features/asientos/presentation/pages/asientos_list_page.dart';
import '../../features/asientos/presentation/pages/asiento_form_page.dart';
import '../../features/socios/presentation/pages/socios_list_page.dart';
import '../../features/socios/presentation/pages/socio_form_page.dart';
import '../../features/cuentas_corrientes/presentation/pages/cuentas_corrientes_list_page.dart';
import '../../features/cuentas_corrientes/presentation/pages/cuenta_corriente_form_page.dart';
import '../../features/cuentas_corrientes/presentation/pages/cuenta_corriente_socio_table_page.dart';
import '../../features/cuentas_corrientes/presentation/pages/cobranzas_select_socio_page.dart';
import '../../features/cuentas_corrientes/presentation/pages/cobranzas_page.dart';
import '../../features/conceptos_tesoreria/presentation/pages/conceptos_tesoreria_list_page.dart';
import '../../features/conceptos_tesoreria/presentation/pages/concepto_tesoreria_form_page.dart';
import '../../features/socios/presentation/pages/conceptos_list_page.dart';
import '../../features/socios/presentation/pages/concepto_form_page.dart';
import '../../features/admin/presentation/pages/mantenimiento_page.dart';
import '../../features/auth/presentation/pages/usuarios_list_page.dart';
import '../../features/auth/presentation/pages/usuario_form_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/facturador/presentation/pages/facturador_global_page.dart';
import '../../features/cuota_social/presentation/pages/valores_cuota_page.dart';
import '../../features/debitos_automaticos/presentation/pages/debitos_automaticos_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }

      if (isLoggedIn && isLoginRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/cuentas',
        name: 'cuentas',
        builder: (context, state) => const CuentasListPage(),
      ),
      GoRoute(
        path: '/cuentas/nueva',
        name: 'cuentas-nueva',
        builder: (context, state) => const CuentaFormPage(),
      ),
      GoRoute(
        path: '/cuentas/:id',
        name: 'cuentas-edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CuentaFormPage(cuentaId: id);
        },
      ),
      GoRoute(
        path: '/asientos',
        name: 'asientos',
        builder: (context, state) => const AsientosListPage(),
      ),
      GoRoute(
        path: '/asientos/nuevo',
        name: 'asientos-nuevo',
        builder: (context, state) => const AsientoFormPage(),
      ),
      GoRoute(
        path: '/asientos/:asiento/:anioMes/:tipoAsiento',
        name: 'asientos-edit',
        builder: (context, state) {
          final asiento = int.parse(state.pathParameters['asiento']!);
          final anioMes = int.parse(state.pathParameters['anioMes']!);
          final tipoAsiento = int.parse(state.pathParameters['tipoAsiento']!);
          return AsientoFormPage(
            asiento: asiento,
            anioMes: anioMes,
            tipoAsiento: tipoAsiento,
          );
        },
      ),
      GoRoute(
        path: '/socios',
        name: 'socios',
        builder: (context, state) => const SociosListPage(),
      ),
      GoRoute(
        path: '/socios/nuevo',
        name: 'socios-nuevo',
        builder: (context, state) => const SocioFormPage(),
      ),
      // Cuenta Corriente por Socio (debe ir ANTES de /socios/:id)
      GoRoute(
        path: '/socios/:socioId/cuenta-corriente',
        name: 'cuenta-corriente-socio',
        builder: (context, state) {
          final socioId = int.parse(state.pathParameters['socioId']!);
          return CuentaCorrienteSocioTablePage(socioId: socioId);
        },
      ),
      GoRoute(
        path: '/socios/:id',
        name: 'socios-edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return SocioFormPage(socioId: id);
        },
      ),
      // Cuentas Corrientes
      GoRoute(
        path: '/cuentas-corrientes',
        name: 'cuentas-corrientes',
        builder: (context, state) => const CuentasCorrientesListPage(),
      ),
      GoRoute(
        path: '/cuentas-corrientes/nueva',
        name: 'cuentas-corrientes-nueva',
        builder: (context, state) => const CuentaCorrienteFormPage(),
      ),
      GoRoute(
        path: '/cuentas-corrientes/:id',
        name: 'cuentas-corrientes-edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CuentaCorrienteFormPage(idtransaccion: id);
        },
      ),
      // Cobranzas
      GoRoute(
        path: '/cobranzas',
        name: 'cobranzas-select-socio',
        builder: (context, state) => const CobranzasSelectSocioPage(),
      ),
      GoRoute(
        path: '/cobranzas/:socioId',
        name: 'cobranzas',
        builder: (context, state) {
          final socioId = int.parse(state.pathParameters['socioId']!);
          return CobranzasPage(socioId: socioId);
        },
      ),
      // Conceptos de Tesorería
      GoRoute(
        path: '/conceptos-tesoreria',
        name: 'conceptos-tesoreria',
        builder: (context, state) => const ConceptosTesoreriaListPage(),
      ),
      GoRoute(
        path: '/conceptos-tesoreria/new',
        name: 'conceptos-tesoreria-new',
        builder: (context, state) => const ConceptoTesoreriaFormPage(),
      ),
      GoRoute(
        path: '/conceptos-tesoreria/:id',
        name: 'conceptos-tesoreria-edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ConceptoTesoreriaFormPage(conceptoId: id);
        },
      ),
      // Conceptos (Socios)
      GoRoute(
        path: '/conceptos',
        name: 'conceptos',
        builder: (context, state) => const ConceptosListPage(),
      ),
      GoRoute(
        path: '/conceptos/new',
        name: 'conceptos-new',
        builder: (context, state) => const ConceptoFormPage(),
      ),
      GoRoute(
        path: '/conceptos/:codigo',
        name: 'conceptos-edit',
        builder: (context, state) {
          final codigo = state.pathParameters['codigo']!;
          return ConceptoFormPage(conceptoCodigo: codigo);
        },
      ),
      // Mantenimiento/Administración
      GoRoute(
        path: '/mantenimiento',
        name: 'mantenimiento',
        builder: (context, state) => const MantenimientoPage(),
      ),
      // Usuarios
      GoRoute(
        path: '/usuarios',
        name: 'usuarios',
        builder: (context, state) => const UsuariosListPage(),
      ),
      GoRoute(
        path: '/usuarios/new',
        name: 'usuarios-new',
        builder: (context, state) => const UsuarioFormPage(),
      ),
      GoRoute(
        path: '/usuarios/:id',
        name: 'usuarios-edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return UsuarioFormPage(usuarioId: id);
        },
      ),
      // Cambiar contraseña
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      // Facturador Global
      GoRoute(
        path: '/facturador-global',
        name: 'facturador-global',
        builder: (context, state) => const FacturadorGlobalPage(),
      ),
      // Valores de Cuota Social
      GoRoute(
        path: '/valores-cuota',
        name: 'valores-cuota',
        builder: (context, state) => const ValoresCuotaPage(),
      ),
      // Débitos Automáticos
      GoRoute(
        path: '/debitos-automaticos',
        name: 'debitos-automaticos',
        builder: (context, state) => const DebitosAutomaticosPage(),
      ),
    ],
  );
});
