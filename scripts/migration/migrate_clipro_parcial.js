/**
 * MIGRACIÓN PARCIAL - Clientes, Proveedores y Comprobantes
 *
 * Inserta en tablas _new (staging). NO toca tablas productivas.
 * Tablas destino: clientes_new, proveedores_new,
 *                 comp_prov_header_new, comp_prov_items_new,
 *                 ven_cli_header_new, ven_cli_items_new
 */

import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const sqlConfig = {
    server: process.env.SQLSERVER_SERVER,
    port: parseInt(process.env.SQLSERVER_PORT),
    user: process.env.SQLSERVER_USER,
    password: process.env.SQLSERVER_PASSWORD,
    database: process.env.SQLSERVER_DATABASE,
    options: {
        encrypt: false,
        trustServerCertificate: true,
        enableArithAbort: true,
    },
    connectionTimeout: 30000,
    requestTimeout: 120000,
};

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    { auth: { persistSession: false } }
);

const BATCH_SIZE = 500;

// ── helpers ────────────────────────────────────────────────────────────────────

async function insertBatch(table, rows, label) {
    let inserted = 0;
    for (let i = 0; i < rows.length; i += BATCH_SIZE) {
        const batch = rows.slice(i, i + BATCH_SIZE);
        const { error } = await supabase.from(table).insert(batch);
        if (error) {
            console.error(`   ❌ Error lote ${Math.floor(i / BATCH_SIZE) + 1} en ${table}:`, error.message);
        } else {
            inserted += batch.length;
            console.log(`   ✅ ${label}: ${inserted} / ${rows.length}`);
        }
    }
    return inserted;
}

async function clearNew(table) {
    // Solo limpia la tabla _new, nunca la productiva
    const { error } = await supabase.from(table).delete().neq('id', -999999);
    if (error) {
        // Intentar con columna alternativa (codigo, id_campo, etc.)
        // No es crítico si falla — la tabla puede estar vacía
        console.log(`   ⚠️  Clear ${table}: ${error.message}`);
    }
}

// ── CLIENTES ───────────────────────────────────────────────────────────────────

async function migrateClientes(pool) {
    console.log('\n📋 Migrando clientes → clientes_new...');

    const { recordset } = await pool.request().query(`
        SELECT Codigo, RazonSocial, Domicilio, Localidad, CodigoPostal, idProvincia,
               Tipo1, Telefono1, Tipo2, Telefono2, Tipo3, Telefono3,
               tipo4, telefono4, Tipo5, telefono5, tipo6, telefono6,
               mail, Notas, Fecha, Vendedor, Hora, idClienteant,
               Nombre, Apellido, TipoCuenta, Categoria, Cuit, civa,
               Cuenta, CuentaSubdiario, FechaNac, Activo, codigoexterno,
               vencimiento, horaAtencion, Alerta, cventa, tablaganancia,
               idZona, Fechabaja, tipodocto, numerodocto, Descuento,
               TipoCuentaComis, ibrutos, percepcionIB, retencionIB,
               idPais, Jurisdiccion, Adicional
        FROM Clientes ORDER BY Codigo
    `);

    console.log(`   Encontrados ${recordset.length} registros en SQL Server`);

    // Limpiar staging antes de insertar
    const { error: delError } = await supabase
        .from('clientes_new')
        .delete()
        .neq('codigo', -999999);
    if (delError) console.log(`   ⚠️  Clear clientes_new: ${delError.message}`);

    const rows = recordset.map(c => ({
        codigo: c.Codigo,
        razon_social: c.RazonSocial?.trim() || null,
        domicilio: c.Domicilio?.trim() || null,
        localidad: c.Localidad?.trim() || null,
        codigo_postal: c.CodigoPostal?.trim() || null,
        id_provincia: c.idProvincia || null,
        tipo1: c.Tipo1 || null,
        telefono1: c.Telefono1?.trim() || null,
        tipo2: c.Tipo2 || null,
        telefono2: c.Telefono2?.trim() || null,
        tipo3: c.Tipo3 || null,
        telefono3: c.Telefono3?.trim() || null,
        tipo4: c.tipo4 || null,
        telefono4: c.telefono4?.trim() || null,
        tipo5: c.Tipo5 || null,
        telefono5: c.telefono5?.trim() || null,
        tipo6: c.tipo6 || null,
        telefono6: c.telefono6?.trim() || null,
        mail: c.mail?.trim() || null,
        notas: c.Notas || null,
        fecha: c.Fecha || null,
        vendedor: c.Vendedor || null,
        hora: c.Hora || null,
        id_cliente_ant: c.idClienteant || null,
        nombre: c.Nombre?.trim() || null,
        apellido: c.Apellido?.trim() || null,
        tipo_cuenta: c.TipoCuenta || null,
        categoria: c.Categoria || null,
        cuit: c.Cuit?.trim() || null,
        civa: c.civa || null,
        cuenta: c.Cuenta || null,
        cuenta_subdiario: c.CuentaSubdiario || null,
        fecha_nac: c.FechaNac || null,
        activo: 1,
        codigo_externo: c.codigoexterno?.trim() || null,
        vencimiento: c.vencimiento || null,
        hora_atencion: c.horaAtencion?.trim() || null,
        alerta: c.Alerta?.trim() || null,
        cventa: c.cventa || null,
        tabla_ganancia: c.tablaganancia || null,
        id_zona: c.idZona || null,
        fecha_baja: c.Fechabaja || null,
        tipo_docto: c.tipodocto || null,
        numero_docto: c.numerodocto || null,
        descuento: c.Descuento || null,
        tipo_cuenta_comis: c.TipoCuentaComis || null,
        ibrutos: c.ibrutos?.trim() || null,
        percepcion_ib: c.percepcionIB || null,
        retencion_ib: c.retencionIB || null,
        id_pais: c.idPais || null,
        jurisdiccion: c.Jurisdiccion || null,
        adicional: c.Adicional?.trim() || null,
    }));

    const total = await insertBatch('clientes_new', rows, 'clientes_new');
    console.log(`✅ clientes_new: ${total} registros insertados`);
}

