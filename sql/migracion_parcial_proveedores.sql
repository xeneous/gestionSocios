-- ============================================================
-- MIGRACIÓN PARCIAL SAO 2026
-- Alcance: Proveedores, Clientes, Comprobantes Compras/Ventas,
--          Valores Tesorería asociados, Notas Imputación,
--          Operaciones Contables, Asientos Header+Items
-- Fecha:   2026-03-07
--
-- INTACTO: socios, recertificaciones, archivos, observaciones,
--          cuentas_corrientes (socios/prof), rechazos, presentaciones,
--          profesionales, valores_tesoreria de socios/profesionales,
--          asientos de socios/profesionales
--
-- ESTRATEGIA:
--   0. Crear _bak_0703 de todas las tablas productivas a tocar  (0 riesgo)
--   1. Cargar datos nuevos en tablas _new (staging)             (0 riesgo)
--   2. Ejecutar FASE 2 (validación) y corregir si hay errores   (0 riesgo)
--   3. Ejecutar FASE 3 (swap) cuando validación sea OK          (⚠️ modifica prod)
--   4. FASE 4 es rollback de emergencia desde _bak_0703
-- ============================================================


-- ============================================================
-- FASE 0 — BACKUP DE TABLAS PRODUCTIVAS
-- Ejecutar PRIMERO, antes de cualquier otra cosa.
-- Crea snapshots inmutables del estado actual de producción.
-- Estas tablas NO se tocan en ninguna fase posterior.
-- ============================================================

-- 0.1 Backup completo de tablas de entidades
CREATE TABLE proveedores_bak_0703      AS SELECT * FROM proveedores;
CREATE TABLE clientes_bak_0703         AS SELECT * FROM clientes;

-- 0.2 Backup completo de comprobantes
CREATE TABLE comp_prov_header_bak_0703 AS SELECT * FROM comp_prov_header;
CREATE TABLE comp_prov_items_bak_0703  AS SELECT * FROM comp_prov_items;
CREATE TABLE ven_cli_header_bak_0703   AS SELECT * FROM ven_cli_header;
CREATE TABLE ven_cli_items_bak_0703    AS SELECT * FROM ven_cli_items;

-- 0.3 Backup selectivo de valores_tesoreria
--     Solo los vinculados a comp_prov o ven_cli (el resto queda intacto en prod)
CREATE TABLE valores_tesoreria_bak_0703 AS
  SELECT * FROM valores_tesoreria
  WHERE idtransaccion_origen IN (
    SELECT id_transaccion FROM comp_prov_header
    UNION ALL
    SELECT id_transaccion FROM ven_cli_header
  );

-- 0.4 Backup selectivo de notas_imputacion (solo OPs proveedores)
CREATE TABLE notas_imputacion_bak_0703 AS
  SELECT * FROM notas_imputacion
  WHERE tipo_operacion = 1;

-- 0.5 Backup selectivo de operaciones_contables + detalle
CREATE TABLE operaciones_contables_bak_0703 AS
  SELECT * FROM operaciones_contables
  WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE');

CREATE TABLE operaciones_detalle_bak_0703 AS
  SELECT * FROM operaciones_detalle_valores_tesoreria
  WHERE operacion_id IN (
    SELECT id FROM operaciones_contables
    WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE')
  );

-- 0.6 Backup selectivo de asientos (solo los de proveedores/clientes)
CREATE TABLE asientos_header_bak_0703 AS
  SELECT * FROM asientos_header
  WHERE (asiento, anio_mes, tipo_asiento) IN (
    SELECT asiento_numero, asiento_anio_mes, asiento_tipo
    FROM operaciones_contables
    WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE')
      AND asiento_numero IS NOT NULL
  );

CREATE TABLE asientos_items_bak_0703 AS
  SELECT * FROM asientos_items
  WHERE (asiento, anio_mes, tipo_asiento) IN (
    SELECT asiento_numero, asiento_anio_mes, asiento_tipo
    FROM operaciones_contables
    WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE')
      AND asiento_numero IS NOT NULL
  );

