import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Selector de fecha: se puede escribir manualmente (dd/mm/aaaa, Enter o
/// "Aceptar") o tocar una fecha del calendario, que confirma automáticamente.
Future<DateTime?> pickDate(
  BuildContext context,
  DateTime initialDate, {
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final first = firstDate ?? DateTime(2000);
  final last = lastDate ?? DateTime(2100);

  // Asegurar que initialDate esté dentro del rango
  final safeInitial = initialDate.isBefore(first)
      ? first
      : initialDate.isAfter(last)
          ? last
          : initialDate;

  return showDialog<DateTime>(
    context: context,
    builder: (context) => _PickDateDialog(
      initial: safeInitial,
      first: first,
      last: last,
    ),
  );
}

class _PickDateDialog extends StatefulWidget {
  final DateTime initial;
  final DateTime first;
  final DateTime last;

  const _PickDateDialog({
    required this.initial,
    required this.first,
    required this.last,
  });

  @override
  State<_PickDateDialog> createState() => _PickDateDialogState();
}

class _PickDateDialogState extends State<_PickDateDialog> {
  late final TextEditingController _ctrl;
  String? _error;

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.initial));
    _ctrl.selection =
        TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Acepta dd/mm/aaaa, dd-mm-aaaa, dd.mm.aaaa, ddmmaaaa y año de 2 dígitos.
  DateTime? _parse(String raw) {
    final s = raw.trim();
    int? d, m, y;
    final parts = s.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      d = int.tryParse(parts[0]);
      m = int.tryParse(parts[1]);
      y = int.tryParse(parts[2]);
    } else if (RegExp(r'^\d{8}$').hasMatch(s)) {
      d = int.parse(s.substring(0, 2));
      m = int.parse(s.substring(2, 4));
      y = int.parse(s.substring(4));
    }
    if (d == null || m == null || y == null) return null;
    if (y < 100) y += 2000;
    final date = DateTime(y, m, d);
    // Rechaza fechas inexistentes (31/02 se desbordaría a marzo)
    if (date.day != d || date.month != m) return null;
    return date;
  }

  void _aceptar() {
    final date = _parse(_ctrl.text);
    if (date == null) {
      setState(() => _error = 'Fecha inválida (dd/mm/aaaa)');
      return;
    }
    if (date.isBefore(widget.first) || date.isAfter(widget.last)) {
      setState(() => _error = 'Fecha fuera de rango');
      return;
    }
    Navigator.of(context).pop(date);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9/\-.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Escribir fecha (dd/mm/aaaa)',
                        errorText: _error,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _aceptar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _aceptar,
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ),
            CalendarDatePicker(
              initialDate: widget.initial,
              firstDate: widget.first,
              lastDate: widget.last,
              onDateChanged: (date) => Navigator.of(context).pop(date),
            ),
          ],
        ),
      ),
    );
  }
}
