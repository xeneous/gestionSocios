/**
 * RELOAD COMPRAS Y ASIENTOS - Directo a producción
 *
 * ⚠️  EJECUTAR SOLO después de correr backup_antes_reload_compras.sql
 *
 * Tablas que modifica:
 *   BORRA + RECARGA:  comp_prov_header, comp_prov_items,
 *                     valores_tesoreria (solo comp_prov),
 *                     asientos_header/items tipo 2 y 3
 *   SOLO BORRA:       notas_imputacion (tipo_operacion=1),
 *                     operaciones_contables (PROVEEDOR),
 *                     operaciones_detalle_valores_tesoreria (PROVEEDOR)
 */

import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import readline from 'readline';

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

function confirm(question) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise(resolve => rl.question(question, ans => {
        rl.close();
        resolve(ans.trim().toLowerCase());
    }));
}

async function insertBatch(table, rows, label) {
    let inserted = 0;
    for (let i = 0; i < rows.length; i += BATCH_SIZE) {
        const batch = rows.slice(i, i + BATCH_SIZE);
        const { error } = await supabase.from(table).insert(batch);
        if (error) {
            console.error(`   ❌ Error lote ${Math.floor(i / BATCH_SIZE) + 1} [${table}]:`, error.message);
        } else {
            inserted += batch.length;
            process.stdout.write(`\r   ✅ ${label}: ${inserted} / ${rows.length}    `);
        }
    }
    console.log();
    return inserted;
}

async function deleteWhere(table, column, values, chunkSize = 200) {
    // Supabase no acepta .in() con miles de valores — lo hacemos en chunks
    let deleted = 0;
    for (let i = 0; i < values.length; i += chunkSize) {
        const chunk = values.slice(i, i + chunkSize);
        const { error } = await supabase.from(table).delete().in(column, chunk);
        if (error) console.error(`   ❌ Error eliminando chunk de ${table}:`, error.message);
        else deleted += chunk.length;
    }
    return deleted;
}

async function resetSeq(table, column) {
    const { data, error } = await supabase
        .from(table).select(column).order(column, { ascending: false }).limit(1).single();
    if (error && error.code !== 'PGRST116') {
        console.log(`   ⚠️  No se pudo resetear secuencia de ${table}.${column}: ${error.message}`);
        return;
    }
    const maxVal = data?.[column] ?? 0;
    // Ejecutar via RPC si existe, sino mostrar el SQL manual
    const { error: rpcError } = await supabase.rpc('reset_sequence', {
        p_table_name: table,
        p_column_name: column
    });
    if (rpcError) {
        console.log(`   ⚠️  Ejecutar manualmente: SELECT setval(pg_get_serial_sequence('${table}','${column}'), ${maxVal});`);
    } else {
        console.log(`   ✅ Secuencia ${table}.${column} → ${maxVal}`);
    }
}

// ── PASO 1: BORRAR ─────────────────────────────────────────────────────────────

