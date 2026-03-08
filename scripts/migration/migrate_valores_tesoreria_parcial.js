/**
 * MIGRACIÓN PARCIAL - Valores de Tesorería
 *
 * Inserta en valores_tesoreria_new SOLO los valores vinculados a
 * comp_prov_header_new o ven_cli_header_new.
 * NO toca valores_tesoreria ni ninguna tabla productiva.
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

const BATCH_SIZE = 200;

async function migrateValoresTesoreriaParcial() {
    let pool;
    try {
        console.log('='.repeat(60));
        console.log('  MIGRACIÓN PARCIAL - Valores Tesorería → valores_tesoreria_new');
        console.log('  ⚠️  Solo valores de comp_prov y ven_cli');
        console.log('  ⚠️  NO toca tablas productivas');
        console.log('='.repeat(60));

        console.log('\n🔌 Conectando a SQL Server...');
        pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado\n');

        // Obtener IDs válidos de comp_prov_header_new y ven_cli_header_new
        console.log('📋 Obteniendo IDs de transacciones desde staging...');

        const validIds = new Set();
        let page = 0;
        const pageSize = 1000;

        // comp_prov_header_new
        while (true) {
            const { data, error } = await supabase
                .from('comp_prov_header_new')
                .select('id_transaccion')
                .range(page * pageSize, (page + 1) * pageSize - 1);
            if (error) throw new Error(`Error leyendo comp_prov_header_new: ${error.message}`);
            if (!data || data.length === 0) break;
            data.forEach(r => validIds.add(r.id_transaccion));
            if (data.length < pageSize) break;
            page++;
        }

        // ven_cli_header_new
        page = 0;
        while (true) {
            const { data, error } = await supabase
                .from('ven_cli_header_new')
                .select('id_transaccion')
                .range(page * pageSize, (page + 1) * pageSize - 1);
            if (error) throw new Error(`Error leyendo ven_cli_header_new: ${error.message}`);
            if (!data || data.length === 0) break;
            data.forEach(r => validIds.add(r.id_transaccion));
            if (data.length < pageSize) break;
            page++;
        }

        console.log(`✅ IDs de transacciones válidos (comp_prov + ven_cli): ${validIds.size}`);

        if (validIds.size === 0) {
            console.error('❌ No hay IDs en las tablas _new. Ejecutar migrate_clipro_parcial.js primero.');
            process.exit(1);
        }

        // Obtener todos los valores de SQL Server
        console.log('\n📋 Leyendo ValoresTesoreria desde SQL Server...');
        const { recordset } = await pool.request().query(`
            SELECT
                idTransaccion,
                idTransaccionOrigen,
                TipoMovimiento,
                idConcepto_Tesoreria,
                FechaEmision,
                Vencimiento,
                Banco,
                Cuenta,
                Sucursal,
                Numero,
                NumeroInterno,
                Firma,
                importe,
                Cancelado,
                idOperador,
                Observaciones,
                locked,
                cobrador,
                Corregido,
                tipocambio,
                base
            FROM ValoresTesoreria
            ORDER BY idTransaccion
        `);
        console.log(`✅ ${recordset.length} registros leídos de SQL Server`);

        // Filtrar solo los vinculados a comp_prov o ven_cli
        const filtrados = recordset.filter(r =>
            r.idTransaccionOrigen != null && validIds.has(r.idTransaccionOrigen)
        );
        console.log(`✅ ${filtrados.length} valores vinculados a comp_prov/ven_cli (${recordset.length - filtrados.length} de socios/otros excluidos)`);

        // Limpiar staging
        const { error: delError } = await supabase
            .from('valores_tesoreria_new')
            .delete()
            .neq('id', -999999);
        if (delError) console.log(`   ⚠️  Clear valores_tesoreria_new: ${delError.message}`);

        // Preparar e insertar
        const rows = filtrados.map(row => {
            let lockedValue = false;
            if (row.locked) {
                if (Buffer.isBuffer(row.locked)) {
                    lockedValue = Array.from(row.locked).some(byte => byte !== 0);
                } else {
                    lockedValue = Boolean(row.locked);
                }
            }
            return {
                id: row.idTransaccion,
                idtransaccion_origen: row.idTransaccionOrigen || null,
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
                locked: lockedValue,
                cobrador: row.cobrador || null,
                corregido: row.Corregido || null,
                tipocambio: row.tipocambio || null,
                base: row.base || null,
            };
        });

        let inserted = 0;
        for (let i = 0; i < rows.length; i += BATCH_SIZE) {
            const batch = rows.slice(i, i + BATCH_SIZE);
            const { error } = await supabase.from('valores_tesoreria_new').insert(batch);
            if (error) {
                console.error(`   ❌ Error lote ${Math.floor(i / BATCH_SIZE) + 1}:`, error.message);
            } else {
                inserted += batch.length;
                console.log(`   ✅ valores_tesoreria_new: ${inserted} / ${rows.length}`);
            }
        }

        console.log('\n' + '='.repeat(60));
        console.log(`✅ COMPLETADO: ${inserted} valores insertados en valores_tesoreria_new`);
        console.log('='.repeat(60));

        process.exit(0);
    } catch (err) {
        console.error('\n💥 ERROR:', err);
        process.exit(1);
    } finally {
        if (pool) await pool.close();
    }
}

migrateValoresTesoreriaParcial();
