# Convenciones de Código - SAO 2026

Este archivo define las convenciones y patrones establecidos en el proyecto.

⚠️ **IMPORTANTE**: Estas no son sugerencias, son **estándares del proyecto**.

---

## 🏗️ Arquitectura General

### Estructura de Features
```
lib/features/[nombre_modulo]/
  ├── models/           # Modelos de datos
  ├── services/         # Lógica de negocio y acceso a datos
  ├── providers/        # Riverpod providers y notifiers
  └── presentation/     # UI (pages, widgets)
      ├── pages/
      └── widgets/
```

### Patrón de Servicios
- **Servicios** contienen lógica de negocio y acceso a DB
- **Providers** orquestan servicios y manejan estado
- **Pages** solo UI, mínima lógica

---

## 💾 Base de Datos

### Convenciones de Nombrado

#### Tablas
- Snake_case: `cuentas_corrientes`, `asientos_header`
- Plurales para entidades: `socios`, `cuentas`
- Sufijos `_header` / `_items` para header-detail

#### Columnas
- Snake_case: `socio_id`, `fecha_emision`
- PKs: `id` (SERIAL) o nombre descriptivo (`idtransaccion`)
- FKs: `[tabla]_id` (ej: `socio_id`)
- Timestamps: `created_at`, `updated_at`

### Plan de Cuentas

#### ⚠️ CRÍTICO: Estructura de `cuentas`
```sql
CREATE TABLE cuentas (
  id SERIAL PRIMARY KEY,              -- PK interna, no se usa en lógica de negocio
  cuenta INTEGER UNIQUE NOT NULL,     -- Número de cuenta (este se usa en asientos)
  descripcion VARCHAR(100) NOT NULL,
  imputable BOOLEAN DEFAULT false,
  ...
);
```

**Regla**: En código Dart, cuando usas `cuentaId`, estás usando el NÚMERO de cuenta (`cuenta`), NO el `id`.

#### Asientos Contables
```sql
CREATE TABLE asientos_items (
  ...
  cuenta_id INTEGER,  -- ⚠️ Almacena el NÚMERO de cuenta, no FK a cuentas.id
  debe NUMERIC(18,2),
  haber NUMERIC(18,2),
  ...
);
```

**Por qué**: Compatibilidad con sistema legacy, simplicidad en queries de reportes.

---

## 🎯 Dart / Flutter

### Providers (Riverpod)

#### Naming
```dart
// Service provider (Provider)
final [modulo]ServiceProvider = Provider<[Modulo]Service>(...);

// Notifier provider (NotifierProvider)
final [modulo]NotifierProvider = NotifierProvider<[Modulo]Notifier, State>(...);

// Data provider (FutureProvider/StreamProvider)
final [entidad]Provider = FutureProvider<List<Entidad>>(...);
```

#### Estructura de Notifier
```dart
class [Modulo]Notifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> operacion() async {
    state = const AsyncValue.loading();
    try {
      // Lógica
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
```

### Modelos

#### Naming
- Archivo: `[entidad]_model.dart`
- Clase: `[Entidad]` (sin sufijo Model)
- Usar `freezed` solo si necesario (inmutabilidad, copyWith, etc)

#### Serialización
```dart
class Entidad {
  factory Entidad.fromJson(Map<String, dynamic> json) => ...;
  Map<String, dynamic> toJson() => ...;
}
```

### Servicios

#### Estructura
```dart
class [Modulo]Service {
  final SupabaseClient _supabase;

  [Modulo]Service(this._supabase);

  // Métodos públicos
  Future<T> operacion() async { ... }

  // Métodos privados (helpers)
  Future<void> _helper() async { ... }
}
```

---

## 📊 Asientos Contables

### Tipos de Asiento (INMUTABLES)
```dart
static const int tipoDiario = 0;    // Asiento de diario puro
static const int tipoIngreso = 1;   // Ingreso
static const int tipoEgreso = 2;    // Egreso
static const int tipoCompras = 3;   // Compras
static const int tipoVentas = 4;    // Ventas
```

### Uso de AsientosService

