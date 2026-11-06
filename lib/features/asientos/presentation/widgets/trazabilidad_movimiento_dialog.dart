import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Línea de un asiento con la descripción de su cuenta.
class _LineaAsiento {
  final int cuenta;
  final String descripcion;
  final double debe;
  final double haber;
  _LineaAsiento(this.cuenta, this.descripcion, this.debe, this.haber);
}

/// Asiento (cabecera + líneas).
class _AsientoTraza {
  final int asiento;
  final int anioMes;
  final int tipo;
  final DateTime fecha;
  final String detalle;
  final List<_LineaAsiento> lineas;
  _AsientoTraza(this.asiento, this.anioMes, this.tipo, this.fecha, this.detalle, this.lineas);
}

/// Recibo que canceló (total o parcialmente) una factura, con su asiento de cobranza.
class _ReciboTraza {
  final int numero;
  final DateTime? fecha;
  final double totalRecibo;
  final double aplicado;
  final _AsientoTraza? asiento;
  _ReciboTraza(this.numero, this.fecha, this.totalRecibo, this.aplicado, this.asiento);
}

class _FacturaTraza {
  final String nroComprobante;
  final DateTime? fecha;
  final int? cliente;
  final double total;
  final double cancelado;
  final List<_ReciboTraza> recibos;
  _FacturaTraza(this.nroComprobante, this.fecha, this.cliente, this.total, this.cancelado, this.recibos);
}

class _Traza {
  final _AsientoTraza origen;
  final List<_FacturaTraza> facturas; // facturas ligadas al asiento
  final bool origenEsRecibo; // true: el asiento clickeado es una cobranza y 'facturas' son las que canceló
  final String? aviso;
  final String modulo; // módulo donde se generó el asiento
  _Traza(this.origen, this.facturas, this.origenEsRecibo, this.aviso, this.modulo);
}

/// Abre el recorrido: línea del mayor -> asiento -> factura -> recibo -> asiento de cobranza.
Future<void> mostrarTrazabilidadMovimiento(
  BuildContext context, {
  required int asiento,
  required DateTime fecha,
  required String detalle,
}) {
  return showDialog(
    context: context,
    builder: (_) => _TrazabilidadDialog(asiento: asiento, fecha: fecha, detalle: detalle),
  );
}

class _TrazabilidadDialog extends ConsumerStatefulWidget {
  final int asiento;
  final DateTime fecha;
  final String detalle;
  const _TrazabilidadDialog({required this.asiento, required this.fecha, required this.detalle});

  @override
  ConsumerState<_TrazabilidadDialog> createState() => _TrazabilidadDialogState();
}

