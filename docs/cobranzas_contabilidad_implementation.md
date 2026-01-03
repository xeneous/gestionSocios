# Implementación de Cobranzas con Integración Contable

## Resumen

Se ha implementado la funcionalidad completa de generación de recibos de cobranza con integración contable automática. El sistema genera:

1. **Recibo de cobranza** (valores_tesoreria)
2. **Registro COB** en cuentas corrientes
3. **Asiento de diario** balanceado (DEBE = HABER)

Todo en una única transacción atómica (commit o rollback).

## Arquitectura de la Solución

### 1. Función PostgreSQL Transaccional

**Archivo**: `database/create_generar_recibo_cobranza_completo.sql`

La función `generar_recibo_cobranza` realiza:

1. **Validaciones**:
   - Verifica que haya transacciones y formas de pago
   - Valida que los totales coincidan (tolerancia 0.01)
   - Verifica que el asiento esté balanceado (DEBE = HABER)

2. **Obtiene numeración secuencial**:
   - Número de recibo (RECIBO)
   - Número de asiento (ASIENTO)

3. **Crea valores de tesorería**:
   - Un registro por cada forma de pago
   - tipo_movimiento = 1 (Ingreso)
   - Marca como cancelado al crearlo

4. **Actualiza cuentas corrientes**:
   - Incrementa el campo `cancelado` de cada transacción pagada
   - Proporcional al monto pagado

5. **Crea registro COB**:
   - tipo_comprobante = 'COB'
   - documento_numero = número de recibo
   - importe = total cobrado
   - signo = -1 (disminuye deuda)

6. **Genera asiento de diario**:
   - **Header**: Asiento con detalle "Cobranza Recibo Nro. XXX"
   - **Items DEBE**: Desde conceptos_tesoreria.imputacion_contable
   - **Items HABER**: Desde conceptos.cuenta_contable_id (vía detalle_cuentas_corrientes)
   - **Validación**: DEBE = HABER (partida doble)

### 2. Estructura del Asiento

#### DEBE (Débito)
Representa las cuentas de caja/banco donde ingresa el dinero:

```
Para cada forma de pago:
  - Cuenta: conceptos_tesoreria.imputacion_contable
  - Monto: monto de la forma de pago
  - Ejemplo: "Caja Efectivo" $100.00
```

#### HABER (Crédito)
Representa las cuentas de deudores que se están cancelando:

```
Para cada transacción pagada:
  Para cada detalle de la transacción:
    - Cuenta: conceptos.cuenta_contable_id
    - Monto: proporcional al pago (monto_pago / importe_total) * importe_detalle
    - Ejemplo: "Deudores Socios - Cuota Social" $100.00
```

### 3. Cálculo Proporcional

Cuando se paga parcialmente una transacción, el sistema calcula proporcionalmente cuánto corresponde a cada concepto:

```
Transacción:
  - Concepto A: $60 (60%)
  - Concepto B: $40 (40%)
  - Total: $100

Pago parcial de $50:
  - HABER Concepto A: $30 (50% de 60)
  - HABER Concepto B: $20 (50% de 40)
```

## Archivos Modificados/Creados

### SQL
1. ✅ `database/create_generar_recibo_cobranza_completo.sql` - Función principal
   - Reemplaza la función anterior
   - Agrega COB y asiento de diario

### Dart/Flutter
1. ✅ `lib/features/cuentas_corrientes/services/cobranzas_service.dart`
   - Retorna `Map<String, int>` con numero_recibo y numero_asiento

2. ✅ `lib/features/cuentas_corrientes/providers/cobranzas_provider.dart`
   - Actualizado para retornar ambos números

3. ✅ `lib/features/cuentas_corrientes/presentation/pages/cobranzas_page.dart`
   - Muestra número de recibo y asiento en el diálogo de éxito

## Requisitos de Configuración

### 1. Tablas Necesarias
- ✅ `conceptos_tesoreria` - con campo `imputacion_contable`
- ✅ `valores_tesoreria` - con sequence para auto-increment
- ✅ `cuentas_corrientes` - con soporte para tipo_comprobante 'COB'
- ✅ `detalle_cuentas_corrientes` - vinculada con conceptos
- ✅ `conceptos` - con campo `cuenta_contable_id`
- ✅ `cuentas` - plan de cuentas contable
- ✅ `asientos_header` - encabezados de asientos
- ✅ `asientos_items` - items de asientos
- ✅ `numeradores` - con 'RECIBO' y 'ASIENTO'

### 2. Datos Maestros Requeridos

**Conceptos de Tesorería**:
- Cada concepto debe tener `imputacion_contable` configurado
- Ejemplo: id=1, descripcion="Efectivo", imputacion_contable="1101" (Caja)