// ── PROVEEDORES ────────────────────────────────────────────────────────────────

async function migrateProveedores(pool) {
    console.log('\n📋 Migrando proveedores → proveedores_new...');

    const { recordset } = await pool.request().query(`
        SELECT Codigo, RazonSocial, Domicilio, Localidad, CodigoPostal, idProvincia,
               Cuenta, Tipo1, Telefono1, Tipo2, Telefono2, Tipo3, Telefono3,
               tipo4, telefono4, Tipo5, telefono5, tipo6, telefono6,
               mail, Notas, Fecha, Vendedor, Hora, idClienteant,
               Nombre, Apellido, TipoCuenta, Categoria, Cuit, civa,
               CuentaSubdiario, FechaNac, Activo, codigoexterno,
               vencimiento, horaAtencion, Alerta, cventa, idZona,
               fechabaja, TablaGanancia, tipodocto, numerodocto, descuento,
               ibrutos, percepcionIB, retencionIB, idPais, Jurisdiccion, Adicional
        FROM Proveedores ORDER BY Codigo
    `);

    console.log(`   Encontrados ${recordset.length} registros en SQL Server`);

    const { error: delError } = await supabase
        .from('proveedores_new')
        .delete()
        .neq('codigo', -999999);
    if (delError) console.log(`   ⚠️  Clear proveedores_new: ${delError.message}`);

    const rows = recordset.map(p => ({
        codigo: p.Codigo,
        razon_social: p.RazonSocial?.trim() || null,
        domicilio: p.Domicilio?.trim() || null,
        localidad: p.Localidad?.trim() || null,
        codigo_postal: p.CodigoPostal?.trim() || null,
        id_provincia: p.idProvincia || null,
        cuenta: p.Cuenta || null,
        tipo1: p.Tipo1 || null,
        telefono1: p.Telefono1?.trim() || null,
        tipo2: p.Tipo2 || null,
        telefono2: p.Telefono2?.trim() || null,
        tipo3: p.Tipo3 || null,
        telefono3: p.Telefono3?.trim() || null,
        tipo4: p.tipo4 || null,
        telefono4: p.telefono4?.trim() || null,
        tipo5: p.Tipo5 || null,
        telefono5: p.telefono5?.trim() || null,
        tipo6: p.tipo6 || null,
        telefono6: p.telefono6?.trim() || null,
        mail: p.mail?.trim() || null,
        notas: p.Notas || null,
        fecha: p.Fecha || null,
        vendedor: p.Vendedor || null,
        hora: p.Hora || null,
        id_cliente_ant: p.idClienteant || null,
        nombre: p.Nombre?.trim() || null,
        apellido: p.Apellido?.trim() || null,
        tipo_cuenta: p.TipoCuenta || null,
        categoria: p.Categoria || null,
        cuit: p.Cuit?.trim() || null,
        civa: p.civa || null,
        cuenta_subdiario: p.CuentaSubdiario || null,
        fecha_nac: p.FechaNac || null,
        activo: 1,
        codigo_externo: p.codigoexterno?.trim() || null,
        vencimiento: p.vencimiento || null,
        hora_atencion: p.horaAtencion?.trim() || null,
        alerta: p.Alerta?.trim() || null,
        cventa: p.cventa || null,
        id_zona: p.idZona || null,
        fecha_baja: p.fechabaja || null,
        tabla_ganancia: p.TablaGanancia || null,
        tipo_docto: p.tipodocto || null,
        numero_docto: p.numerodocto || null,
        descuento: p.descuento || null,
        ibrutos: p.ibrutos?.trim() || null,
        percepcion_ib: p.percepcionIB || null,
        retencion_ib: p.retencionIB || null,
        id_pais: p.idPais || null,
        jurisdiccion: p.Jurisdiccion || null,
        adicional: p.Adicional?.trim() || null,
    }));

    const total = await insertBatch('proveedores_new', rows, 'proveedores_new');
    console.log(`✅ proveedores_new: ${total} registros insertados`);
}