-- 0.7 Verificar que los backups se crearon correctamente
SELECT 'proveedores_bak_0703'      AS tabla, COUNT(*) FROM proveedores_bak_0703
UNION ALL
SELECT 'clientes_bak_0703'         AS tabla, COUNT(*) FROM clientes_bak_0703
UNION ALL
SELECT 'comp_prov_header_bak_0703' AS tabla, COUNT(*) FROM comp_prov_header_bak_0703
UNION ALL
SELECT 'comp_prov_items_bak_0703'  AS tabla, COUNT(*) FROM comp_prov_items_bak_0703
UNION ALL
SELECT 'ven_cli_header_bak_0703'   AS tabla, COUNT(*) FROM ven_cli_header_bak_0703
UNION ALL
SELECT 'ven_cli_items_bak_0703'    AS tabla, COUNT(*) FROM ven_cli_items_bak_0703
UNION ALL
SELECT 'valores_tesoreria_bak_0703'   AS tabla, COUNT(*) FROM valores_tesoreria_bak_0703
UNION ALL
SELECT 'notas_imputacion_bak_0703'    AS tabla, COUNT(*) FROM notas_imputacion_bak_0703
UNION ALL
SELECT 'operaciones_contables_bak_0703' AS tabla, COUNT(*) FROM operaciones_contables_bak_0703
UNION ALL
SELECT 'operaciones_detalle_bak_0703' AS tabla, COUNT(*) FROM operaciones_detalle_bak_0703
UNION ALL
SELECT 'asientos_header_bak_0703'  AS tabla, COUNT(*) FROM asientos_header_bak_0703
UNION ALL
SELECT 'asientos_items_bak_0703'   AS tabla, COUNT(*) FROM asientos_items_bak_0703;


-- ============================================================
-- FASE 1 — CREAR TABLAS STAGING
-- Ejecutar UNA SOLA VEZ para crear la estructura.
-- Luego cargar datos en cada tabla _new via CSV o INSERT.
-- ============================================================

-- 1.1 proveedores_new
DROP TABLE IF EXISTS proveedores_new;
CREATE TABLE proveedores_new (LIKE proveedores INCLUDING ALL);

-- 1.2 clientes_new
DROP TABLE IF EXISTS clientes_new;
CREATE TABLE clientes_new (LIKE clientes INCLUDING ALL);

-- 1.3 comp_prov_header_new
DROP TABLE IF EXISTS comp_prov_header_new;
CREATE TABLE comp_prov_header_new (LIKE comp_prov_header INCLUDING ALL);

-- 1.4 comp_prov_items_new
DROP TABLE IF EXISTS comp_prov_items_new;
CREATE TABLE comp_prov_items_new (LIKE comp_prov_items INCLUDING ALL);

-- 1.5 ven_cli_header_new
DROP TABLE IF EXISTS ven_cli_header_new;
CREATE TABLE ven_cli_header_new (LIKE ven_cli_header INCLUDING ALL);

-- 1.6 ven_cli_items_new
DROP TABLE IF EXISTS ven_cli_items_new;
CREATE TABLE ven_cli_items_new (LIKE ven_cli_items INCLUDING ALL);

-- 1.7 valores_tesoreria_new
-- Solo se cargan los valores vinculados a comp_prov o ven_cli
DROP TABLE IF EXISTS valores_tesoreria_new;
CREATE TABLE valores_tesoreria_new (LIKE valores_tesoreria INCLUDING ALL);

-- 1.8 notas_imputacion_new
-- Solo imputaciones de OPs de proveedores (tipo_operacion = 1)
DROP TABLE IF EXISTS notas_imputacion_new;
CREATE TABLE notas_imputacion_new (LIKE notas_imputacion INCLUDING ALL);

-- 1.9 operaciones_contables_new
-- Solo operaciones de PROVEEDOR / CLIENTE
DROP TABLE IF EXISTS operaciones_contables_new;
CREATE TABLE operaciones_contables_new (LIKE operaciones_contables INCLUDING ALL);

-- 1.10 operaciones_detalle_valores_tesoreria_new
DROP TABLE IF EXISTS operaciones_detalle_valores_tesoreria_new;
CREATE TABLE operaciones_detalle_valores_tesoreria_new
  (LIKE operaciones_detalle_valores_tesoreria INCLUDING ALL);

-- 1.11 asientos_header_new
-- Solo asientos vinculados a operaciones_contables de PROVEEDOR/CLIENTE
DROP TABLE IF EXISTS asientos_header_new;
CREATE TABLE asientos_header_new (LIKE asientos_header INCLUDING ALL);

-- 1.12 asientos_items_new
DROP TABLE IF EXISTS asientos_items_new;
CREATE TABLE asientos_items_new (LIKE asientos_items INCLUDING ALL);


