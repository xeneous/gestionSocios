# Workflow de Claude - Protocolo Obligatorio

Este documento define el **proceso que Claude DEBE seguir** en cada implementación para evitar romper código existente.

---

## 🎯 Objetivo

**Prevenir regresiones y trabajo redundante** siguiendo un protocolo estricto antes de escribir código.

---

## 📋 Protocolo Obligatorio

### Antes de CUALQUIER implementación nueva:

```
┌─────────────────────────────────────────────────────────┐
│ 1. ¿EXISTE CÓDIGO SIMILAR?                              │
│    → Grep/Glob para buscar implementaciones existentes  │
│    → Leer AL MENOS 2 ejemplos completos                 │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 2. ¿AFECTA CÓDIGO CRÍTICO?                              │
│    → Revisar docs/CRITICAL-PATHS.md                     │
│    → Si está listado → STOP y seguir reglas             │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 3. ¿CÓMO SE HACE AQUÍ?                                  │
│    → Revisar docs/coding-conventions.md                 │
│    → Identificar patrón establecido                     │
│    → Buscar convenciones de naming                      │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 4. PROPONER ANTES DE CODIFICAR                          │
│    → Explicar approach al usuario                       │
│    → Mostrar patrón que seguiré                         │
│    → ESPERAR aprobación                                 │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 5. IMPLEMENTAR CON REFERENCIAS                          │
│    → Seguir patrón identificado                         │
│    → Agregar comentarios con referencias                │
│    → Documentar decisiones no obvias                    │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│ 6. VERIFICAR IMPACTO                                    │
│    → Listar archivos modificados                        │
│    → Mencionar qué podría verse afectado                │
│    → Recomendar tests necesarios                        │
└─────────────────────────────────────────────────────────┘
```

---

## 🔍 Ejemplos Concretos

### Caso 1: Usar un campo existente (`cuentaId`)

#### ❌ Proceso INCORRECTO (lo que NO hacer):
```
1. Leo schema → Veo tabla `cuentas` con `id` y `cuenta`
2. Asumo que `cuentaId` es FK a `cuentas.id`
3. Escribo código que busca el `id`
4. ❌ FALLA porque `cuentaId` es el número, no el id
```

#### ✅ Proceso CORRECTO (lo que DEBO hacer):
```
1. STOP → "Voy a usar cuentaId, ¿cómo se usa aquí?"

2. GREP:
   grep -r "cuentaId" lib/features/asientos/

3. LEER ejemplos:
   - asiento_form_page.dart:181 → item.cuentaId = cuenta.cuenta;
   - asientos_service.dart:101 → usa cuentaId directamente

4. IDENTIFICAR patrón:
   "cuentaId almacena el NÚMERO de cuenta, no un id de tabla"

5. PROPONER:
   "Encontré que cuentaId se usa así: [mostrar patrón]
    Voy a hacer lo mismo. ¿Procedo?"

6. CODIFICAR con comentario:
   // El cuentaId es el NÚMERO de cuenta, no un ID de tabla
   // Esto es consistente con el alta de asientos manual (asiento_form_page.dart:181)
   final numeroCuenta = int.parse(imputacionContable);
```

### Caso 2: Modificar código en CRITICAL-PATHS.md

#### ❌ Proceso INCORRECTO:
```
1. Usuario pide mejorar AsientosService
2. Modifico directamente el código
3. ❌ Rompo el alta manual de asientos que depende del comportamiento exacto
```

#### ✅ Proceso CORRECTO:
```
1. STOP → "AsientosService está en CRITICAL-PATHS.md"

2. LEER reglas:
   - Es servicio centralizado
   - Valida DEBE=HABER automáticamente
   - Usado por múltiples módulos

3. ANALIZAR impacto:
   grep -r "AsientosService" lib/
   # Encuentro: asientos_provider.dart, cobranzas_provider.dart

4. PROPONER:
   "AsientosService es código crítico usado por:
    - Alta manual de asientos
    - Generación automática en cobranzas

    Cambio propuesto: [explicar]
    Posibles afectados: [listar]

    Alternativa: Crear método nuevo sin modificar existente

    ¿Qué prefieres?"

5. ESPERAR decisión del usuario
```

---

## 🛠️ Comandos Útiles

### Buscar implementaciones existentes
```bash
# Buscar uso de un modelo/clase
grep -r "AsientosService" lib/

# Buscar uso de un campo
grep -r "cuentaId" lib/features/asientos/

# Buscar patrón similar
grep -r "\.single()" lib/ | grep "from('cuentas')"

# Ver archivos que usan cierta tabla
grep -r "from('valores_tesoreria')" lib/
```

### Verificar si código es crítico
```bash
# ¿Está documentado como crítico?
grep -i "asientos" docs/CRITICAL-PATHS.md

# ¿Tiene tests?
ls test/**/*asientos*
```

---

## ⚠️ Red Flags - Cuándo DETENERME

Si encuentro cualquiera de estos, DEBO pausar y consultar:

1. **Modificar código en CRITICAL-PATHS.md**
   - Puede romper funcionalidad probada

2. **Crear patrón diferente para algo que ya existe**
   - Ejemplo: Nueva forma de crear asientos cuando AsientosService existe

3. **Asumir estructura de datos sin verificar**
   - Ejemplo: Asumir que `cuenta_id` es FK sin buscar usos

4. **Modificar múltiples archivos críticos**
   - Alto riesgo de efectos secundarios

5. **No encontrar ejemplos de cómo se hace algo**
   - Probablemente estoy inventando algo nuevo → Consultar

---

## 📊 Checklist Pre-Implementación

Antes de escribir código, verifico:

- [ ] Busqué código similar existente (Grep/Glob)
- [ ] Leí AL MENOS 2 ejemplos completos
- [ ] Revisé CRITICAL-PATHS.md
- [ ] Revisé coding-conventions.md
- [ ] Identifiqué el patrón a seguir
- [ ] Propuse approach al usuario (si es cambio significativo)
- [ ] Tengo referencias claras para comentarios

**Si algún checkbox está vacío → NO codifico todavía**

---

## 📝 Template de Propuesta

Cuando debo proponer un cambio:

```
## Análisis del Código Existente

He encontrado que [X] se implementa así:
- Archivo: [ruta:línea]
- Patrón: [descripción]
- Usado en: [listar lugares]

## Cambio Propuesto

Voy a [descripción del cambio]

Seguiré este patrón: [explicar]

## Posibles Impactos

Archivos afectados:
- [archivo1] - [por qué]
- [archivo2] - [por qué]

Código que podría verse afectado:
- [módulo1] - [cómo lo usa]

## Alternativas Consideradas

1. [Opción A]: [pros/cons]
2. [Opción B]: [pros/cons]

¿Procedo con [opción elegida]?
```

---

## 🎓 Lecciones Aprendidas

### Error: Asumir que `cuentaId` es FK
- **Fecha**: 2025-01-03
- **Contexto**: Implementación cobranzas
- **Error**: Busqué `id` en tabla `cuentas` para `cuentaId`
- **Corrección**: `cuentaId` es el número de cuenta directamente
- **Lección**: SIEMPRE buscar usos existentes de un campo antes de usarlo

### [Agregar más lecciones a medida que surjan]

---

## 📅 Última Actualización

**Fecha**: 2025-01-03
**Propósito**: Establecer protocolo estricto para evitar regresiones
**Aplicable a**: Todos los proyectos con Claude
