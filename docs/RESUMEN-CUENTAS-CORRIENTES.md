# Resumen Cuentas Corrientes - Documentación

## Descripción General

Módulo para visualizar un listado completo de las cuentas corrientes de todos los socios activos, con funcionalidad de exportación a Excel y envío de emails.

---

## Características

### 📊 Columnas Mostradas

1. **Socio** - ID del socio
2. **Apellido** - Apellido del socio
3. **Nombre** - Nombre del socio
4. **Grupo** - Grupo al que pertenece (si tiene)
5. **Saldo** - Saldo total de la cuenta corriente (importe - cancelado)
6. **RDA Pendiente** - Suma de conceptos RDA pendientes
7. **Teléfono** - Teléfono del socio
8. **Email** - Email del socio
9. **Acción** - Botón para enviar email con resumen

### ⚡ Optimizaciones

- **Función RPC en PostgreSQL** - Todo el procesamiento se hace en el servidor
- **Cálculos en tiempo real** - Los saldos se calculan dinámicamente
- **Filtro automático** - Solo muestra socios activos

### 📈 Estadísticas

El módulo muestra en la parte superior:
- Total de socios activos
- Cantidad de socios con saldo pendiente
- Saldo total general
- Total de RDA pendiente

### 📤 Exportación a Excel

- Botón en el AppBar para exportar
- Genera archivo `.xlsx` con todos los datos
- Formato con encabezados en negrita y fondo azul
- Guarda en la carpeta de Descargas con timestamp
- Formato: `resumen_cuentas_corrientes_YYYYMMDD_HHMMSS.xlsx`

### 📧 Envío de Email

- Botón de email por cada renglón
- Solo habilitado si el socio tiene email
- Confirmación antes de enviar
- Incluye: saldo total y RDA pendiente
- **TODO**: Implementar servicio de email real

---

## Estructura de Archivos

```
lib/features/cuentas_corrientes/
├── models/
│   └── cuenta_corriente_resumen.dart       # Modelo de datos
├── services/
│   └── cuentas_corrientes_service.dart     # Servicio con RPC
├── providers/
│   └── cuentas_corrientes_provider.dart    # Providers Riverpod
└── presentation/pages/
    └── resumen_cuentas_corrientes_page.dart # UI principal

database/
├── functions/
│   └── obtener_resumen_cuentas_corrientes.sql # Función RPC
└── deploy_rpc_functions.sql                    # Script de deploy completo
```

---

## Instalación y Configuración

### 1. Dependencias

Ya están instaladas:
```yaml
dependencies:
  excel: ^4.0.6           # Para exportar a Excel
  path_provider: ^2.1.1   # Para obtener directorio de descargas
```

### 2. Desplegar Función RPC en Supabase

Ejecutar el script SQL en Supabase SQL Editor:

```bash
# Opción 1: Copiar y pegar en Supabase Dashboard
# Ve a: Project → SQL Editor → New Query
# Pega el contenido de: database/deploy_rpc_functions.sql

# Opción 2: Supabase CLI
supabase db push
```

El script creará la función `obtener_resumen_cuentas_corrientes()` que:
- Filtra solo socios activos
- Calcula saldo total por socio (suma de importe - cancelado)
- Calcula RDA pendiente (suma de RDA con saldo > 0)
- Retorna todo en una sola query optimizada

### 3. Verificar Instalación

```sql
-- Verificar que la función existe
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'obtener_resumen_cuentas_corrientes';

-- Probar la función
SELECT * FROM obtener_resumen_cuentas_corrientes();
```

---

## Cómo Usar

### Acceso al Módulo

**Desde el Dashboard:**
1. Ir al Dashboard principal
2. Click en **"Resumen Cuentas Corrientes"** (botón color teal)

**Desde URL directa:**
```
/resumen-cuentas-corrientes
```

**Desde código:**
```dart
context.go('/resumen-cuentas-corrientes');
```

### Exportar a Excel

