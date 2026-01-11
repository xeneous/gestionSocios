# Registro Contable de Débitos Automáticos

## Descripción General

Este documento explica cómo funciona el registro contable automático de las presentaciones de débitos automáticos a tarjetas (Visa, Mastercard, etc.).

## Flujo del Proceso

### 1. Generación del Archivo de Presentación

Cuando se genera un archivo para enviar a las tarjetas (Pesos.txt, Visamov.txt, etc.), el sistema:

- Obtiene los CS (Cuota Servicio) pendientes del período
- Filtra por socios adheridos a débito automático y con tarjeta válida
- Genera el archivo en el formato requerido por cada tarjeta

### 2. Registro Contable (NUEVO)

Después de generar y confirmar el archivo de presentación, se debe llamar al método `registrarPresentacionDebitoAutomatico` que:

#### Por cada socio en la presentación:

1. **Crea un comprobante 'DA' (Débito Automático)** en `cuentas_corrientes`:
   - `tipo_comprobante`: 'DA'
   - `socio_id` y `entidad_id`: Identificación del socio
   - `importe`: Total presentado a la tarjeta para ese socio
   - `cancelado`: Mismo valor del importe (se considera cancelado al crearlo)
   - `documento_numero`: Año/mes de la presentación (ej: '202512')
   - `fecha`: Fecha de la presentación
   - `vencimiento`: Fecha de la presentación

2. **Actualiza el campo `cancelado`** en los registros CS originales:
   - Suma el monto presentado al campo `cancelado` existente
   - Permite trackear pagos parciales si el CS tiene un importe mayor

3. **Registra la trazabilidad** en las tablas de operaciones:
   - `operaciones_contables`: Registro maestro de la operación tipo 'DEBITO_AUTOMATICO'
   - `operaciones_detalle_cuentas_corrientes`: Vincula qué CS fueron cancelados y por qué monto

## Uso desde el Código

### Paso 1: Ejecutar la función SQL en Supabase

Primero, ejecutar el script SQL en el SQL Editor de Supabase:

```bash
database/create_registrar_debito_automatico.sql
```

### Paso 2: Llamar al método desde Dart

Después de generar los archivos de presentación, llamar al método:

```dart
import 'package:intl/intl.dart';

// En el servicio o página de débitos automáticos
final service = ref.read(debitosAutomaticosServiceProvider);

try {
  // Obtener los items que se van a presentar
  final items = await service.getMovimientosPendientes(
    anioMes: 202512,
    tarjetaId: tarjetaId, // null para todas
  );

  // Registrar la presentación contable
  final operacionId = await service.registrarPresentacionDebitoAutomatico(
    items: items,
    anioMes: 202512,
    fechaPresentacion: DateTime.now(),
    operadorId: operadorId, // Opcional
  );

  print('Presentación registrada. ID operación: $operacionId');

} catch (e) {
  print('Error al registrar presentación: $e');
  // Si falla, hacer rollback automático (manejado por PostgreSQL)
}
```

## Ejemplo de Datos

### Entrada (items de la presentación)

```dart
List<DebitoAutomaticoItem> items = [
  DebitoAutomaticoItem(
    socioId: 1,
    idtransaccion: 123,
    importe: 32500.00,
    tipoComprobante: 'CS',
    documentoNumero: '202512',
    // ... otros campos
  ),
  DebitoAutomaticoItem(
    socioId: 1,
    idtransaccion: 124,
    importe: 12500.00,
    tipoComprobante: 'CS',
    documentoNumero: '202512',
    // ... otros campos
  ),
  DebitoAutomaticoItem(
    socioId: 2,
    idtransaccion: 125,
    importe: 15000.00,
    tipoComprobante: 'CS',
    documentoNumero: '202512',
    // ... otros campos
  ),
];
```

### Resultado en la BD

#### Tabla `cuentas_corrientes` - Nuevos registros DA creados:

