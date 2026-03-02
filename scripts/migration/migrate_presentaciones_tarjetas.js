import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const sqlConfig = {
    server: process.env.SQLSERVER_SERVER,
    port: parseInt(process.env.SQLSERVER_PORT),
    user: process.env.SQLSERVER_USER,
    password: process.env.SQLSERVER_PASSWORD,
    database: process.env.SQLSERVER_DATABASE,
    options: { encrypt: false, trustServerCertificate: true }
};

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function migratePresentacionesTarjetas() {
    console.log('========================================');
    console.log('  Migración: Presentaciones de Tarjetas');
    console.log('========================================\n');

    try {
        console.log('🔌 Conectando a SQL Server...');
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado\n');

        // 1. Leer de MSSQL
        console.log('📖 Leyendo presentacionestarjetas de SQL Server...');
        const result = await pool.request().query(`
            SELECT tarjeta, Periodo, socio, entidad, Importe, Numero
            FROM presentacionestarjetas
            ORDER BY tarjeta, Periodo, socio
        `);
        console.log(`✅ ${result.recordset.length} registros leídos\n`);

        if (result.recordset.length === 0) {
            console.log('ℹ️  No hay datos para migrar');
            await pool.close();
            process.exit(0);
        }

        // 2. Limpiar tablas destino
        console.log('🧹 Limpiando tablas destino...');
        await supabase.from('detalle_presentaciones_tarjetas').delete().gt('id', 0);
        await supabase.from('presentaciones_tarjetas').delete().gt('id', 0);
        console.log('✅ Tablas limpiadas\n');

        // 3. Migrar detalle_presentaciones_tarjetas
        console.log('💾 Migrando detalle_presentaciones_tarjetas...');
        const batchSize = 500;
        let migrated = 0;
        let errors = 0;

        for (let i = 0; i < result.recordset.length; i += batchSize) {
            const batch = result.recordset.slice(i, i + batchSize);

            const rows = batch.map(r => ({
                tarjeta_id: r.tarjeta,
                periodo: r.Periodo,
                socio_id: r.socio,
                entidad_id: r.entidad ?? 0,   // 0=socio, 1=profesional
                importe: r.Importe ?? 0,
                // Numero es numeric(16,0) → varchar, preservar ceros a la izquierda con 16 dígitos
                numero_tarjeta: r.Numero
                    ? r.Numero.toString().padStart(16, '0')
                    : null,
            }));

            const { error } = await supabase
                .from('detalle_presentaciones_tarjetas')
                .insert(rows);

            if (error) {
                console.error(`   ❌ Error en lote ${Math.floor(i / batchSize) + 1}:`, error.message);
                errors++;
            } else {
                migrated += rows.length;
                console.log(`   ✅ Lote ${Math.floor(i / batchSize) + 1}: ${rows.length} registros`);
            }
        }

        console.log(`\n✅ Detalle migrado: ${migrated} registros\n`);

        // 4. Derivar presentaciones_tarjetas (header) agrupando por tarjeta+Periodo
        console.log('📊 Generando cabeceras presentaciones_tarjetas...');

        // Agrupar en JS: { "tarjeta-periodo": { tarjeta_id, periodo, total } }
        const headersMap = {};
        for (const r of result.recordset) {
            const key = `${r.tarjeta}-${r.Periodo}`;
            if (!headersMap[key]) {
                headersMap[key] = {
                    tarjeta_id: r.tarjeta,
                    periodo: r.Periodo,
                    total: 0,
                };
            }
            headersMap[key].total += parseFloat(r.Importe ?? 0);
        }

        const headers = Object.values(headersMap).map(h => {
            // Derivar fecha_presentacion: primer día del mes del período YYYYMM
            const anio = Math.floor(h.periodo / 100);
            const mes = h.periodo % 100;
            const fechaPresentacion = `${anio}-${mes.toString().padStart(2, '0')}-01`;

            return {
                tarjeta_id: h.tarjeta_id,
                fecha_presentacion: fechaPresentacion,
                total: Math.round(h.total * 100) / 100,
                procesado: true, // histórico = ya fue procesado
            };
        });

        const { error: headersError } = await supabase
            .from('presentaciones_tarjetas')
            .insert(headers);

        if (headersError) {
            console.error('❌ Error insertando cabeceras:', headersError.message);
            errors++;
        } else {
            console.log(`✅ ${headers.length} cabeceras creadas`);
        }

        await pool.close();

        console.log('\n========================================');
        console.log('✅ MIGRACIÓN COMPLETADA');
        console.log(`   Detalle: ${migrated} registros`);
        console.log(`   Headers: ${headers.length}`);
        if (errors > 0) console.log(`   ⚠️  Lotes con errores: ${errors}`);
        console.log('========================================\n');

        process.exit(errors > 0 ? 1 : 0);

    } catch (error) {
        console.error('\n💥 ERROR FATAL:', error);
        process.exit(1);
    }
}

migratePresentacionesTarjetas();