-- ============================================================
-- FASE 2 — VALIDACIÓN
-- Ejecutar DESPUÉS de cargar los datos en las tablas _new.
-- Todos los resultados deberían ser 0 (sin errores) antes de
-- proceder al swap.
-- ============================================================

-- 2.1 Conteo de registros cargados
SELECT 'proveedores_new'                           AS tabla, COUNT(*) FROM proveedores_new
UNION ALL
SELECT 'clientes_new'                              AS tabla, COUNT(*) FROM clientes_new
UNION ALL
SELECT 'comp_prov_header_new'                      AS tabla, COUNT(*) FROM comp_prov_header_new
UNION ALL
SELECT 'comp_prov_items_new'                       AS tabla, COUNT(*) FROM comp_prov_items_new
UNION ALL
SELECT 'ven_cli_header_new'                        AS tabla, COUNT(*) FROM ven_cli_header_new
UNION ALL
SELECT 'ven_cli_items_new'                         AS tabla, COUNT(*) FROM ven_cli_items_new
UNION ALL
SELECT 'valores_tesoreria_new'                     AS tabla, COUNT(*) FROM valores_tesoreria_new
UNION ALL
SELECT 'notas_imputacion_new'                      AS tabla, COUNT(*) FROM notas_imputacion_new
UNION ALL
SELECT 'operaciones_contables_new'                 AS tabla, COUNT(*) FROM operaciones_contables_new
UNION ALL
SELECT 'operaciones_detalle_valores_tesoreria_new' AS tabla, COUNT(*) FROM operaciones_detalle_valores_tesoreria_new
UNION ALL
SELECT 'asientos_header_new'                       AS tabla, COUNT(*) FROM asientos_header_new
UNION ALL
SELECT 'asientos_items_new'                        AS tabla, COUNT(*) FROM asientos_items_new;

-- 2.2 Integridad FK: comp_prov_header_new → proveedores_new
-- Debe devolver 0 filas
SELECT h.id_transaccion, h.proveedor
FROM comp_prov_header_new h
WHERE NOT EXISTS (SELECT 1 FROM proveedores_new p WHERE p.codigo = h.proveedor);

-- 2.3 Integridad FK: comp_prov_items_new → comp_prov_header_new
-- Debe devolver 0 filas
SELECT i.id_campo, i.id_transaccion
FROM comp_prov_items_new i
WHERE NOT EXISTS (SELECT 1 FROM comp_prov_header_new h WHERE h.id_transaccion = i.id_transaccion);

-- 2.4 Integridad FK: ven_cli_header_new → clientes_new
-- Debe devolver 0 filas
SELECT h.id_transaccion, h.cliente
FROM ven_cli_header_new h
WHERE NOT EXISTS (SELECT 1 FROM clientes_new c WHERE c.codigo = h.cliente);

-- 2.5 Integridad FK: ven_cli_items_new → ven_cli_header_new
-- Debe devolver 0 filas
SELECT i.id_campo, i.id_transaccion
FROM ven_cli_items_new i
WHERE NOT EXISTS (SELECT 1 FROM ven_cli_header_new h WHERE h.id_transaccion = i.id_transaccion);

-- 2.6 Integridad FK: valores_tesoreria_new → comp_prov_header_new o ven_cli_header_new
-- Debe devolver 0 filas (todos los valores deben tener su comprobante)
SELECT v.id, v.idtransaccion_origen, v.tipo_movimiento
FROM valores_tesoreria_new v
WHERE v.idtransaccion_origen IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM comp_prov_header_new h WHERE h.id_transaccion = v.idtransaccion_origen)
  AND NOT EXISTS (SELECT 1 FROM ven_cli_header_new  h WHERE h.id_transaccion = v.idtransaccion_origen);

-- 2.7 Integridad FK: notas_imputacion_new → comp_prov_header_new
-- Debe devolver 0 filas
SELECT n.id, n.id_operacion, n.id_transaccion
FROM notas_imputacion_new n
WHERE NOT EXISTS (SELECT 1 FROM comp_prov_header_new h WHERE h.id_transaccion = n.id_operacion)
   OR NOT EXISTS (SELECT 1 FROM comp_prov_header_new h WHERE h.id_transaccion = n.id_transaccion);

