import 'package:flutter/material.dart';

class QuickAccessItem {
  final String id;
  final String label;
  final IconData icon;
  final String route;
  final Color color;
  final String category;

  const QuickAccessItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
    required this.category,
  });
}

/// Todos los accesos disponibles, agrupados por categoría
const _socios = 'Socios';
const _clientes = 'Clientes';
const _proveedores = 'Proveedores';
const _contabilidad = 'Contabilidad';

final allQuickAccessItems = <QuickAccessItem>[
  // Socios
  QuickAccessItem(id: 'socios', label: 'Socios', icon: Icons.people, route: '/socios', color: Colors.blue, category: _socios),
  QuickAccessItem(id: 'residentes', label: 'Residentes', icon: Icons.medical_services, route: '/listado-residentes', color: Colors.teal, category: _socios),
  QuickAccessItem(id: 'facturar', label: 'Facturar Conceptos', icon: Icons.receipt, route: '/facturacion-conceptos', color: Colors.blue, category: _socios),
  QuickAccessItem(id: 'cobranzas', label: 'Cobranzas Socios', icon: Icons.payments, route: '/cobranzas', color: Colors.blue, category: _socios),
  QuickAccessItem(id: 'ctas_ctes', label: 'Control Ctas Ctes', icon: Icons.account_balance_wallet, route: '/resumen-cuentas-corrientes', color: Colors.blue, category: _socios),

  // Clientes
  QuickAccessItem(id: 'clientes', label: 'Clientes / Sponsors', icon: Icons.business, route: '/clientes', color: Colors.green, category: _clientes),
  QuickAccessItem(id: 'comp_ventas', label: 'Comprobantes Ventas', icon: Icons.receipt, route: '/comprobantes-clientes', color: Colors.green, category: _clientes),
  QuickAccessItem(id: 'cobranzas_cli', label: 'Cobranzas Clientes', icon: Icons.payments, route: '/cobranzas-clientes', color: Colors.green, category: _clientes),
  QuickAccessItem(id: 'saldos_cli', label: 'Saldos Clientes', icon: Icons.account_balance_wallet, route: '/saldos-clientes', color: Colors.green, category: _clientes),

  // Proveedores
  QuickAccessItem(id: 'proveedores', label: 'Proveedores', icon: Icons.store, route: '/proveedores', color: Colors.orange, category: _proveedores),
  QuickAccessItem(id: 'comp_compras', label: 'Comprobantes Compras', icon: Icons.receipt_long, route: '/comprobantes-proveedores', color: Colors.orange, category: _proveedores),
  QuickAccessItem(id: 'orden_pago', label: 'Orden de Pago', icon: Icons.payment, route: '/orden-pago', color: Colors.orange, category: _proveedores),
  QuickAccessItem(id: 'pago_directo', label: 'Pago Directo', icon: Icons.flash_on, route: '/pago-directo', color: Colors.deepOrange, category: _proveedores),
  QuickAccessItem(id: 'saldos_prov', label: 'Saldos Proveedores', icon: Icons.account_balance_wallet, route: '/saldos-proveedores', color: Colors.orange, category: _proveedores),

  // Contabilidad
  QuickAccessItem(id: 'asientos', label: 'Asientos de Diario', icon: Icons.book, route: '/asientos', color: Colors.blueGrey, category: _contabilidad),
  QuickAccessItem(id: 'mayor', label: 'Mayor de Cuentas', icon: Icons.account_balance, route: '/mayor-cuentas', color: Colors.blueGrey, category: _contabilidad),
  QuickAccessItem(id: 'plan_cuentas', label: 'Plan de Cuentas', icon: Icons.list_alt, route: '/cuentas', color: Colors.blueGrey, category: _contabilidad),
  QuickAccessItem(id: 'param_contables', label: 'Parámetros Contables', icon: Icons.settings, route: '/parametros-contables', color: Colors.blueGrey, category: _contabilidad),
];

/// IDs de accesos rápidos por defecto para la primera vez
const defaultQuickAccessIds = [
  'socios',
  'cobranzas',
  'cobranzas_cli',
  'orden_pago',
  'pago_directo',
  'asientos',
];

/// Obtener las categorías únicas en orden
List<String> get quickAccessCategories =>
    allQuickAccessItems.map((e) => e.category).toSet().toList();