// ── COMP PROV HEADER ───────────────────────────────────────────────────────────

async function migrateCompProvHeader(pool) {
    console.log('\n📋 Migrando CompProvHeader → comp_prov_header_new...');

    const { recordset } = await pool.request().query(`
        SELECT idtransaccion, comprobante, aniomes, fecha, proveedor, tipocomprobante,
               nrocomprobante, tipofactura, totalimporte, cancelado,
               fecha1venc, fecha2venc, estado, fechareal, centrocosto,
               DescripcionImporte, Moneda, ImporteOrigen, TC, doc_c, CanceladoOrigen
        FROM CompProvHeader ORDER BY idtransaccion
    `);

    console.log(`   Encontrados ${recordset.length} registros`);

    const { error: delError } = await supabase
        .from('comp_prov_header_new')
        .delete()
        .neq('id_transaccion', -999999);
    if (delError) console.log(`   ⚠️  Clear comp_prov_header_new: ${delError.message}`);

    const rows = recordset.map(t => ({
        id_transaccion: t.idtransaccion,
        comprobante: t.comprobante,
        anio_mes: t.aniomes,
        fecha: t.fecha,
        proveedor: t.proveedor,
        tipo_comprobante: t.tipocomprobante,
        nro_comprobante: t.nrocomprobante?.trim() || null,
        tipo_factura: t.tipofactura?.trim() || null,
        total_importe: t.totalimporte,
        cancelado: t.cancelado,
        fecha1_venc: t.fecha1venc || null,
        fecha2_venc: t.fecha2venc || null,
        estado: t.estado?.trim() || null,
        fecha_real: t.fechareal,
        centro_costo: t.centrocosto || null,
        descripcion_importe: t.DescripcionImporte?.trim() || null,
        moneda: t.Moneda || null,
        importe_origen: t.ImporteOrigen || null,
        tc: t.TC || null,
        doc_c: t.doc_c || null,
        cancelado_origen: t.CanceladoOrigen || null,
    }));

    const total = await insertBatch('comp_prov_header_new', rows, 'comp_prov_header_new');
    console.log(`✅ comp_prov_header_new: ${total} registros insertados`);
}

// ── COMP PROV ITEMS ────────────────────────────────────────────────────────────

async function migrateCompProvItems(pool) {
    console.log('\n📋 Migrando CompProvItems → comp_prov_items_new...');

    const { recordset } = await pool.request().query(`
        SELECT idCampo, idTransaccion, comprobante, aniomes, item, concepto,
               cuenta, importe, BaseContable, Area, Detalle, Alicuota, Grilla,
               Base, FechaCierre, Factura
        FROM CompProvItems ORDER BY idCampo
    `);

    console.log(`   Encontrados ${recordset.length} registros`);

    const { error: delError } = await supabase
        .from('comp_prov_items_new')
        .delete()
        .neq('id_campo', -999999);
    if (delError) console.log(`   ⚠️  Clear comp_prov_items_new: ${delError.message}`);

    const rows = recordset.map(t => ({
        id_campo: t.idCampo,
        id_transaccion: t.idTransaccion,
        comprobante: t.comprobante,
        anio_mes: t.aniomes,
        item: t.item,
        concepto: t.concepto?.trim() || null,
        cuenta: t.cuenta,
        importe: t.importe,
        base_contable: t.BaseContable,
        area: t.Area || null,
        detalle: t.Detalle?.trim() || null,
        alicuota: t.Alicuota,
        grilla: t.Grilla?.trim() || null,
        base: t.Base || null,
        fecha_cierre: t.FechaCierre || null,
        factura: t.Factura?.trim() || null,
    }));

    const total = await insertBatch('comp_prov_items_new', rows, 'comp_prov_items_new');
    console.log(`✅ comp_prov_items_new: ${total} registros insertados`);
}

// ── VEN CLI HEADER ─────────────────────────────────────────────────────────────