**Conceptos de Socios**:
- Cada concepto debe tener `cuenta_contable_id` configurado
- Ejemplo: concepto="CUS", cuenta_contable_id=123 (Deudores Socios)

**Plan de Cuentas**:
- Las cuentas deben existir en la tabla `cuentas`
- El campo `cuenta` debe coincidir con `imputacion_contable`

**Tipos de Comprobante**:
- Debe existir 'COB' en tipos_comprobante_socios
- Con signo=-1 (disminuye deuda) y id_tipo_movimiento=2 (Crédito)

## Pasos para Desplegar

### 1. Ejecutar SQL
```bash
# Conectarse a Supabase y ejecutar:
database/create_generar_recibo_cobranza_completo.sql
```

Este script:
- Crea/reemplaza la función `generar_recibo_cobranza`
- Agrega el numerador 'ASIENTO' si no existe

### 2. Verificar Configuración

```sql
-- Verificar que conceptos_tesoreria tienen imputación contable
SELECT id, descripcion, imputacion_contable
FROM conceptos_tesoreria
WHERE imputacion_contable IS NULL OR imputacion_contable = '';

-- Verificar que conceptos tienen cuenta contable
SELECT concepto, descripcion, cuenta_contable_id
FROM conceptos
WHERE cuenta_contable_id IS NULL;

-- Verificar numeradores
SELECT * FROM numeradores WHERE tipo IN ('RECIBO', 'ASIENTO');
```

### 3. Probar Funcionamiento

1. Ingresar al módulo de Cobranzas
2. Seleccionar un socio con deuda
3. Marcar transacciones a pagar
4. Seleccionar formas de pago
5. Generar recibo
6. Verificar:
   - Recibo generado
   - Asiento generado
   - COB creado en cuentas_corrientes
   - Saldos actualizados

## Validaciones Implementadas

1. ✅ **Balance de pagos**: Total a pagar = Total formas de pago
2. ✅ **Balance contable**: DEBE = HABER (partida doble)
3. ✅ **Existencia de cuentas**: Todas las cuentas deben existir
4. ✅ **Transacciones válidas**: Las transacciones deben existir
5. ✅ **Configuración completa**: Conceptos con cuentas asignadas

## Errores Comunes

### Error: "Concepto de tesorería X no tiene imputación contable"
**Solución**: Configurar el campo `imputacion_contable` en la tabla `conceptos_tesoreria`

```sql
UPDATE conceptos_tesoreria
SET imputacion_contable = '1101'  -- Código de cuenta
WHERE id = X;
```

### Error: "Concepto X no tiene cuenta contable configurada"
**Solución**: Asignar `cuenta_contable_id` al concepto

```sql
UPDATE conceptos
SET cuenta_contable_id = (SELECT id FROM cuentas WHERE cuenta = 1301)
WHERE concepto = 'CUS';
```

### Error: "No se encontró cuenta contable X"
**Solución**: Verificar que la cuenta exista en el plan de cuentas

```sql
SELECT * FROM cuentas WHERE cuenta::VARCHAR = 'X';
```

### Error: "El asiento no está balanceado"
**Solución**: Revisar:
1. Que todos los conceptos tengan cuenta contable
2. Que los importes sean correctos
3. Que no haya redondeos excesivos

## Próximas Mejoras

1. **Anulación de recibos**: Implementar función para anular recibos
2. **Reportes**: Libro de cobranzas, libro de asientos
3. **Auditoría**: Log de cambios en valores_tesoreria y asientos
4. **Validación adicional**: Verificar que cuentas sean imputables
5. **Centro de costo**: Agregar soporte para centros de costo

## Notas Técnicas

### Atomicidad
Todo el proceso se ejecuta en una única transacción PostgreSQL. Si cualquier paso falla, se hace rollback automático de todos los cambios.

### Performance
La función utiliza índices existentes en:
- cuentas_corrientes(idtransaccion)
- detalle_cuentas_corrientes(idtransaccion)
- conceptos(concepto)
- cuentas(cuenta)

### Seguridad
- Función marcada como `SECURITY DEFINER`
- Validaciones estrictas de datos
- RLS policies en todas las tablas

## Referencias

- [Función PostgreSQL](../database/create_generar_recibo_cobranza_completo.sql)
- [Servicio Dart](../lib/features/cuentas_corrientes/services/cobranzas_service.dart)
- [Provider](../lib/features/cuentas_corrientes/providers/cobranzas_provider.dart)
- [UI](../lib/features/cuentas_corrientes/presentation/pages/cobranzas_page.dart)