#### ✅ SIEMPRE hacer:
```dart
// 1. Obtener servicio
final asientosService = ref.read(asientosServiceProvider);

// 2. Preparar items
final items = <AsientoItemData>[
  AsientoItemData(
    cuentaId: 11010101,  // Número de cuenta, NO id de tabla
    debe: 1000.0,
    haber: 0.0,
    observacion: 'Detalle',
  ),
];

// 3. Crear asiento
final numeroAsiento = await asientosService.crearAsiento(
  tipoAsiento: AsientosService.tipoIngreso,
  fecha: DateTime.now(),
  detalle: 'Descripción del asiento',
  items: items,
);
```

#### ❌ NUNCA hacer:
```dart
// ❌ NO crear asientos con inserts directos
await supabase.from('asientos_header').insert(...);

// ❌ NO buscar id de cuenta para cuentaId
final cuenta = await supabase.from('cuentas').select('id')...;
items.add(AsientoItemData(cuentaId: cuenta['id']));  // ¡INCORRECTO!

// ❌ NO validar manualmente DEBE=HABER (el servicio lo hace)
if (totalDebe != totalHaber) throw ...;  // AsientosService ya valida
```

---

## 🧪 Testing

### Estructura de Tests
```
test/
  ├── unit/              # Tests unitarios de servicios/modelos
  ├── integration/       # Tests de integración (DB, múltiples servicios)
  └── widget/            # Tests de widgets
```

### Naming
```dart
// Archivo: [cosa_a_testear]_test.dart
// Grupo: describe/group('[NombreClase]')
// Test: test('should [comportamiento esperado] when [condición]')

group('AsientosService', () {
  test('should create asiento when items are balanced', () async {
    // Arrange
    // Act
    // Assert
  });
});
```

---

## 📝 Comentarios y Documentación

### Cuándo Comentar

#### ✅ SIEMPRE comentar:
- Decisiones no obvias
- Referencias a código existente
- Workarounds temporales
- Reglas de negocio importantes

```dart
// El cuentaId es el NÚMERO de cuenta, no un ID de tabla
// Esto es consistente con el alta de asientos manual (asiento_form_page.dart:181)
final numeroCuenta = int.parse(imputacionContable);
```

#### ❌ NO comentar:
- Código auto-explicativo
- Repetir lo que dice el código

```dart
// ❌ Malo
// Incrementa el contador
contador++;

// ✅ Bueno (si no es obvio por qué)
// Usamos contador+1 porque el sistema legacy empieza en 1, no en 0
contador++;
```

### Documentación de APIs Públicas
```dart
/// Crea un asiento de diario completo de forma transaccional
///
/// Parámetros:
/// - tipoAsiento: Tipo de asiento (0-4)
/// - fecha: Fecha del asiento
/// - items: Lista de items (DEBE y HABER)
///
/// Validaciones:
/// - El asiento debe estar balanceado (DEBE = HABER)
/// - Debe tener al menos un item
///
/// Retorna:
/// - El número de asiento generado
///
/// Throws:
/// - Exception si el asiento no está balanceado
Future<int> crearAsiento({...}) async { ... }
```

---

## 🔄 Workflows

### Proceso de Implementación de Nueva Feature

1. **Investigar código existente**
   ```bash
   # ¿Ya existe algo similar?
   grep -r "concepto similar" lib/
   ```

2. **Leer CRITICAL-PATHS.md**
   - ¿Afecta código probado?
   - ¿Hay reglas que debo seguir?

3. **Seguir convenciones**
   - Estructura de carpetas
   - Naming
   - Patrones establecidos

4. **Documentar decisiones importantes**
   - Actualizar CRITICAL-PATHS.md si es código probado
   - Agregar comentarios con referencias

### Modificación de Código Existente

1. **STOP ⛔**
   - ¿Está en CRITICAL-PATHS.md?
   - ¿Hay tests que validen?

2. **Leer código completamente**
   - Entender qué hace
   - Buscar todos los usos

3. **Proponer cambios ANTES de codificar**
   - Explicar impacto
   - Mostrar alternativas

4. **Ejecutar tests**
   - Verificar que nada se rompió

---

## 🚀 Deployment

### Checklist Pre-Deploy
- [ ] Tests pasan
- [ ] No hay TODOs críticos sin resolver
- [ ] Documentación actualizada (si aplica)
- [ ] CRITICAL-PATHS.md actualizado (si nuevo código probado)

---

## 📅 Última Actualización

**Fecha**: 2025-01-03
**Autor**: Sistema
**Cambios**: Creación inicial con convenciones de asientos y plan de cuentas
