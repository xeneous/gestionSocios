import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

// Configuración SQL Server
const sqlConfig = {
    server: process.env.SQLSERVER_SERVER,
    port: parseInt(process.env.SQLSERVER_PORT),
    user: process.env.SQLSERVER_USER,
    password: process.env.SQLSERVER_PASSWORD,
    database: process.env.SQLSERVER_DATABASE,
    options: {
        encrypt: false,
        trustServerCertificate: true
    }
};

// Configuración Supabase
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function fixTarjetaIds() {
    console.log('🔄 Actualizando tarjeta_id de socios desde SQL Server...\n');

    try {
        // Conectar a SQL Server
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado a SQL Server');

        // Primero, obtener todas las tarjetas de Supabase
        const { data: tarjetasSupabase, error: tarjetasError } = await supabase
            .from('tarjetas')
            .select('id, codigo, descripcion');

        if (tarjetasError) {
            throw new Error('Error cargando tarjetas de Supabase: ' + tarjetasError.message);
        }

        console.log('\n📋 Tarjetas disponibles en Supabase:');
        tarjetasSupabase.forEach(t => {
            console.log(`   ID ${t.id}: ${t.descripcion} (código: ${t.codigo})`);
        });

        const tarjetasIdsValidos = new Set(tarjetasSupabase.map(t => t.id));

        // Obtener todos los socios con sus tarjetas de SQL Server
        const result = await pool.request().query(`
            SELECT socio, Tarjeta 
            FROM socios 
            WHERE socio IS NOT NULL
            ORDER BY socio
        `);

        console.log(`\n📊 Encontrados ${result.recordset.length} socios en SQL Server`);

        // Analizar qué tarjetas se usan en SQL Server
        const tarjetasUsadas = new Set();
        result.recordset.forEach(row => {
            if (row.Tarjeta) {
                tarjetasUsadas.add(row.Tarjeta);
            }
        });

        console.log('\n📋 Tarjetas usadas en SQL Server:');
        Array.from(tarjetasUsadas).sort((a, b) => a - b).forEach(id => {
            const existe = tarjetasIdsValidos.has(id);
            const simbolo = existe ? '✅' : '❌';
            console.log(`   ${simbolo} ID ${id} (${existe ? 'existe en Supabase' : 'NO EXISTE EN SUPABASE'})`);
        });

        // Actualizar en lotes
        const batchSize = 100;
        let updated = 0;
        let skipped = 0;
        let errors = 0;

        for (let i = 0; i < result.recordset.length; i += batchSize) {
            const batch = result.recordset.slice(i, i + batchSize);

            for (const row of batch) {
                let tarjetaId = row.Tarjeta || 0;

                // Si la tarjeta no existe en Supabase, usar 0 (Sin tarjeta)
                if (tarjetaId !== 0 && !tarjetasIdsValidos.has(tarjetaId)) {
                    console.log(`⚠️  Socio ${row.socio}: tarjeta ${tarjetaId} no existe, usando 0`);
                    tarjetaId = 0;
                    skipped++;
                }

                const { error } = await supabase
                    .from('socios')
                    .update({ tarjeta_id: tarjetaId })
                    .eq('id', row.socio);

                if (error) {
                    console.error(`❌ Error actualizando socio ${row.socio}:`, error.message);
                    errors++;
                } else {
                    updated++;
                }
            }

            console.log(`✅ Procesados ${i + batch.length} de ${result.recordset.length} socios`);
        }

        console.log(`\n📊 Resumen de actualización:`);
        console.log(`   ✅ Actualizados exitosamente: ${updated}`);
        console.log(`   ⚠️  Con tarjeta inválida (asignados a 0): ${skipped}`);
        console.log(`   ❌ Errores: ${errors}`);
        console.log(`   📦 Total procesados: ${result.recordset.length}`);

        // Verificar resultados
        console.log('\n📊 Verificando distribución de tarjetas en Supabase...');
        const { data: allSocios } = await supabase
            .from('socios')
            .select('tarjeta_id');

        const counts = {};
        allSocios.forEach(s => {
            counts[s.tarjeta_id] = (counts[s.tarjeta_id] || 0) + 1;
        });

        console.log('\nDistribución de tarjetas:');
        for (const [id, count] of Object.entries(counts).sort((a, b) => a[0] - b[0])) {
            const tarjeta = tarjetasSupabase.find(t => t.id == id);
            console.log(`   ${tarjeta?.descripcion || `ID ${id}`}: ${count} socios`);
        }

        await pool.close();
        console.log('\n✅ Actualización completada');

    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

// Ejecutar
fixTarjetaIds()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