1. Click en el botón de descarga (📥) en el AppBar
2. El archivo se genera automáticamente
3. Se guarda en la carpeta de Descargas
4. Se muestra un SnackBar con la ruta del archivo

### Enviar Email a un Socio

1. Buscar el socio en la tabla
2. Click en el botón de email (✉️) en la columna "Acción"
3. Confirmar en el diálogo
4. El email se envía con el resumen de saldo y RDA

**Nota:** Por ahora solo simula el envío. Hay que implementar el servicio real.

---

## Código Importante

### Modelo de Datos

```dart
class CuentaCorrienteResumen {
  final int socioId;
  final String apellido;
  final String nombre;
  final String? grupo;
  final double saldo;
  final double rdaPendiente;
  final String? telefono;
  final String? email;

  bool get tieneEmail => email != null && email!.isNotEmpty;
  bool get tieneSaldoPendiente => saldo > 0;
}
```

### Provider

```dart
final resumenCuentasCorrientesProvider =
    FutureProvider<List<CuentaCorrienteResumen>>((ref) async {
  final service = ref.watch(cuentasCorrientesResumenServiceProvider);
  return service.obtenerResumenCuentasCorrientes();
});
```

### Función SQL (Simplificada)

```sql
CREATE OR REPLACE FUNCTION obtener_resumen_cuentas_corrientes()
RETURNS TABLE(...) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id::INTEGER as socio_id,
        s.apellido,
        s.nombre,
        s.grupo,
        COALESCE(SUM(cc.importe - cc.cancelado), 0)::NUMERIC as saldo,
        COALESCE(
            SUM(CASE WHEN cc.tipo_comprobante = 'RDA'
                THEN cc.importe - cc.cancelado ELSE 0 END),
            0
        )::NUMERIC as rda_pendiente,
        s.telefono,
        s.email
    FROM socios s
    LEFT JOIN cuentas_corrientes cc ON cc.socio_id = s.id
    WHERE s.activo = TRUE
    GROUP BY s.id, s.apellido, s.nombre, s.grupo, s.telefono, s.email
    ORDER BY s.apellido, s.nombre;
END;
$$ LANGUAGE plpgsql STABLE;
```

---

## Fallback Mode

Si la función RPC no está disponible, el servicio usa un **método legacy** que:
1. Trae todos los socios activos
2. Por cada socio, consulta sus cuentas corrientes
3. Calcula el saldo en el cliente
4. Filtra RDA pendientes

**⚠️ Advertencia:** El método legacy es **mucho más lento** porque hace N+1 queries.

**Recomendación:** Siempre desplegar la función RPC.

---

## Permisos y Seguridad

### RLS (Row Level Security)

La función RPC respeta las políticas RLS de las tablas:
- `socios` - Debe tener SELECT habilitado para el rol del usuario
- `cuentas_corrientes` - Debe tener SELECT habilitado

### Roles Requeridos

- Usuario debe tener permiso `puedeFacturarMasivo` para ver el botón en Dashboard
- La página es accesible desde la URL para cualquier usuario autenticado

### Configurar Permisos RPC

```sql
-- Permitir que usuarios autenticados ejecuten la función
GRANT EXECUTE ON FUNCTION obtener_resumen_cuentas_corrientes() TO authenticated;
```

---

## TODOs Pendientes

### 1. Implementar Servicio de Email Real

Actualmente el envío de email solo simula con un delay:

```dart
// TODO: Implementar envío de email
Future<void> enviarEmailResumen({
  required int socioId,
  required String email,
  required double saldo,
  required double rdaPendiente,
}) async {
  // Aquí se podría:
  // 1. Llamar a una Cloud Function de Firebase
  // 2. Usar un servicio de email (SendGrid, etc.)
  // 3. Generar PDF con el detalle de la cuenta
}
```

**Opciones:**
- **Firebase Cloud Functions** + SendGrid/Mailgun
- **Edge Functions de Supabase** con Resend
- **API externa** de email marketing

### 2. Abrir Explorador de Archivos

Después de exportar a Excel:

