-- =============================================================================
-- Script: Agregar FKs faltantes para tipos de comprobante
-- Base de datos: Supabase (PostgreSQL)
-- Fecha: 2026-01-25
-- =============================================================================

-- PASO 1: Identificar tipos de comprobante huérfanos en comp_prov_header
-- (tipos que no existen en tip_comp_mod_header)
SELECT DISTINCT cph.tipo_comprobante, COUNT(*) as cantidad
FROM comp_prov_header cph
LEFT JOIN tip_comp_mod_header tcm ON cph.tipo_comprobante = tcm.codigo
WHERE tcm.codigo IS NULL
GROUP BY cph.tipo_comprobante;

-- PASO 2: Identificar tipos de comprobante huérfanos en ven_cli_header
SELECT DISTINCT vch.tipo_comprobante, COUNT(*) as cantidad
FROM ven_cli_header vch
LEFT JOIN tip_vent_mod_header tvm ON vch.tipo_comprobante = tvm.codigo
WHERE tvm.codigo IS NULL
GROUP BY vch.tipo_comprobante;

-- PASO 3: Ver qué tipos existen en tip_comp_mod_header
SELECT codigo, comprobante, descripcion FROM tip_comp_mod_header ORDER BY codigo;

-- PASO 4: Ver qué tipos existen en tip_vent_mod_header
SELECT codigo, comprobante, descripcion FROM tip_vent_mod_header ORDER BY codigo;

-- =============================================================================
-- CORRECCION: Agregar tipos faltantes o actualizar registros huérfanos
-- Ejecutar SOLO después de revisar los pasos anteriores
-- =============================================================================

-- Opción A: Agregar el tipo 5 a tip_comp_mod_header si es válido
-- INSERT INTO tip_comp_mod_header (codigo, comprobante, descripcion, multiplicador, signo)
-- VALUES (5, 'XX', 'Descripción del tipo 5', 1, 1);

-- Opción B: Actualizar registros huérfanos a un tipo válido
-- UPDATE comp_prov_header SET tipo_comprobante = 1 WHERE tipo_comprobante = 5;

-- =============================================================================
-- AGREGAR FKs (ejecutar SOLO después de corregir datos huérfanos)
-- =============================================================================

-- FK de ven_cli_header.tipo_comprobante a tip_vent_mod_header.codigo
-- ALTER TABLE ven_cli_header
-- ADD CONSTRAINT fk_ven_cli_tipo_comprobante
-- FOREIGN KEY (tipo_comprobante) REFERENCES tip_vent_mod_header(codigo);

-- FK de comp_prov_header.tipo_comprobante a tip_comp_mod_header.codigo
-- ALTER TABLE comp_prov_header
-- ADD CONSTRAINT fk_comp_prov_tipo_comprobante
-- FOREIGN KEY (tipo_comprobante) REFERENCES tip_comp_mod_header(codigo);

-- Verificar que las FKs se crearon correctamente
-- SELECT
--     tc.table_name,
--     kcu.column_name,
--     ccu.table_name AS foreign_table_name,
--     ccu.column_name AS foreign_column_name
-- FROM
--     information_schema.table_constraints AS tc
--     JOIN information_schema.key_column_usage AS kcu
--       ON tc.constraint_name = kcu.constraint_name
--     JOIN information_schema.constraint_column_usage AS ccu
--       ON ccu.constraint_name = tc.constraint_name
-- WHERE tc.constraint_type = 'FOREIGN KEY'
-- AND tc.table_name IN ('ven_cli_header', 'comp_prov_header');