async function borrarTodo() {
    console.log('\n🗑️  Borrando datos existentes...\n');

    // 1a. Trazabilidad (primero los hijos)
    console.log('   operaciones_detalle_valores_tesoreria (PROVEEDOR)...');
    const { data: opsIds } = await supabase
        .from('operaciones_contables')
        .select('id')
        .eq('entidad_tipo', 'PROVEEDOR');
    if (opsIds && opsIds.length > 0) {
        await deleteWhere('operaciones_detalle_valores_tesoreria', 'operacion_id', opsIds.map(r => r.id));
    }

    console.log('   operaciones_contables (PROVEEDOR)...');
    const { error: e1 } = await supabase
        .from('operaciones_contables').delete().eq('entidad_tipo', 'PROVEEDOR');
    if (e1) console.error('   ❌', e1.message);

    console.log('   notas_imputacion (tipo_operacion=1)...');
    const { error: e2 } = await supabase
        .from('notas_imputacion').delete().eq('tipo_operacion', 1);
    if (e2) console.error('   ❌', e2.message);

    // 1b. Asientos tipo 2 y 3
    console.log('   asientos_items (tipo 2 y 3)...');
    const { error: e3 } = await supabase
        .from('asientos_items').delete().in('tipo_asiento', [2, 3]);
    if (e3) console.error('   ❌', e3.message);

    console.log('   asientos_header (tipo 2 y 3)...');
    const { error: e4 } = await supabase
        .from('asientos_header').delete().in('tipo_asiento', [2, 3]);
    if (e4) console.error('   ❌', e4.message);

    // 1c. Valores tesorería de comp_prov
    console.log('   valores_tesoreria (vinculados a comp_prov)...');
    let allCompProvIds = [];
    let page = 0;
    while (true) {
        const { data, error } = await supabase
            .from('comp_prov_header')
            .select('id_transaccion')
            .range(page * 1000, (page + 1) * 1000 - 1);
        if (error || !data || data.length === 0) break;
        allCompProvIds = allCompProvIds.concat(data.map(r => r.id_transaccion));
        if (data.length < 1000) break;
        page++;
    }
    if (allCompProvIds.length > 0) {
        await deleteWhere('valores_tesoreria', 'idtransaccion_origen', allCompProvIds);
    }

    // 1d. Comprobantes (items antes que header por FK)
    console.log('   comp_prov_items...');
    const { error: e5 } = await supabase
        .from('comp_prov_items').delete().gte('id_campo', 0);
    if (e5) console.error('   ❌', e5.message);

    console.log('   comp_prov_header...');
    const { error: e6 } = await supabase
        .from('comp_prov_header').delete().gte('id_transaccion', 0);
    if (e6) console.error('   ❌', e6.message);

    // 1e. Proveedores (después de comp_prov por FK)
    console.log('   proveedores...');
    const { error: e7 } = await supabase
        .from('proveedores').delete().gte('codigo', 0);
    if (e7) console.error('   ❌', e7.message);

    console.log('\n✅ Borrado completado\n');
}

// ── PASO 2b: RECARGAR PROVEEDORES ─────────────────────────────────────────────

