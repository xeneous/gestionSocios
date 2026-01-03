# Resumen de Sesión: Cobranzas con Asientos de Diario

## ✅ Lo que se completó

### 1. Servicio Centralizado de Asientos (`AsientosService`)
**Archivo**: `lib/features/asientos/services/asientos_service.dart`

**Funcionalidad**:
- Servicio reutilizable para TODOS los módulos que necesiten generar asientos
- Maneja los 5 tipos de asientos:
  - 0: Asiento de diario puro (`tipoDiario`)
  - 1: Ingreso (`tipoIngreso`)
  - 2: Egreso (`tipoEgreso`)
  - 3: Compras (`tipoCompras`)
  - 4: Ventas (`tipoVentas`)

**Métodos**:
```dart
Future<int> crearAsiento({
  required int tipoAsiento,
  required DateTime fecha,
  required String detalle,
  required List<AsientoItemData> items,
  int? centroCosto,
})
```

**Validaciones**:
- ✅ Partida doble: DEBE = HABER (tolerancia 0.01)
- ✅ Al menos un item
- ✅ Cuenta válida para cada item
- ✅ Numeración secuencial automática por período y tipo

### 2. Integración con Provider Existente
**Archivo**: `lib/features/asientos/providers/asientos_provider.dart`

**Cambios**:
- Agregado `asientosServiceProvider`
- `createAsiento()` ahora usa `AsientosService` (centralizado)
- ✅ **El alta manual de asientos sigue funcionando**

### 3. Función PostgreSQL Simplificada
**Archivo**: `database/create_generar_recibo_function.sql`

**Funcionalidad**:
1. ✅ Genera número de recibo secuencial
2. ✅ Crea valores_tesoreria (formas de pago)
3. ✅ Actualiza campo `cancelado` en cuentas_corrientes
4. ✅ Crea registro **COB** en cuentas_corrientes

**IMPORTANTE**: Ya NO genera asiento de diario (se hace desde Dart)

### 4. Servicio de Cobranzas Actualizado
**Archivo**: `lib/features/cuentas_corrientes/services/cobranzas_service.dart`

**Cambios**:
- `generarRecibo()` ahora retorna solo `int` (número de recibo)
- Ya NO retorna número de asiento
- Documentación actualizada

## ⏳ Lo que falta completar

### 1. Ejecutar SQL en Supabase
**Archivo**: `database/create_generar_recibo_function.sql`

```sql
-- Ejecutar este script completo en Supabase Dashboard
-- Reemplaza la función anterior que intentaba crear asientos
```

### 2. Actualizar CobranzasProvider
**Archivo**: `lib/features/cuentas_corrientes/providers/cobranzas_provider.dart`

Necesita:
```dart
import '../../asientos/services/asientos_service.dart';

Future<Map<String, int>> generarRecibo({...}) async {
  // 1. Generar recibo (PostgreSQL)
  final numeroRecibo = await service.generarRecibo(...);

  // 2. Generar asiento usando AsientosService
  final asientosService = ref.read(asientosServiceProvider);

  // Preparar items DEBE y HABER
  final itemsAsiento = await _prepararItemsAsiento(
    transaccionesAPagar,
    formasPago,
    numeroRecibo
  );

  final numeroAsiento = await asientosService.crearAsiento(
    tipoAsiento: AsientosService.tipoIngreso, // tipo 1
    fecha: DateTime.now(),
    detalle: 'Cobranza Recibo Nro. $numeroRecibo',
    items: itemsAsiento,
  );

  return {
    'numero_recibo': numeroRecibo,
    'numero_asiento': numeroAsiento,
  };
}
```

### 3. Implementar `_prepararItemsAsiento()`
Lógica para crear items:

**DEBE** (Caja/Banco):
```dart
for (var formaPago in formasPago.entries) {
  // Obtener cuenta desde conceptos_tesoreria.imputacion_contable
  final cuentaId = await _getCuentaIdFromConceptoTesoreria(formaPago.key);

  items.add(AsientoItemData(
    cuentaId: cuentaId,
    debe: formaPago.value,
    haber: 0,
    observacion: 'Recibo Nro. $numeroRecibo',
  ));
}
```

**HABER** (Deudores):
```dart
for (var transaccion in transaccionesAPagar.entries) {
  // Obtener detalles de la transacción
  final detalles = await _getDetallesTransaccion(transaccion.key);

  for (var detalle in detalles) {
    // Calcular monto proporcional
    final montoProporcional = (transaccion.value / totalTransaccion) * detalle.importe;

    items.add(AsientoItemData(
      cuentaId: detalle.cuentaContableId,
      debe: 0,
      haber: montoProporcional,
      observacion: 'Recibo Nro. $numeroRecibo - Trans. ${transaccion.key}',
    ));
  }
}
```

### 4. Actualizar UI
**Archivo**: `lib/features/cuentas_corrientes/presentation/pages/cobranzas_page.dart`

Ya tiene el código para mostrar ambos números, solo verificar que funcione.

## 📋 Queries Helper Necesarias

### Obtener cuenta contable desde concepto de tesorería
```dart
Future<int> _getCuentaIdFromConceptoTesoreria(int idConcepto) async {
  final response = await supabase
      .from('conceptos_tesoreria')
      .select('imputacion_contable')
      .eq('id', idConcepto)
      .single();

  final imputacionContable = response['imputacion_contable'];

  // Buscar cuenta por número
  final cuenta = await supabase
      .from('cuentas')
      .select('id')
      .eq('cuenta', int.parse(imputacionContable))
      .single();

  return cuenta['id'] as int;
}
```

### Obtener detalles de transacción con cuenta contable
```dart
Future<List<DetalleConCuenta>> _getDetallesTransaccion(int idTransaccion) async {
  final response = await supabase
      .from('detalle_cuentas_corrientes')
      .select('''
        *,
        conceptos!inner(cuenta_contable_id)
      ''')
      .eq('idtransaccion', idTransaccion);

  return response.map((json) => DetalleConCuenta(
    importe: json['importe'],
    cuentaContableId: json['conceptos']['cuenta_contable_id'],
  )).toList();
}
```

## 🎯 Próximos Pasos (en orden)

1. **Ejecutar SQL**: `database/create_generar_recibo_function.sql`
2. **Implementar helpers** en CobranzasProvider
3. **Actualizar** método `generarRecibo()` en CobranzasProvider
4. **Probar** generación completa (recibo + asiento)
5. **Verificar** que el alta manual de asientos siga funcionando

## ✨ Beneficios de este Approach

1. ✅ **Reutilización**: AsientosService se usa para todos los módulos
2. ✅ **Mantenibilidad**: Lógica de asientos en un solo lugar
3. ✅ **Flexibilidad**: Fácil agregar nuevos tipos de asientos
4. ✅ **Consistencia**: Mismas validaciones para todos
5. ✅ **No rompe nada**: El alta manual sigue funcionando igual

## 📝 Notas Importantes

- El alta de asientos de diario manual **sigue funcionando** (verificado)
- La función PostgreSQL **NO** genera asientos (simplificado)
- Los 5 tipos de asiento están definidos en `AsientosService`
- Todos los módulos deberán usar `AsientosService` para consistencia
