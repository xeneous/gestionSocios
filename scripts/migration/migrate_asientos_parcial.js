/**
 * MIGRACIÓN PARCIAL - Asientos de Diario
 *
 * Inserta en asientos_header_new y asientos_items_new.
 * Migra TODOS los asientos desde SQL Server (no se puede filtrar
 * por entidad a nivel de origen). El swap en Fase 3 del SQL de
 * migración solo toma los vinculados a PROVEEDOR/CLIENTE.
 * NO toca asientos_header ni asientos_items productivos.
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

const BATCH_SIZE = 1000;

async function migrateAsientosParcial() {
    let pool;
    try {
        console.log('='.repeat(60));
        console.log('  MIGRACIÓN PARCIAL - Asientos → tablas _new');
        console.log('  Migra todos los asientos; el swap filtra por entidad');
        console.log('  ⚠️  NO toca tablas productivas');
        console.log('='.repeat(60));

        console.log('\n🔌 Conectando a SQL Server...');
        pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado\n');

        // ── HEADERS ────────────────────────────────────────────────────────────
        console.log('📋 Leyendo AsientosDiariosHeader desde SQL Server...');
        const headersResult = await pool.request().query(`
            SELECT asiento, aniomes, tipoasiento, fecha, detalle, centrocosto
            FROM AsientosDiariosHeader
            ORDER BY asiento, aniomes, tipoasiento
        `);
        console.log(`✅ ${headersResult.recordset.length} headers encontrados`);

        // Limpiar staging
        const { error: delHeaderError } = await supabase
            .from('asientos_header_new')
            .delete()
            .gte('asiento', 0);
        if (delHeaderError) console.log(`   ⚠️  Clear asientos_header_new: ${delHeaderError.message}`);

        let insertedHeaders = 0;
        for (let i = 0; i < headersResult.recordset.length; i += BATCH_SIZE) {
            const batch = headersResult.recordset.slice(i, i + BATCH_SIZE);
            const data = batch.map(row => ({
                asiento: row.asiento,
                anio_mes: row.aniomes,
                tipo_asiento: row.tipoasiento,
                fecha: row.fecha?.toISOString().split('T')[0] || null,
                detalle: row.detalle?.trim() || null,
                centro_costo: row.centrocosto || null,
            }));

            const { error } = await supabase.from('asientos_header_new').insert(data);
            if (error) {
                console.error(`   ❌ Error lote headers ${Math.floor(i / BATCH_SIZE) + 1}:`, error.message);
            } else {
                insertedHeaders += data.length;
                console.log(`   ✅ asientos_header_new: ${insertedHeaders} / ${headersResult.recordset.length}`);
            }
        }

        // ── ITEMS ──────────────────────────────────────────────────────────────
        console.log('\n📋 Leyendo AsientosDiariosItems desde SQL Server...');
        const itemsResult = await pool.request().query(`
            SELECT asiento, aniomes, tipoasiento, item, cuenta, debe, haber, observacion
            FROM AsientosDiariosItems
            ORDER BY asiento, aniomes, tipoasiento, item
        `);
        console.log(`✅ ${itemsResult.recordset.length} items encontrados`);

        // Construir set de asientos válidos en _new (para FK check)
        const validKeys = new Set(
            headersResult.recordset.map(h => `${h.asiento}-${h.aniomes}-${h.tipoasiento}`)
        );

        // Construir mapa cuenta_numero → cuenta_id desde Supabase
        // La tabla cuentas usa 'cuenta' como PK (no tiene columna 'id')
        console.log('🔍 Obteniendo mapa de cuentas desde Supabase...');
        let allCuentas = [];
        let cPage = 0;
        while (true) {
            const { data, error } = await supabase
                .from('cuentas')
                .select('cuenta')
                .range(cPage * 1000, (cPage + 1) * 1000 - 1);
            if (error) throw new Error(`Error leyendo cuentas: ${error.message}`);
            if (!data || data.length === 0) break;
            allCuentas = allCuentas.concat(data);
            if (data.length < 1000) break;
            cPage++;
        }
        const cuentaMap = new Map(allCuentas.map(c => [c.cuenta, c.cuenta]));
        console.log(`✅ ${cuentaMap.size} cuentas mapeadas`);

        // Limpiar staging items
        const { error: delItemsError } = await supabase
            .from('asientos_items_new')
            .delete()
            .gte('item', 0);
        if (delItemsError) console.log(`   ⚠️  Clear asientos_items_new: ${delItemsError.message}`);

        let insertedItems = 0;
        let skippedItems = 0;

        for (let i = 0; i < itemsResult.recordset.length; i += BATCH_SIZE) {
            const batch = itemsResult.recordset.slice(i, i + BATCH_SIZE);

            const data = [];
            for (const row of batch) {
                const key = `${row.asiento}-${row.aniomes}-${row.tipoasiento}`;
                if (!validKeys.has(key)) {
                    skippedItems++;
                    continue;
                }
                const cuentaId = cuentaMap.get(row.cuenta);
                if (row.cuenta && !cuentaId) {
                    console.log(`   ⚠️  Cuenta ${row.cuenta} no existe (asiento ${row.asiento}/${row.aniomes}/${row.tipoasiento} item ${row.item})`);
                }
                data.push({
                    asiento: row.asiento,
                    anio_mes: row.aniomes,
                    tipo_asiento: row.tipoasiento,
                    item: row.item,
                    cuenta_id: cuentaId || null,
                    debe: row.debe || 0,
                    haber: row.haber || 0,
                    observacion: row.observacion?.trim() || null,
                });
            }

            // Deduplicar dentro del lote
            const unique = Array.from(
                new Map(data.map(r => [`${r.asiento}-${r.anio_mes}-${r.tipo_asiento}-${r.item}`, r])).values()
            );

            if (unique.length === 0) continue;

            const { error } = await supabase.from('asientos_items_new').insert(unique);
            if (error) {
                console.error(`   ❌ Error lote items ${Math.floor(i / BATCH_SIZE) + 1}:`, error.message);
                skippedItems += unique.length;
            } else {
                insertedItems += unique.length;
                console.log(`   ✅ asientos_items_new: ${insertedItems} / ${itemsResult.recordset.length} (${skippedItems} omitidos)`);
            }
        }

        console.log('\n' + '='.repeat(60));
        console.log(`✅ COMPLETADO`);
        console.log(`   Headers: ${insertedHeaders} insertados en asientos_header_new`);
        console.log(`   Items:   ${insertedItems} insertados en asientos_items_new (${skippedItems} omitidos)`);
        console.log('='.repeat(60));

        process.exit(0);
    } catch (err) {
        console.error('\n💥 ERROR:', err);
        process.exit(1);
    } finally {
        if (pool) await pool.close();
    }
}

migrateAsientosParcial();