async function recargarProveedores(pool) {
    console.log('📋 Recargando proveedores...');
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
    console.log(`   ${recordset.length} registros leídos de MSSQL`);

    const rows = recordset.map(p => ({
        codigo: p.Codigo,
        razon_social: p.RazonSocial?.trim() || null,
        domicilio: p.Domicilio?.trim() || null,
        localidad: p.Localidad?.trim() || null,
        codigo_postal: p.CodigoPostal?.trim() || null,
        id_provincia: p.idProvincia || null,
        cuenta: p.Cuenta || null,
        tipo1: p.Tipo1 || null, telefono1: p.Telefono1?.trim() || null,
        tipo2: p.Tipo2 || null, telefono2: p.Telefono2?.trim() || null,
        tipo3: p.Tipo3 || null, telefono3: p.Telefono3?.trim() || null,
        tipo4: p.tipo4 || null, telefono4: p.telefono4?.trim() || null,
        tipo5: p.Tipo5 || null, telefono5: p.telefono5?.trim() || null,
        tipo6: p.tipo6 || null, telefono6: p.telefono6?.trim() || null,
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

    await insertBatch('proveedores', rows, 'proveedores');
}

// ── PASO 2: RECARGAR COMP_PROV ─────────────────────────────────────────────────

async function recargarCompProv(pool) {
    console.log('📋 Recargando comp_prov_header...');
    const { recordset: headers } = await pool.request().query(`
        SELECT idtransaccion, comprobante, aniomes, fecha, proveedor, tipocomprobante,
               nrocomprobante, tipofactura, totalimporte, cancelado,
               fecha1venc, fecha2venc, estado, fechareal, centrocosto,
               DescripcionImporte, Moneda, ImporteOrigen, TC, doc_c, CanceladoOrigen
        FROM CompProvHeader ORDER BY idtransaccion
    `);
    console.log(`   ${headers.length} registros leídos de MSSQL`);

    const headerRows = headers.map(t => ({
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

    await insertBatch('comp_prov_header', headerRows, 'comp_prov_header');

    console.log('📋 Recargando comp_prov_items...');
    const { recordset: items } = await pool.request().query(`
        SELECT idCampo, idTransaccion, comprobante, aniomes, item, concepto,
               cuenta, importe, BaseContable, Area, Detalle, Alicuota, Grilla,
               Base, FechaCierre, Factura
        FROM CompProvItems ORDER BY idCampo
    `);
    console.log(`   ${items.length} registros leídos de MSSQL`);

    const itemRows = items.map(t => ({
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

    await insertBatch('comp_prov_items', itemRows, 'comp_prov_items');
}

// ── PASO 3: RECARGAR VALORES TESORERÍA ─────────────────────────────────────────

async function recargarValoresTesoreria(pool) {
    console.log('📋 Recargando valores_tesoreria (comp_prov)...');

    // Obtener IDs válidos de comp_prov_header ya insertado
    const validIds = new Set();
    let page = 0;
    while (true) {
        const { data, error } = await supabase
            .from('comp_prov_header')
            .select('id_transaccion')
            .range(page * 1000, (page + 1) * 1000 - 1);
        if (error || !data || data.length === 0) break;
        data.forEach(r => validIds.add(r.id_transaccion));
        if (data.length < 1000) break;
        page++;
    }
    console.log(`   ${validIds.size} IDs de comp_prov en producción`);

    const { recordset } = await pool.request().query(`
        SELECT idTransaccion, idTransaccionOrigen, TipoMovimiento, idConcepto_Tesoreria,
               FechaEmision, Vencimiento, Banco, Cuenta, Sucursal, Numero, NumeroInterno,
               Firma, importe, Cancelado, idOperador, Observaciones, locked,
               cobrador, Corregido, tipocambio, base
        FROM ValoresTesoreria
        ORDER BY idTransaccion
    `);

    const filtrados = recordset.filter(r =>
        r.idTransaccionOrigen != null && validIds.has(r.idTransaccionOrigen)
    );
    console.log(`   ${filtrados.length} valores vinculados a comp_prov (de ${recordset.length} totales)`);

    const rows = filtrados.map(row => {
        let locked = false;
        if (row.locked) {
            if (Buffer.isBuffer(row.locked)) {
                locked = Array.from(row.locked).some(b => b !== 0);
            } else {
                locked = Boolean(row.locked);
            }
        }
        return {
            id: row.idTransaccion,
            idtransaccion_origen: row.idTransaccionOrigen,
            tipo_movimiento: row.TipoMovimiento || null,
            idconcepto_tesoreria: row.idConcepto_Tesoreria || null,
            fecha_emision: row.FechaEmision || null,
            vencimiento: row.Vencimiento || null,
            banco: row.Banco || null,
            cuenta: row.Cuenta || null,
            sucursal: row.Sucursal || null,
            numero: row.Numero || null,
            numero_interno: row.NumeroInterno || null,
            firma: row.Firma || null,
            importe: row.importe || 0,
            cancelado: row.Cancelado || 0,
            idoperador: row.idOperador || null,
            observaciones: row.Observaciones || null,
            locked,
            cobrador: row.cobrador || null,
            corregido: row.Corregido || null,
            tipocambio: row.tipocambio || null,
            base: row.base || null,
        };
    });

    await insertBatch('valores_tesoreria', rows, 'valores_tesoreria');
}

// ── PASO 4: RECARGAR ASIENTOS TIPO 2 Y 3 ──────────────────────────────────────

async function recargarAsientos(pool) {
    console.log('📋 Recargando asientos_header (tipo 2 y 3)...');

    const { recordset: headers } = await pool.request().query(`
        SELECT asiento, aniomes, tipoasiento, fecha, detalle, centrocosto
        FROM AsientosDiariosHeader
        WHERE tipoasiento IN (2, 3)
        ORDER BY asiento, aniomes, tipoasiento
    `);
    console.log(`   ${headers.length} headers leídos de MSSQL`);

    const headerRows = headers.map(row => ({
        asiento: row.asiento,
        anio_mes: row.aniomes,
        tipo_asiento: row.tipoasiento,
        fecha: row.fecha?.toISOString().split('T')[0] || null,
        detalle: row.detalle?.trim() || null,
        centro_costo: row.centrocosto || null,
    }));

    await insertBatch('asientos_header', headerRows, 'asientos_header');

    // Mapa de cuentas
    console.log('📋 Recargando asientos_items (tipo 2 y 3)...');
    let allCuentas = [];
    let cPage = 0;
    while (true) {
        const { data, error } = await supabase
            .from('cuentas').select('cuenta')
            .range(cPage * 1000, (cPage + 1) * 1000 - 1);
        if (error || !data || data.length === 0) break;
        allCuentas = allCuentas.concat(data);
        if (data.length < 1000) break;
        cPage++;
    }
    const cuentaMap = new Map(allCuentas.map(c => [c.cuenta, c.cuenta]));

    // Set de asientos válidos
    const validKeys = new Set(
        headers.map(h => `${h.asiento}-${h.aniomes}-${h.tipoasiento}`)
    );

    const { recordset: items } = await pool.request().query(`
        SELECT asiento, aniomes, tipoasiento, item, cuenta, debe, haber, observacion
        FROM AsientosDiariosItems
        WHERE tipoasiento IN (2, 3)
        ORDER BY asiento, aniomes, tipoasiento, item
    `);
    console.log(`   ${items.length} items leídos de MSSQL`);

    let skipped = 0;
    const itemRows = [];
    for (const row of items) {
        const key = `${row.asiento}-${row.aniomes}-${row.tipoasiento}`;
        if (!validKeys.has(key)) { skipped++; continue; }
        itemRows.push({
            asiento: row.asiento,
            anio_mes: row.aniomes,
            tipo_asiento: row.tipoasiento,
            item: row.item,
            cuenta_id: cuentaMap.get(row.cuenta) || null,
            debe: row.debe || 0,
            haber: row.haber || 0,
            observacion: row.observacion?.trim() || null,
        });
    }

    // Deduplicar
    const unique = Array.from(
        new Map(itemRows.map(r => [`${r.asiento}-${r.anio_mes}-${r.tipo_asiento}-${r.item}`, r])).values()
    );

    await insertBatch('asientos_items', unique, 'asientos_items');
    if (skipped > 0) console.log(`   ⚠️  ${skipped} items omitidos (header no encontrado)`);
}

// ── PASO 5: RESETEAR SECUENCIAS ────────────────────────────────────────────────

async function resetearSecuencias() {
    console.log('\n🔄 Reseteando secuencias...');
    await resetSeq('comp_prov_header', 'id_transaccion');
    await resetSeq('comp_prov_items', 'id_campo');
    await resetSeq('valores_tesoreria', 'id');
    await resetSeq('asientos_header', 'id');
    await resetSeq('asientos_items', 'id');
}

// ── MAIN ───────────────────────────────────────────────────────────────────────

async function main() {
    console.log('='.repeat(60));
    console.log('  RELOAD COMPRAS Y ASIENTOS → PRODUCCIÓN');
    console.log('  ⚠️  Modifica tablas productivas directamente');
    console.log('='.repeat(60));
    console.log('\nTablas afectadas:');
    console.log('  BORRAR+RECARGAR: proveedores, comp_prov_header, comp_prov_items,');
    console.log('                   valores_tesoreria (comp_prov),');
    console.log('                   asientos_header/items (tipo 2 y 3)');
    console.log('  SOLO BORRAR:     notas_imputacion, operaciones_contables,');
    console.log('                   operaciones_detalle_valores_tesoreria');

    const ok = await confirm('\n¿Confirmás? Escribí "si" para continuar: ');
    if (ok !== 'si') {
        console.log('Cancelado.');
        process.exit(0);
    }

    const backup = await confirm('¿Ya ejecutaste backup_antes_reload_compras.sql en Supabase? (si/no): ');
    if (backup !== 'si') {
        console.log('Ejecutá el backup primero. Cancelado.');
        process.exit(0);
    }

    let pool;
    try {
        console.log('\n🔌 Conectando a SQL Server...');
        pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado\n');

        await borrarTodo();
        await recargarProveedores(pool);
        await recargarCompProv(pool);
        await recargarValoresTesoreria(pool);
        await recargarAsientos(pool);
        await resetearSecuencias();

        console.log('\n' + '='.repeat(60));
        console.log('✅ RELOAD COMPLETADO');
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