-- 2.8 Integridad FK: asientos_items_new → asientos_header_new
-- Debe devolver 0 filas
SELECT i.id, i.asiento, i.anio_mes, i.tipo_asiento
FROM asientos_items_new i
WHERE NOT EXISTS (
  SELECT 1 FROM asientos_header_new h
  WHERE h.asiento     = i.asiento
    AND h.anio_mes    = i.anio_mes
    AND h.tipo_asiento = i.tipo_asiento
);

-- 2.9 Integridad FK: operaciones_contables_new → asientos_header_new
-- Debe devolver 0 filas (asientos referenciados deben existir en _new)
SELECT o.id, o.asiento_numero, o.asiento_anio_mes, o.asiento_tipo
FROM operaciones_contables_new o
WHERE o.asiento_numero IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM asientos_header_new h
    WHERE h.asiento      = o.asiento_numero
      AND h.anio_mes     = o.asiento_anio_mes
      AND h.tipo_asiento = o.asiento_tipo
  );

-- 2.10 Comparación de saldos proveedores: producción vs staging
-- Útil para detectar diferencias importantes de montos
SELECT
  'PRODUCCION' AS origen,
  COUNT(*)     AS total_comprobantes,
  SUM(total_importe)           AS suma_total_importe,
  SUM(cancelado)               AS suma_cancelado,
  SUM(total_importe - cancelado) AS suma_saldo
FROM comp_prov_header
UNION ALL
SELECT
  'STAGING'    AS origen,
  COUNT(*)     AS total_comprobantes,
  SUM(total_importe)           AS suma_total_importe,
  SUM(cancelado)               AS suma_cancelado,
  SUM(total_importe - cancelado) AS suma_saldo
FROM comp_prov_header_new;

-- 2.11 Comparación de saldos clientes: producción vs staging
SELECT
  'PRODUCCION' AS origen,
  COUNT(*)     AS total_comprobantes,
  SUM(total_importe) AS suma_total,
  SUM(cancelado)     AS suma_cancelado
FROM ven_cli_header
UNION ALL
SELECT
  'STAGING'    AS origen,
  COUNT(*)     AS total_comprobantes,
  SUM(total_importe) AS suma_total,
  SUM(cancelado)     AS suma_cancelado
FROM ven_cli_header_new;

-- 2.12 Asientos balanceados en staging (debe = haber por asiento)
-- Debe devolver 0 filas (sin asientos desbalanceados)
SELECT i.asiento, i.anio_mes, i.tipo_asiento,
       SUM(i.debe) AS total_debe,
       SUM(i.haber) AS total_haber,
       ABS(SUM(i.debe) - SUM(i.haber)) AS diferencia
FROM asientos_items_new i
GROUP BY i.asiento, i.anio_mes, i.tipo_asiento
HAVING ABS(SUM(i.debe) - SUM(i.haber)) > 0.01;


-- ============================================================
-- FASE 3 — SWAP (REEMPLAZO)
-- ⛔ NO EJECUTAR hasta que:
--    a) _bak_0703 estén creadas y con datos verificados (Fase 0)
--    b) _new estén cargadas y Fase 2 dé 0 errores
--    c) Se confirme explícitamente que se puede tocar producción
--
-- TODO EL BLOQUE ESTÁ COMENTADO INTENCIONALMENTE.
-- Descomentar y ejecutar paso a paso cuando se autorice.
-- ============================================================