| idtransaccion | socio_id | tipo_comprobante | documento_numero | importe | cancelado | fecha |
|---------------|----------|------------------|------------------|---------|-----------|-------|
| 200 | 1 | DA | 202512 | 45000.00 | 45000.00 | 2025-12-01 |
| 201 | 2 | DA | 202512 | 15000.00 | 15000.00 | 2025-12-01 |

#### Tabla `cuentas_corrientes` - Registros CS actualizados (campo cancelado):

| idtransaccion | tipo_comprobante | importe | cancelado (ANTES) | cancelado (DESPUÉS) |
|---------------|------------------|---------|-------------------|---------------------|
| 123 | CS | 32500.00 | 0.00 | 32500.00 |
| 124 | CS | 12500.00 | 0.00 | 12500.00 |
| 125 | CS | 15000.00 | 0.00 | 15000.00 |

#### Tabla `operaciones_contables`:

| id | tipo_operacion | numero_comprobante | fecha | total | observaciones |
|----|----------------|-------------------|-------|-------|---------------|
| 50 | DEBITO_AUTOMATICO | 202512 | 2025-12-01 | 60000.00 | Presentación DA período 202512 |

#### Tabla `operaciones_detalle_cuentas_corrientes`:

| id | operacion_id | idtransaccion | monto |
|----|--------------|---------------|-------|
| 100 | 50 | 123 | 32500.00 |
| 101 | 50 | 124 | 12500.00 |
| 102 | 50 | 125 | 15000.00 |

## Consultas Útiles

### Ver todas las presentaciones de débitos automáticos:

```sql
SELECT
  oc.id,
  oc.numero_comprobante as periodo,
  oc.fecha,
  oc.total,
  COUNT(odc.id) as cantidad_registros
FROM operaciones_contables oc
LEFT JOIN operaciones_detalle_cuentas_corrientes odc ON oc.id = odc.operacion_id
WHERE oc.tipo_operacion = 'DEBITO_AUTOMATICO'
GROUP BY oc.id
ORDER BY oc.fecha DESC;
```

### Ver el detalle de una presentación específica:

```sql
SELECT
  cc.socio_id,
  s.apellido,
  s.nombre,
  cc.tipo_comprobante,
  cc.documento_numero,
  odc.monto as monto_presentado
FROM operaciones_detalle_cuentas_corrientes odc
JOIN cuentas_corrientes cc ON odc.idtransaccion = cc.idtransaccion
JOIN socios s ON cc.socio_id = s.id
WHERE odc.operacion_id = 50  -- ID de la operación
ORDER BY s.apellido;
```

### Ver qué CS fueron cancelados por débito automático:

```sql
SELECT
  cc.*,
  STRING_AGG(oc.numero_comprobante::TEXT, ', ') as periodos_debito
FROM cuentas_corrientes cc
JOIN operaciones_detalle_cuentas_corrientes odc ON cc.idtransaccion = odc.idtransaccion
JOIN operaciones_contables oc ON odc.operacion_id = oc.id
WHERE cc.tipo_comprobante = 'CS'
  AND oc.tipo_operacion = 'DEBITO_AUTOMATICO'
GROUP BY cc.idtransaccion;
```

## Seguridad y Transacciones

- **Todo es transaccional**: Si algo falla, se hace rollback automático de TODA la operación
- **Validaciones incluidas**:
  - Verifica que existan los CS a cancelar
  - Valida el formato del año/mes
  - Verifica que haya datos para procesar
- **No permite duplicados**: Si se intenta registrar la misma presentación dos veces, fallará porque intentará actualizar los mismos CS

## Próximos Pasos

1. **Generar asiento contable**: Agregar la generación automática del asiento de diario (tipo 1 - Ingreso)
2. **Reversión de presentaciones**: Implementar la funcionalidad para revertir una presentación si es rechazada por la tarjeta
3. **Reportes**: Crear reportes de presentaciones y seguimiento de débitos