```dart
// TODO: Abrir explorador de archivos
action: SnackBarAction(
  label: 'Abrir carpeta',
  onPressed: () {
    // Implementar open_file o url_launcher
  },
)
```

**Sugerencias:**
- Usar package `url_launcher` para abrir la carpeta
- En Windows: `file:///C:/Users/...`
- En macOS/Linux: `file:///home/...`

### 3. Filtros Adicionales

Agregar filtros opcionales:
- Por grupo
- Por rango de saldo
- Solo socios con saldo > 0
- Solo socios con email

### 4. Detalle de Cuenta

Al hacer click en una fila, mostrar el detalle completo de la cuenta corriente del socio.

---

## Troubleshooting

### Error: "Function does not exist"

**Causa:** La función RPC no está desplegada en Supabase

**Solución:**
```sql
-- Ejecutar en Supabase SQL Editor
-- Copiar contenido de: database/deploy_rpc_functions.sql
```

### Error: "Permission denied for function"

**Causa:** El usuario no tiene permisos EXECUTE en la función

**Solución:**
```sql
GRANT EXECUTE ON FUNCTION obtener_resumen_cuentas_corrientes() TO authenticated;
```

### La exportación a Excel falla

**Causa:** Problemas con path_provider o permisos de escritura

**Solución:**
```dart
// Verificar permisos en Android/iOS
// Agregar en AndroidManifest.xml (Android)
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>

// Agregar en Info.plist (iOS)
<key>UIFileSharingEnabled</key>
<true/>
```

### Datos incorrectos en saldo o RDA

**Causa:** Cálculo incorrecto de `importe - cancelado`

**Solución:**
```sql
-- Verificar datos manualmente
SELECT
  socio_id,
  tipo_comprobante,
  importe,
  cancelado,
  importe - cancelado as saldo_calculado
FROM cuentas_corrientes
WHERE socio_id = 123; -- Reemplazar con ID del socio
```

---

## Performance

### Benchmarks Estimados

Con 1000 socios activos:
- **Con RPC:** ~200-500ms
- **Sin RPC (legacy):** ~5-15 segundos

Con 5000 socios activos:
- **Con RPC:** ~500ms-1s
- **Sin RPC (legacy):** ~30-60 segundos

### Optimizaciones Aplicadas

1. ✅ Función RPC procesa todo en PostgreSQL
2. ✅ LEFT JOIN para incluir socios sin cuentas
3. ✅ GROUP BY para agregar por socio
4. ✅ COALESCE para evitar NULLs
5. ✅ Índices en `socio_id`, `tipo_comprobante`

### Recomendaciones

- Crear índice en `cuentas_corrientes(socio_id, tipo_comprobante)`
- Mantener la tabla `socios` limpia (archivar inactivos)
- Ejecutar `VACUUM ANALYZE` periódicamente

---

## Relacionado con Otros Módulos

### Seguimiento de Deudas
- Usa la misma función RPC optimizada `buscar_socios_con_deuda()`
- También muestra email y permite notificaciones

### Facturador Global
- Genera las cuentas corrientes que este módulo lista
- Los saldos reflejan las facturas generadas

### Débitos Automáticos
- Filtra socios con débito automático
- Complementa con este módulo para ver estado general

---

## Changelog

### v1.0.0 - 2026-01-06
- ✅ Implementación inicial
- ✅ Función RPC optimizada
- ✅ Exportación a Excel
- ✅ UI con estadísticas
- ✅ Botón de email por renglón
- ✅ Integración con Dashboard
- ⏳ Email real (pendiente)
- ⏳ Abrir carpeta después de exportar (pendiente)

---

## Recursos

- [Excel Package Docs](https://pub.dev/packages/excel)
- [Path Provider Docs](https://pub.dev/packages/path_provider)
- [Supabase RPC Docs](https://supabase.com/docs/guides/database/functions)
- [PostgreSQL Aggregate Functions](https://www.postgresql.org/docs/current/functions-aggregate.html)