/*

-- PRE-REQUISITO: confirmar que _bak_0703 y _new existen y tienen datos
SELECT 'proveedores_bak_0703' AS t, COUNT(*) FROM proveedores_bak_0703
UNION ALL SELECT 'proveedores_new',      COUNT(*) FROM proveedores_new
UNION ALL SELECT 'clientes_bak_0703',    COUNT(*) FROM clientes_bak_0703
UNION ALL SELECT 'clientes_new',         COUNT(*) FROM clientes_new
UNION ALL SELECT 'comp_prov_header_bak_0703', COUNT(*) FROM comp_prov_header_bak_0703
UNION ALL SELECT 'comp_prov_header_new', COUNT(*) FROM comp_prov_header_new
UNION ALL SELECT 'ven_cli_header_bak_0703', COUNT(*) FROM ven_cli_header_bak_0703
UNION ALL SELECT 'ven_cli_header_new',   COUNT(*) FROM ven_cli_header_new;

-- ── 3.1 Proveedores ─────────────────────────────────────────
TRUNCATE TABLE proveedores CASCADE;
INSERT INTO proveedores SELECT * FROM proveedores_new;
SELECT setval(
  pg_get_serial_sequence('proveedores', 'codigo'),
  (SELECT MAX(codigo) FROM proveedores)
);

-- ── 3.2 Clientes ────────────────────────────────────────────
TRUNCATE TABLE clientes CASCADE;
INSERT INTO clientes SELECT * FROM clientes_new;
SELECT setval(
  pg_get_serial_sequence('clientes', 'codigo'),
  (SELECT MAX(codigo) FROM clientes)
);

-- ── 3.3 Comprobantes proveedores ────────────────────────────
TRUNCATE TABLE comp_prov_items;
TRUNCATE TABLE comp_prov_header CASCADE;
INSERT INTO comp_prov_header SELECT * FROM comp_prov_header_new;
INSERT INTO comp_prov_items  SELECT * FROM comp_prov_items_new;
SELECT setval(
  pg_get_serial_sequence('comp_prov_header', 'id_transaccion'),
  (SELECT MAX(id_transaccion) FROM comp_prov_header)
);
SELECT setval(
  pg_get_serial_sequence('comp_prov_items', 'id_campo'),
  (SELECT MAX(id_campo) FROM comp_prov_items)
);

-- ── 3.4 Comprobantes clientes ────────────────────────────────
TRUNCATE TABLE ven_cli_items;
TRUNCATE TABLE ven_cli_header CASCADE;
INSERT INTO ven_cli_header SELECT * FROM ven_cli_header_new;
INSERT INTO ven_cli_items  SELECT * FROM ven_cli_items_new;
SELECT setval(
  pg_get_serial_sequence('ven_cli_header', 'id_transaccion'),
  (SELECT MAX(id_transaccion) FROM ven_cli_header)
);
SELECT setval(
  pg_get_serial_sequence('ven_cli_items', 'id_campo'),
  (SELECT MAX(id_campo) FROM ven_cli_items)
);

-- ── 3.5 Valores tesorería (solo prov/cli) ────────────────────
DELETE FROM valores_tesoreria
WHERE idtransaccion_origen IN (
  SELECT id_transaccion FROM comp_prov_header
  UNION ALL
  SELECT id_transaccion FROM ven_cli_header
);
INSERT INTO valores_tesoreria SELECT * FROM valores_tesoreria_new;
SELECT setval(
  pg_get_serial_sequence('valores_tesoreria', 'id'),
  (SELECT MAX(id) FROM valores_tesoreria)
);

-- ── 3.6 Notas imputación (solo prov, tipo_operacion = 1) ─────
DELETE FROM notas_imputacion WHERE tipo_operacion = 1;
INSERT INTO notas_imputacion SELECT * FROM notas_imputacion_new;
SELECT setval(
  pg_get_serial_sequence('notas_imputacion', 'id'),
  (SELECT MAX(id) FROM notas_imputacion)
);

-- ── 3.7 Operaciones contables + detalle (prov/cli) ───────────
DELETE FROM operaciones_detalle_valores_tesoreria
WHERE operacion_id IN (
  SELECT id FROM operaciones_contables
  WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE')
);
DELETE FROM operaciones_contables
WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE');
INSERT INTO operaciones_contables SELECT * FROM operaciones_contables_new;
INSERT INTO operaciones_detalle_valores_tesoreria
  SELECT * FROM operaciones_detalle_valores_tesoreria_new;
SELECT setval(
  pg_get_serial_sequence('operaciones_contables', 'id'),
  (SELECT MAX(id) FROM operaciones_contables)
);
SELECT setval(
  pg_get_serial_sequence('operaciones_detalle_valores_tesoreria', 'id'),
  (SELECT MAX(id) FROM operaciones_detalle_valores_tesoreria)
);

-- ── 3.8 Asientos header + items (solo prov/cli via op_contables) ─
DELETE FROM asientos_items
WHERE (asiento, anio_mes, tipo_asiento) IN (
  SELECT asiento_numero, asiento_anio_mes, asiento_tipo
  FROM operaciones_contables
  WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE')
    AND asiento_numero IS NOT NULL
);
DELETE FROM asientos_header
WHERE (asiento, anio_mes, tipo_asiento) IN (
  SELECT asiento_numero, asiento_anio_mes, asiento_tipo
  FROM operaciones_contables
  WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE')
    AND asiento_numero IS NOT NULL
);
-- Solo insertar los asientos de _new que corresponden a PROVEEDOR/CLIENTE
-- (porque _new puede tener todos los asientos del sistema viejo)
INSERT INTO asientos_header
SELECT h.* FROM asientos_header_new h
WHERE (h.asiento, h.anio_mes, h.tipo_asiento) IN (
  SELECT asiento_numero, asiento_anio_mes, asiento_tipo
  FROM operaciones_contables
  WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE')
    AND asiento_numero IS NOT NULL
);
INSERT INTO asientos_items
SELECT i.* FROM asientos_items_new i
WHERE (i.asiento, i.anio_mes, i.tipo_asiento) IN (
  SELECT asiento_numero, asiento_anio_mes, asiento_tipo
  FROM operaciones_contables
  WHERE entidad_tipo IN ('PROVEEDOR', 'CLIENTE')
    AND asiento_numero IS NOT NULL
);
SELECT setval(
  pg_get_serial_sequence('asientos_header', 'id'),
  (SELECT MAX(id) FROM asientos_header)
);
SELECT setval(
  pg_get_serial_sequence('asientos_items', 'id'),
  (SELECT MAX(id) FROM asientos_items)
);

-- ── 3.9 Verificación post-swap ───────────────────────────────
SELECT 'proveedores'      AS tabla, COUNT(*) AS registros FROM proveedores
UNION ALL
SELECT 'clientes'         AS tabla, COUNT(*) AS registros FROM clientes
UNION ALL
SELECT 'comp_prov_header' AS tabla, COUNT(*) AS registros FROM comp_prov_header
UNION ALL
SELECT 'ven_cli_header'   AS tabla, COUNT(*) AS registros FROM ven_cli_header
UNION ALL
SELECT 'valores_tesoreria (prov+cli)' AS tabla, COUNT(*) AS registros
FROM valores_tesoreria
WHERE idtransaccion_origen IN (
  SELECT id_transaccion FROM comp_prov_header
  UNION ALL SELECT id_transaccion FROM ven_cli_header
);

*/


