# Facturador Global de Cuotas Sociales

## 📋 Resumen de Implementación

### ✅ Lo que se implementó:

**1. Nuevo Rol: Supervisor**
- Agregado a `UserRole` enum
- Permisos: Puede facturar cuotas masivamente
- Jerarquía: Usuario < Contable < Supervisor < Administrador

**2. Facturador Global**
- Módulo completo para generar cuotas sociales masivamente
- Funciona para socios con grupo 'A' (Asistentes) y 'T' (Titulares)
- Respeta valores de residente/no residente por socio
- Solo genera cuotas para meses faltantes

**3. Características:**
- ✅ Vista previa antes de generar
- ✅ Selección de rango de meses (desde/hasta)
- ✅ Muestra resumen: cantidad de socios, cuotas, importe total
- ✅ Tabla con detalle por socio
- ✅ Barra de progreso durante generación
- ✅ Validación de duplicados (no genera si ya existe)
- ✅ Acceso solo para Supervisor y Administrador

**4. Estructura de código:**
```
lib/features/facturador/
├── models/
│   └── facturacion_previa_model.dart
├── services/
│   └── facturador_service.dart
├── providers/
│   └── facturador_provider.dart
└── presentation/
    └── pages/
        └── facturador_global_page.dart
```

**5. Acceso:**
- Dashboard: Botón "Facturador Global de Cuotas" (verde)
- Visible solo para usuarios con rol Supervisor o Administrador
- Ruta: `/facturador-global`

---

## 🔧 Scripts SQL a Ejecutar

### Script 1: Agregar rol Supervisor
**Archivo:** `database/add_supervisor_role.sql`

```sql
-- Modificar el constraint para incluir el nuevo rol
ALTER TABLE public.usuarios
DROP CONSTRAINT IF EXISTS usuarios_rol_check;

ALTER TABLE public.usuarios
ADD CONSTRAINT usuarios_rol_check
CHECK (rol IN ('usuario', 'contable', 'supervisor', 'administrador'));

-- Verificación
SELECT DISTINCT rol FROM public.usuarios ORDER BY rol;
```

---

## 🎯 Cómo Usar el Facturador Global

### Paso 1: Configurar Roles
1. Ejecutar el script SQL para agregar rol Supervisor
2. Ir a Mantenimiento → Usuarios
3. Asignar rol "Supervisor" a los usuarios que facturarán cuotas

### Paso 2: Facturar Cuotas
1. Desde el Dashboard, click en "Facturador Global de Cuotas"
2. Seleccionar rango de meses:
   - Desde: Mes/Año
   - Hasta: Mes/Año
3. Click "Generar Vista Previa"
4. Revisar:
   - Total de socios afectados
   - Total de cuotas a generar
   - Importe total
   - Detalle por socio
5. Click "Confirmar y Generar Cuotas"
6. Esperar a que termine el proceso (se muestra progreso)

### Paso 3: Verificar
- Las cuotas se generan en `cuentas_corrientes` y `detalle_cuentas_corrientes`
- Tipo de comprobante: 'CS'
- Concepto en detalle: 'CS'
- Valores según `valores_cuota_social` (residente/no residente)

---

## 🔐 Permisos por Rol

| Función | Usuario | Contable | Supervisor | Administrador |
|---------|---------|----------|------------|---------------|
| Ver módulos básicos | ✅ | ✅ | ✅ | ✅ |
| Facturar cuotas masivas | ❌ | ❌ | ✅ | ✅ |
| Acceder a mantenimiento | ❌ | ❌ | ❌ | ✅ |
| Gestionar usuarios | ❌ | ❌ | ❌ | ✅ |
| Eliminar socios | ❌ | ❌ | ❌ | ✅ |

---

## ⚠️ Importante

1. **Solo se generan cuotas faltantes**: El sistema detecta automáticamente qué meses ya tienen cuota creada y solo genera las faltantes.

2. **Grupos incluidos**: Solo 'A' (Asistentes) y 'T' (Titulares). Otros grupos se ignoran.

3. **Valores**: Se toman de la tabla `valores_cuota_social` según:
   - Año/Mes del período
   - Si el socio es residente o no residente

4. **No reversible**: Una vez generadas las cuotas, NO hay función de "deshacer". Solo se pueden eliminar manualmente desde Cuentas Corrientes.

5. **Performance**: Para muchos socios/meses puede tardar. Se muestra progreso en tiempo real.

---

## 📊 Ejemplo de Uso

**Escenario:** Generar cuotas de Enero a Diciembre 2024

1. Selecciono: Desde Enero 2024 - Hasta Diciembre 2024
2. Vista previa muestra:
   - 150 socios (100 Asistentes + 50 Titulares)
   - 1,200 cuotas a generar (algunos socios ya tienen cuotas de algunos meses)
   - Total: $4,500,000
3. Confirmo
4. El sistema genera las 1,200 cuotas en ~30 segundos
5. Listo! ✅