async function migrateVenCliHeader(pool) {
    console.log('\n📋 Migrando VenCliHeader → ven_cli_header_new...');

    const { recordset } = await pool.request().query(`
        SELECT idtransaccion, comprobante, aniomes, fecha, cliente, tipocomprobante,
               nrocomprobante, tipofactura, totalimporte, cancelado,
               fecha1venc, fecha2venc, estado, fechareal, centrocosto,
               DescripcionImporte, Moneda, ImporteOrigen, TC, doc_c, CanceladoOrigen
        FROM VenCliHeader ORDER BY idtransaccion
    `);

    console.log(`   Encontrados ${recordset.length} registros`);

    const { error: delError } = await supabase
        .from('ven_cli_header_new')
        .delete()
        .neq('id_transaccion', -999999);
    if (delError) console.log(`   ⚠️  Clear ven_cli_header_new: ${delError.message}`);

    const rows = recordset.map(t => ({
        id_transaccion: t.idtransaccion,
        comprobante: t.comprobante,
        anio_mes: t.aniomes,
        fecha: t.fecha,
        cliente: t.cliente,
        tipo_comprobante: t.tipocomprobante,
        nro_comprobante: t.nrocomprobante?.trim() || null,
        tipo_factura: t.tipofactura?.trim() || null,
        total_importe: t.totalimporte,
        cancelado: t.cancelado,
        fecha1_venc: t.fecha1venc || null,
        fecha2_venc: t.fecha2venc || null,
        estado: t.estado?.trim() || null,
        fecha_real: t.fechareal,
        centro_costo: t.centrocosto || null,
        descripcion_importe: t.DescripcionImporte?.trim() || null,
        moneda: t.Moneda || null,
        importe_origen: t.ImporteOrigen || null,
        tc: t.TC || null,
        doc_c: t.doc_c || null,
        cancelado_origen: t.CanceladoOrigen || null,
    }));

    const total = await insertBatch('ven_cli_header_new', rows, 'ven_cli_header_new');
    console.log(`✅ ven_cli_header_new: ${total} registros insertados`);
}

// ── VEN CLI ITEMS ──────────────────────────────────────────────────────────────

async function migrateVenCliItems(pool) {
    console.log('\n📋 Migrando VenCliItems → ven_cli_items_new...');

    const { recordset } = await pool.request().query(`
        SELECT idCampo, idTransaccion, comprobante, aniomes, item, concepto,
               cuenta, importe, BaseContable, Area, Detalle, Alicuota, Grilla, Base
        FROM Vencliitems ORDER BY idCampo
    `);

    console.log(`   Encontrados ${recordset.length} registros`);

    const { error: delError } = await supabase
        .from('ven_cli_items_new')
        .delete()
        .neq('id_campo', -999999);
    if (delError) console.log(`   ⚠️  Clear ven_cli_items_new: ${delError.message}`);

    const rows = recordset.map(t => ({
        id_campo: t.idCampo,
        id_transaccion: t.idTransaccion,
        comprobante: t.comprobante,
        anio_mes: t.aniomes,
        item: t.item,
        concepto: t.concepto?.trim() || null,
        cuenta: t.cuenta,
        importe: t.importe,
        base_contable: t.BaseContable,
        area: t.Area || null,
        detalle: t.Detalle?.trim() || null,
        alicuota: t.Alicuota,
        grilla: t.Grilla?.trim() || null,
        base: t.Base || null,
    }));

    const total = await insertBatch('ven_cli_items_new', rows, 'ven_cli_items_new');
    console.log(`✅ ven_cli_items_new: ${total} registros insertados`);
}

// ── MAIN ───────────────────────────────────────────────────────────────────────

async function main() {
    console.log('='.repeat(60));
    console.log('  MIGRACIÓN PARCIAL - CLIPRO → tablas _new');
    console.log('  ⚠️  NO toca tablas productivas');
    console.log('='.repeat(60));

    let pool;
    try {
        console.log('\n🔌 Conectando a SQL Server...');
        pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado\n');

        await migrateClientes(pool);
        await migrateProveedores(pool);
        await migrateCompProvHeader(pool);
        await migrateCompProvItems(pool);
        await migrateVenCliHeader(pool);
        await migrateVenCliItems(pool);

        console.log('\n' + '='.repeat(60));
        console.log('✅ MIGRACIÓN CLIPRO PARCIAL COMPLETADA');
        console.log('   Verificar en Supabase las tablas _new antes de continuar');
        console.log('='.repeat(60));

        process.exit(0);
    } catch (err) {
        console.error('\n💥 ERROR FATAL:', err);
        process.exit(1);
    } finally {
        if (pool) await pool.close();
    }
}

main();
