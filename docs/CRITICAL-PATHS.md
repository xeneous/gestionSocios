# Código Crítico - Protegido

Este archivo documenta **código que FUNCIONA y está PROBADO**.

⚠️ **REGLA DE ORO**: Antes de modificar cualquier archivo listado aquí, DEBES:
1. Leer el código existente completamente
2. Buscar usos del patrón con Grep
3. Proponer cambios al usuario ANTES de codificar
4. Ejecutar tests (cuando existan)

---

## 🔒 Plan de Cuentas / Asientos Contables

### ✅ Código PROBADO:
- `lib/features/asientos/presentation/pages/asiento_form_page.dart` - Alta manual de asientos
- `lib/features/asientos/services/asientos_service.dart` - Servicio centralizado
- `lib/features/asientos/providers/asientos_provider.dart` - Provider de asientos
- `lib/features/asientos/models/asiento_model.dart` - Modelos de datos

### 🔒 REGLAS CRÍTICAS:

#### 1. **cuentaId NO es un ID de tabla**
```dart
// ❌ INCORRECTO:
final cuenta = await supabase.from('cuentas').select('id').eq('cuenta', numero).single();
itemsAsiento.add(AsientoItemData(cuentaId: cuenta['id']));

// ✅ CORRECTO:
final numeroCuenta = int.parse(imputacionContable);
itemsAsiento.add(AsientoItemData(cuentaId: numeroCuenta));
```

**Razón**: `cuentaId` almacena el NÚMERO de cuenta contable (campo `cuenta` de la tabla `cuentas`), NO el `id` de la tabla.

**Referencias**:
- `asiento_form_page.dart:181` - `item.cuentaId = cuenta.cuenta;`
- `asientos_service.dart:101` - Usa `cuentaId` directamente
- `asiento_model.dart:91` - Mapea a `cuenta_id` en DB (que almacena el número)

#### 2. **Tipos de Asiento (NO modificar)**
```dart
static const int tipoDiario = 0;    // Asiento de diario puro
static const int tipoIngreso = 1;   // Ingreso
static const int tipoEgreso = 2;    // Egreso
static const int tipoCompras = 3;   // Compras
static const int tipoVentas = 4;    // Ventas
```

**Referencia**: `asientos_service.dart:18-23`

#### 3. **AsientosService es centralizado**
- **TODOS** los módulos que generan asientos DEBEN usar `AsientosService`
- NO crear asientos directamente con inserts a DB
- El servicio valida DEBE = HABER automáticamente

**Referencia**: Decisión de arquitectura del usuario - sesión cobranzas 2025-01-03

---

## 🔒 Cuentas Corrientes

### ✅ Código PROBADO:
- `lib/features/cuentas_corrientes/presentation/pages/cuenta_corriente_socio_table_page.dart` - Consulta de saldos
- `database/create_generar_recibo_function.sql` - Función de generación de recibos

### 🔒 REGLAS CRÍTICAS:

#### 1. **Generación de Recibos**
- Usa función PostgreSQL `generar_recibo_cobranza_completo()`
- La función es SECURITY DEFINER (maneja transaccionalidad)
- Crea registro COB (tipo_comprobante='COB', signo=-1)
- Actualiza campo `cancelado` en transacciones
- Genera valores_tesoreria para cada forma de pago

**NO modificar** la función SQL sin revisar toda la lógica transaccional.

---

## 📋 Cómo Usar Este Documento

### Al implementar nueva funcionalidad:

1. **Buscar si afecta código crítico**:
   ```bash
   # ¿Voy a usar asientos?
   grep -r "AsientosService" lib/

   # ¿Voy a usar cuentaId?
   grep -r "cuentaId" lib/features/asientos/
   ```

2. **Leer el código existente**:
   - Ver AL MENOS 2 usos del patrón
   - Entender por qué se hace así

3. **Seguir el patrón existente**:
   - Copiar el approach, no inventar uno nuevo
   - Agregar comentarios con referencias

4. **Documentar si es código nuevo probado**:
   - Agregar a este archivo cuando se prueba
   - Incluir reglas críticas descubiertas

---

## 🚫 Errores Comunes (Lecciones Aprendidas)

### ❌ Asumir que `cuentaId` es FK a `cuentas.id`
**Error real**: Intentar buscar `id` en tabla `cuentas` cuando `cuentaId` ya tiene el número de cuenta.

**Lección**: Siempre buscar usos existentes del campo antes de usarlo.

**Fecha**: 2025-01-03
**Contexto**: Implementación de cobranzas con asientos

---

## 📅 Última Actualización

**Fecha**: 2025-01-03
**Módulos Documentados**: Asientos, Cuentas Corrientes
**Próximo**: Documentar módulo de cobranzas cuando esté probado