-- ============================================================
-- FASE 4 — ROLLBACK DE EMERGENCIA
-- Ejecutar solo si el swap produjo resultados incorrectos.
-- Restaura desde los _bak_0703 creados en Fase 0.
-- ============================================================

-- RESTAURAR desde _bak_0703 (si algo salió mal post-swap):
/*
TRUNCATE TABLE comp_prov_items;
TRUNCATE TABLE comp_prov_header CASCADE;
INSERT INTO comp_prov_header SELECT * FROM comp_prov_header_bak_0703;
INSERT INTO comp_prov_items  SELECT * FROM comp_prov_items_bak_0703;

TRUNCATE TABLE ven_cli_items;
TRUNCATE TABLE ven_cli_header CASCADE;
INSERT INTO ven_cli_header SELECT * FROM ven_cli_header_bak_0703;
INSERT INTO ven_cli_items  SELECT * FROM ven_cli_items_bak_0703;

TRUNCATE TABLE proveedores CASCADE;
INSERT INTO proveedores SELECT * FROM proveedores_bak_0703;

TRUNCATE TABLE clientes CASCADE;
INSERT INTO clientes SELECT * FROM clientes_bak_0703;

DELETE FROM valores_tesoreria
WHERE idtransaccion_origen IN (
  SELECT id_transaccion FROM comp_prov_header
  UNION ALL SELECT id_transaccion FROM ven_cli_header
);
INSERT INTO valores_tesoreria SELECT * FROM valores_tesoreria_bak_0703;

DELETE FROM notas_imputacion WHERE tipo_operacion = 1;
INSERT INTO notas_imputacion SELECT * FROM notas_imputacion_bak_0703;

DELETE FROM operaciones_detalle_valores_tesoreria
WHERE operacion_id IN (SELECT id FROM operaciones_contables WHERE entidad_tipo IN ('PROVEEDOR','CLIENTE'));
DELETE FROM operaciones_contables WHERE entidad_tipo IN ('PROVEEDOR','CLIENTE');
INSERT INTO operaciones_contables SELECT * FROM operaciones_contables_bak_0703;
INSERT INTO operaciones_detalle_valores_tesoreria SELECT * FROM operaciones_detalle_bak_0703;

DELETE FROM asientos_items
WHERE (asiento, anio_mes, tipo_asiento) IN (
  SELECT asiento_numero, asiento_anio_mes, asiento_tipo
  FROM operaciones_contables WHERE entidad_tipo IN ('PROVEEDOR','CLIENTE') AND asiento_numero IS NOT NULL
);
DELETE FROM asientos_header
WHERE (asiento, anio_mes, tipo_asiento) IN (
  SELECT asiento_numero, asiento_anio_mes, asiento_tipo
  FROM operaciones_contables WHERE entidad_tipo IN ('PROVEEDOR','CLIENTE') AND asiento_numero IS NOT NULL
);
INSERT INTO asientos_header SELECT * FROM asientos_header_bak_0703;
INSERT INTO asientos_items  SELECT * FROM asientos_items_bak_0703;

-- Resetear secuencias post-rollback
SELECT setval(pg_get_serial_sequence('proveedores',      'codigo'),         (SELECT MAX(codigo)         FROM proveedores));
SELECT setval(pg_get_serial_sequence('clientes',         'codigo'),         (SELECT MAX(codigo)         FROM clientes));
SELECT setval(pg_get_serial_sequence('comp_prov_header', 'id_transaccion'), (SELECT MAX(id_transaccion) FROM comp_prov_header));
SELECT setval(pg_get_serial_sequence('comp_prov_items',  'id_campo'),       (SELECT MAX(id_campo)       FROM comp_prov_items));
SELECT setval(pg_get_serial_sequence('ven_cli_header',   'id_transaccion'), (SELECT MAX(id_transaccion) FROM ven_cli_header));
SELECT setval(pg_get_serial_sequence('ven_cli_items',    'id_campo'),       (SELECT MAX(id_campo)       FROM ven_cli_items));
SELECT setval(pg_get_serial_sequence('valores_tesoreria',           'id'),  (SELECT MAX(id)             FROM valores_tesoreria));
SELECT setval(pg_get_serial_sequence('notas_imputacion',            'id'),  (SELECT MAX(id)             FROM notas_imputacion));
SELECT setval(pg_get_serial_sequence('operaciones_contables',       'id'),  (SELECT MAX(id)             FROM operaciones_contables));
SELECT setval(pg_get_serial_sequence('operaciones_detalle_valores_tesoreria', 'id'), (SELECT MAX(id) FROM operaciones_detalle_valores_tesoreria));
SELECT setval(pg_get_serial_sequence('asientos_header', 'id'),             (SELECT MAX(id)             FROM asientos_header));
SELECT setval(pg_get_serial_sequence('asientos_items',  'id'),             (SELECT MAX(id)             FROM asientos_items));
*/


