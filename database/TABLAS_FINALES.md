# SAO 2026 - Tablas Finales del Sistema

## Resumen Completo de Tablas PostgreSQL

Total de tablas: **31 tablas**

---

## 1. TABLAS DE REFERENCIA (3)
- `provincias` - Provincias de Argentina
- `categorias_iva` - Categorías de IVA
- `grupos_agrupados` - Grupos/categorías de socios

## 2. CONTABILIDAD CORE (3)
- `cuentas` - Plan de cuentas contable
- `asientos_header` - Encabezados de asientos diarios
- `asientos_items` - Líneas/ítems de asientos diarios

## 3. ENTIDADES (4)
- `socios` - Miembros de la SAO
- `profesionales` - Profesionales/médicos
- `clientes` - Clientes
- `proveedores` - Proveedores/Suppliers

## 4. OBSERVACIONES Y CONTACTOS (4)
- `observaciones_socios` - Notas/observaciones de socios
- `contactos_proveedores` - Contactos de proveedores
- `contactos_clientes` - Contactos de clientes

## 5. FACTURACIÓN Y CONCEPTOS (4)
- `conceptos` - Conceptos de facturación (cuotas, cargos)
- `conceptos_socios` - Asignación de conceptos a socios
- `conceptos_profesionales` - Asignación de conceptos a profesionales
- `cuentas_corrientes` - Cuenta corriente de socios
- `detalle_cuentas_corrientes` - Detalle de CC

## 6. COMPRAS (4)
- `tipos_comprobante_compra` - Tipos de comprobante compra
- `tipos_comprobante_compra_items` - Config de tipos compra
- `compras_header` - Encabezados de compras
- `compras_items` - Líneas de compras

## 7. VENTAS (4)
- `tipos_comprobante_venta` - Tipos de comprobante venta
- `tipos_comprobante_venta_items` - Config de tipos venta
- `ventas_header` - Encabezados de ventas
- `ventas_items` - Líneas de ventas

## 8. TESORERÍA (2)
- `conceptos_tesoreria` - Conceptos de tesorería (cheques, efectivo, etc.)
- `valores_tesoreria` - Valores de tesorería (cheques, transferencias)

## 9. TARJETAS/PAGOS (2)
- `tarjetas` - Tarjetas de crédito/débito
- `presentaciones_tarjetas` - Presentaciones/lotes de tarjetas

---

## Tabla de Resumen por Prioridad

| Prioridad | Cantidad | Tablas |
|-----------|----------|--------|
| 🔴 CRÍTICO | 8 | cuentas, asientos_*, socios, conceptos, cuentas_corrientes, compras_*, ventas_* |
| 🟡 ALTA | 12 | clientes, proveedores, profesionales, tipos_comprobante_*, contactos_*, conceptos_socios |
| 🟢 MEDIA | 11 | referencia, observaciones, tesorería, tarjetas, presentaciones |

---

## Cambios Respecto al Schema SQL Server Original

### Tablas Consolidadas
- `VenCliHeader` → `ventas_header`
- `CompProvHeader` → `compras_header`  
- `TipCompModHeader` → `tipos_comprobante_compra`
- `tipventModHeader` → `tipos_comprobante_venta`
- `ValoresTesoreria` → `valores_tesoreria`
- `Conceptos_tesoreria` → `conceptos_tesoreria`
- `ContactosProveedores` → `contactos_proveedores`

### Campos Simplificados
- **socios**: De 70+ campos a ~30 (eliminó domicilio duplicado, cobradores, seguros)
- **conceptos**: De 16 campos a 9 (eliminó campos municipales y seguros)
- **clientes/proveedores**: De 6 teléfonos a 2

### Normalizaciones
- Separación de observaciones a tabla independiente
- IDs auto-incrementales (SERIAL) en lugar de IDENTITY
- Uso de BOOLEAN en lugar de TINYINT/CHAR(1)
- FKs con ON DELETE CASCADE donde corresponde

---

## Próximos Pasos

1. ✅ Schema PostgreSQL completado
2. ⏳ Crear proyecto Supabase
3. ⏳ Ejecutar migrations
4. ⏳ Iniciar proyecto Flutter Web
5. ⏳ Desarrollar módulos por prioridad

---

## Validación del Schema

Total confirmado con usuario: **31 tablas** ✅

Todas las tablas críticas incluidas:
- ✅ Contabilidad (plan cuentas, asientos)
- ✅ Socios y contactos
- ✅ Compras y ventas
- ✅ Tesorería
- ✅ Facturación (conceptos, CC)
- ✅ Referencias (provincias, IVA, etc.)