class _TrazabilidadDialogState extends ConsumerState<_TrazabilidadDialog> {
  final _money = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
  final _dateFmt = DateFormat('dd/MM/yyyy');
  late Future<_Traza> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargar(ref.read(supabaseProvider));
  }

  static String _iso(DateTime d) => d.toIso8601String().split('T')[0];
  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  Future<_AsientoTraza?> _leerAsiento(SupabaseClient db, int asiento, int anioMes, int tipo) async {
    final h = await db
        .from('asientos_header')
        .select('asiento, anio_mes, tipo_asiento, fecha, detalle')
        .eq('asiento', asiento)
        .eq('anio_mes', anioMes)
        .eq('tipo_asiento', tipo)
        .maybeSingle();
    if (h == null) return null;
    final items = await db
        .from('asientos_items')
        .select('item, cuenta_id, debe, haber, cuentas(descripcion)')
        .eq('asiento', asiento)
        .eq('anio_mes', anioMes)
        .eq('tipo_asiento', tipo)
        .order('item');
    final lineas = (items as List)
        .map((i) => _LineaAsiento(
              i['cuenta_id'] as int,
              (i['cuentas'] is Map ? i['cuentas']['descripcion'] : null)?.toString() ?? '',
              _num(i['debe']),
              _num(i['haber']),
            ))
        .toList();
    return _AsientoTraza(
      h['asiento'] as int,
      h['anio_mes'] as int,
      h['tipo_asiento'] as int,
      DateTime.parse(h['fecha'] as String),
      (h['detalle'] as String?) ?? '',
      lineas,
    );
  }

  static const _moduloPorOperacion = {
    'COBRANZA_SOCIO': 'Cobranzas de socios',
    'COBRANZA_PROFESIONAL': 'Cobranzas de profesionales',
    'COBRANZA_SPONSOR': 'Cobranzas de sponsors',
    'ORDEN_PAGO': 'Pagos a proveedores (orden de pago)',
    'DEBITO_AUTOMATICO': 'Débito automático',
  };

  /// Módulo que generó el asiento: primero por el vínculo en operaciones_contables,
  /// si no por el tipo de asiento.
  Future<String> _moduloDe(SupabaseClient db, _AsientoTraza a) async {
    final oc = await db
        .from('operaciones_contables')
        .select('tipo_operacion')
        .eq('asiento_numero', a.asiento)
        .eq('asiento_anio_mes', a.anioMes)
        .eq('asiento_tipo', a.tipo)
        .limit(1);
    if ((oc as List).isNotEmpty) {
      final t = oc.first['tipo_operacion']?.toString() ?? '';
      return _moduloPorOperacion[t] ?? t;
    }
    switch (a.tipo) {
      case 1:
        return a.detalle.contains('Recibo Cli') ? 'Cobranzas de sponsors' : 'Cobranzas (socios / profesionales)';
      case 2:
        return 'Pagos a proveedores';
      case 3:
        return 'Compras (comprobantes de proveedores)';
      case 4:
        return 'Ventas (facturas de sponsors)';
      default:
        return 'Asiento manual / otros módulos (tarjetas, ajustes, correcciones)';
    }
  }

  Future<_Traza> _cargar(SupabaseClient db) async {
    // 1) Identificar el asiento: el mayor solo trae número, fecha y detalle.
    final cands = await db
        .from('asientos_header')
        .select('asiento, anio_mes, tipo_asiento, detalle')
        .eq('asiento', widget.asiento)
        .eq('fecha', _iso(widget.fecha));
    final exactos = (cands as List).where((c) => (c['detalle'] ?? '') == widget.detalle).toList();
    final elegido = exactos.isNotEmpty ? exactos : cands;
    if (elegido.isEmpty) {
      throw Exception('No se encontró el asiento ${widget.asiento} del ${_dateFmt.format(widget.fecha)}.');
    }
    final h = elegido.first;
    final origen = await _leerAsiento(db, h['asiento'] as int, h['anio_mes'] as int, h['tipo_asiento'] as int);
    if (origen == null) throw Exception('No se pudo leer el asiento.');

    final modulo = await _moduloDe(db, origen);

    String? aviso;
    if (elegido.length > 1) {
      aviso = 'Hay ${elegido.length} asientos con el mismo número, fecha y detalle; se muestra el primero.';
    }

    // 2a) Asiento de venta (tipo 4): 'FACTURA:000300000583,CLIENTE' -> factura -> recibos -> asientos de cobranza
    if (origen.tipo == 4) {
      final m = RegExp(r':\s*([0-9A-Za-z]+)\s*,').firstMatch(origen.detalle);
      if (m == null) return _Traza(origen, [], false, aviso ?? 'No se pudo leer el número de comprobante del detalle.', modulo);
      final facts = await db
          .from('ven_cli_header')
          .select('id_transaccion, nro_comprobante, fecha, cliente, total_importe, cancelado, tipo_comprobante')
          .eq('nro_comprobante', m.group(1)!)
          .neq('tipo_comprobante', 0);
      final lista = facts as List;
      if (lista.isEmpty) return _Traza(origen, [], false, aviso ?? 'No se encontró el comprobante ${m.group(1)}.', modulo);
      if (lista.length > 1) {
        aviso = '${aviso == null ? '' : '$aviso '}El número ${m.group(1)} coincide con ${lista.length} comprobantes (factura y nota de crédito u otro cliente); revisar cuál corresponde.';
      }
      final out = <_FacturaTraza>[];
      for (final f in lista) {
        out.add(await _facturaConRecibos(db, f));
      }
      return _Traza(origen, out, false, aviso, modulo);
    }

    // 2b) Asiento de cobranza de sponsors (tipo 1): 'Recibo Cli Nro. N - ...' -> facturas que canceló
    if (origen.tipo == 1) {
      final m = RegExp(r'Recibo Cli Nro\.\s*(\d+)').firstMatch(origen.detalle);
      if (m != null) {
        final nro = int.parse(m.group(1)!);
        final rec = await db
            .from('ven_cli_header')
            .select('id_transaccion, comprobante, fecha, total_importe')
            .eq('comprobante', nro)
            .eq('tipo_comprobante', 0);
        if ((rec as List).isEmpty) return _Traza(origen, [], true, aviso ?? 'No se encontró el recibo $nro.', modulo);
        final imp = await db
            .from('notas_imputacion')
            .select('id_transaccion, importe')
            .eq('id_operacion', rec.first['id_transaccion'])
            .eq('tipo_operacion', 2);
        final ids = (imp as List).map((e) => e['id_transaccion']).toList();
        final out = <_FacturaTraza>[];
        if (ids.isNotEmpty) {
          final fs = await db
              .from('ven_cli_header')
              .select('id_transaccion, nro_comprobante, fecha, cliente, total_importe, cancelado')
              .inFilter('id_transaccion', ids)
              .order('fecha');
          for (final f in fs as List) {
            out.add(_FacturaTraza(
              f['nro_comprobante'].toString(),
              DateTime.tryParse('${f['fecha']}'),
              f['cliente'] as int?,
              _num(f['total_importe']),
              _num(f['cancelado']),
              [],
            ));
          }
        }
        return _Traza(origen, out, true, aviso, modulo);
      }
    }

    return _Traza(
      origen,
      [],
      false,
      aviso ?? 'Este asiento fue generado por el módulo: $modulo. El recorrido factura → recibo → cobranza solo aplica a ventas y cobranzas de sponsors.',
      modulo,
    );
  }

  Future<_FacturaTraza> _facturaConRecibos(SupabaseClient db, Map<String, dynamic> f) async {
    final imp = await db
        .from('notas_imputacion')
        .select('id_operacion, importe')
        .eq('id_transaccion', f['id_transaccion'])
        .eq('tipo_operacion', 2);
    final recibos = <_ReciboTraza>[];
    for (final i in imp as List) {
      final rec = await db
          .from('ven_cli_header')
          .select('comprobante, fecha, total_importe')
          .eq('id_transaccion', i['id_operacion'])
          .eq('tipo_comprobante', 0)
          .maybeSingle();
      if (rec == null) continue;
      final nro = rec['comprobante'] as int;
      final oc = await db
          .from('operaciones_contables')
          .select('asiento_numero, asiento_anio_mes, asiento_tipo')
          .eq('tipo_operacion', 'COBRANZA_SPONSOR')
          .eq('numero_comprobante', nro)
          .limit(1);
      _AsientoTraza? asientoCob;
      if ((oc as List).isNotEmpty && oc.first['asiento_numero'] != null) {
        asientoCob = await _leerAsiento(
          db,
          oc.first['asiento_numero'] as int,
          oc.first['asiento_anio_mes'] as int,
          (oc.first['asiento_tipo'] as int?) ?? 1,
        );
      }
      recibos.add(_ReciboTraza(nro, DateTime.tryParse('${rec['fecha']}'), _num(rec['total_importe']), _num(i['importe']), asientoCob));
    }
    return _FacturaTraza(
      f['nro_comprobante'].toString(),
      DateTime.tryParse('${f['fecha']}'),
      f['cliente'] as int?,
      _num(f['total_importe']),
      _num(f['cancelado']),
      recibos,
    );
  }

  static const _tipoNombre = {1: 'Ingreso', 2: 'Egreso', 3: 'Compras', 4: 'Ventas'};

  Widget _asientoView(_AsientoTraza a, {String? titulo}) {
    final nombre = _tipoNombre[a.tipo] ?? 'Tipo ${a.tipo}';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${titulo ?? 'Asiento'} ${a.asiento} · $nombre · ${a.anioMes} · ${_dateFmt.format(a.fecha)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(a.detalle, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const SizedBox(height: 4),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(80),
                1: FlexColumnWidth(),
                2: FixedColumnWidth(120),
                3: FixedColumnWidth(120),
              },
              children: [
                for (final l in a.lineas)
                  TableRow(children: [
                    Text('${l.cuenta}', style: const TextStyle(fontSize: 12)),
                    Text(l.descripcion, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                    Text(l.debe > 0 ? _money.format(l.debe) : '',
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Colors.green)),
                    Text(l.haber > 0 ? _money.format(l.haber) : '',
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _facturaView(_FacturaTraza f, bool origenEsRecibo) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Factura ${f.nroComprobante}'
            '${f.fecha != null ? ' · ${_dateFmt.format(f.fecha!)}' : ''}'
            '${f.cliente != null ? ' · sponsor ${f.cliente}' : ''}'
            ' · total ${_money.format(f.total)} · cancelado ${_money.format(f.cancelado)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (!origenEsRecibo && f.recibos.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text('Sin recibos aplicados (pendiente de cobro).', style: TextStyle(color: Colors.orange[800])),
            ),
          for (final r in f.recibos)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recibo ${r.numero}'
                    '${r.fecha != null ? ' · ${_dateFmt.format(r.fecha!)}' : ''}'
                    ' · aplicó ${_money.format(r.aplicado)} de ${_money.format(r.totalRecibo)}',
                  ),
                  if (r.asiento != null)
                    _asientoView(r.asiento!, titulo: 'Cobranza: asiento')
                  else
                    Text('Sin asiento de cobranza vinculado.', style: TextStyle(color: Colors.red[700])),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Trazabilidad · asiento ${widget.asiento}'),
      content: SizedBox(
        width: 760,
        child: FutureBuilder<_Traza>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return Text('${snap.error}'.replaceFirst('Exception: ', ''), style: const TextStyle(color: Colors.red));
            }
            final t = snap.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Módulo: ${t.modulo}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  if (t.aviso != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 6),
                      color: Colors.amber[50],
                      child: Text(t.aviso!, style: const TextStyle(fontSize: 12)),
                    ),
                  _asientoView(t.origen),
                  if (t.origenEsRecibo && t.facturas.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Facturas que canceló este recibo:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  for (final f in t.facturas) _facturaView(f, t.origenEsRecibo),
                ],
              ),
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }
}