-- ============================================================
-- LIMPIEZA FINAL (ejecutar solo cuando todo esté confirmado OK)
-- ============================================================
/*
-- Eliminar tablas staging
DROP TABLE IF EXISTS proveedores_new;
DROP TABLE IF EXISTS clientes_new;
DROP TABLE IF EXISTS comp_prov_header_new;
DROP TABLE IF EXISTS comp_prov_items_new;
DROP TABLE IF EXISTS ven_cli_header_new;
DROP TABLE IF EXISTS ven_cli_items_new;
DROP TABLE IF EXISTS valores_tesoreria_new;
DROP TABLE IF EXISTS notas_imputacion_new;
DROP TABLE IF EXISTS operaciones_contables_new;
DROP TABLE IF EXISTS operaciones_detalle_valores_tesoreria_new;
DROP TABLE IF EXISTS asientos_header_new;
DROP TABLE IF EXISTS asientos_items_new;

-- Eliminar backups (solo cuando se confirme que prod está OK)
DROP TABLE IF EXISTS proveedores_bak_0703;
DROP TABLE IF EXISTS clientes_bak_0703;
DROP TABLE IF EXISTS comp_prov_header_bak_0703;
DROP TABLE IF EXISTS comp_prov_items_bak_0703;
DROP TABLE IF EXISTS ven_cli_header_bak_0703;
DROP TABLE IF EXISTS ven_cli_items_bak_0703;
DROP TABLE IF EXISTS valores_tesoreria_bak_0703;
DROP TABLE IF EXISTS notas_imputacion_bak_0703;
DROP TABLE IF EXISTS operaciones_contables_bak_0703;
DROP TABLE IF EXISTS operaciones_detalle_bak_0703;
DROP TABLE IF EXISTS asientos_header_bak_0703;
DROP TABLE IF EXISTS asientos_items_bak_0703;
*/
