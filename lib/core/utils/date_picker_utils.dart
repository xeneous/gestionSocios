import 'package:flutter/material.dart';

/// Muestra un selector de fecha que confirma automáticamente al tocar una fecha,
/// sin necesidad de presionar OK.
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
    builder: (context) {
      return Dialog(
        child: SizedBox(
          width: 360,
          child: CalendarDatePicker(
            initialDate: safeInitial,
            firstDate: first,
            lastDate: last,
            onDateChanged: (date) => Navigator.of(context).pop(date),
          ),
        ),
      );
    },
  );
}
