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
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    {
        auth: {
            autoRefreshToken: false,
            persistSession: false
        }
    }
);

//============================================
// PASO 1: MIGRAR CONCEPTOS (MAESTRO)
//============================================
async function migrateConceptos(pool) {
    console.log('📋 Migrando tabla CONCEPTOS (maestro)...\n');

    try {
        // Leer conceptos de SQL Server con nombres exactos
        const result = await pool.request().query(`
            SELECT 
                Concepto, Entidad, Descripcion, Modalidad, Importe,
                Imputacion_Contable, Grupo
            FROM conceptos
            ORDER BY Concepto
        `);

        console.log(`   📊 Encontrados ${result.recordset.length} conceptos en SQL Server`);

        if (result.recordset.length > 0) {
            // Transformar datos según mapeo
            const conceptosToInsert = result.recordset.map(c => ({
                concepto: c.Concepto?.trim(),
                entidad: c.Entidad || 0,
                descripcion: c.Descripcion?.trim(),
                modalidad: c.Modalidad?.trim(),
                importe: c.Importe,
                cuenta_contable: c.Imputacion_Contable,  // Ahora es el número de cuenta, no id
                grupo: c.Grupo?.trim(),
                activo: true  // Todos empiezan activos
            }));

            // Insertar en lotes
            const batchSize = 50;
            let migrated = 0;

            for (let i = 0; i < conceptosToInsert.length; i += batchSize) {
                const batch = conceptosToInsert.slice(i, i + batchSize);

                const { error } = await supabase
                    .from('conceptos')
                    .insert(batch);

                if (error) {
                    console.error(`   ❌ Error en lote ${Math.floor(i / batchSize) + 1}:`, error.message);
                    console.error('   Detalles:', error);
                } else {
                    migrated += batch.length;
                    console.log(`   ✅ Lote ${Math.floor(i / batchSize) + 1}: ${batch.length} conceptos`);
                }
            }

            console.log(`\n✅ Total migrados: ${migrated} conceptos\n`);
        }

    } catch (err) {
        console.error('💥 Error migrando conceptos:', err);
        throw err;
    }
}

//============================================
// PASO 2: MIGRAR CONCEPTOS_SOCIOS (RELACIÓN)
//============================================
async function migrateConceptosSocios(pool) {
    console.log('📋 Migrando tabla CONCEPTOS_SOCIOS (relación)...\n');

    try {
        // Leer conceptos_socios de SQL Server con nombres exactos
        const result = await pool.request().query(`
            SELECT 
                socio, Concepto, FechaAlta, FecHaVigencia, Importe, FechaBaja
            FROM conceptos_socios
            ORDER BY socio, Concepto
        `);

        console.log(`   📊 Encontrados ${result.recordset.length} conceptos_socios en SQL Server`);

        if (result.recordset.length > 0) {
            // Transformar datos según mapeo
            const conceptosSociosToInsert = result.recordset.map(cs => ({
                socio_id: cs.socio,
                concepto: cs.Concepto?.trim(),
                fecha_alta: cs.FechaAlta,
                fecha_vigencia: cs.FecHaVigencia,
                importe: cs.Importe,
                fecha_baja: cs.FechaBaja
            }));

            // Insertar en lotes
            const batchSize = 100;
            let migrated = 0;
            let errors = 0;

            for (let i = 0; i < conceptosSociosToInsert.length; i += batchSize) {
                const batch = conceptosSociosToInsert.slice(i, i + batchSize);

                const { error } = await supabase
                    .from('conceptos_socios')
                    .insert(batch);

                if (error) {
                    console.error(`   ❌ Error en lote ${Math.floor(i / batchSize) + 1}:`, error.message);
                    console.error('   Detalles:', error);
                    errors += batch.length;
                } else {
                    migrated += batch.length;
                    console.log(`   ✅ Lote ${Math.floor(i / batchSize) + 1}: ${batch.length} conceptos_socios`);
                }
            }

            console.log(`\n✅ Total migrados: ${migrated} conceptos_socios`);
            if (errors > 0) {
                console.log(`⚠️  Errores: ${errors} registros`);
            }
            console.log('');

        }

    } catch (err) {
        console.error('💥 Error migrando conceptos_socios:', err);
        throw err;
    }
}

//============================================
// PASO 3: MIGRAR OBSERVACIONES_SOCIOS
//============================================
async function migrateObservacionesSocios(pool) {
    console.log('📋 Migrando tabla OBSERVACIONES_SOCIOS...\n');

    try {
        // Leer observaciones_socios de SQL Server con nombres exactos
        const result = await pool.request().query(`
            SELECT 
                Socio, fecha, observacion
            FROM observaciones_socios
            ORDER BY Socio, fecha DESC
        `);

        console.log(`   📊 Encontradas ${result.recordset.length} observaciones en SQL Server`);

        if (result.recordset.length > 0) {
            // Transformar datos según mapeo
            const observacionesToInsert = result.recordset.map(obs => ({
                socio_id: obs.Socio,
                fecha: obs.fecha,
                observacion: obs.observacion?.trim() || ''
            }));

            // Insertar en lotes
            const batchSize = 100;
            let migrated = 0;
            let errors = 0;

            for (let i = 0; i < observacionesToInsert.length; i += batchSize) {
                const batch = observacionesToInsert.slice(i, i + batchSize);

                const { error } = await supabase
                    .from('observaciones_socios')
                    .insert(batch);

                if (error) {
                    console.error(`   ❌ Error en lote ${Math.floor(i / batchSize) + 1}:`, error.message);
                    console.error('   Detalles:', error);
                    errors += batch.length;
                } else {
                    migrated += batch.length;
                    console.log(`   ✅ Lote ${Math.floor(i / batchSize) + 1}: ${batch.length} observaciones`);
                }
            }

            console.log(`\n✅ Total migradas: ${migrated} observaciones`);
            if (errors > 0) {
                console.log(`⚠️  Errores: ${errors} registros`);
            }
            console.log('');

        }

    } catch (err) {
        console.error('💥 Error migrando observaciones_socios:', err);
        throw err;
    }
}

//============================================
// MAIN: EJECUTAR MIGRACIÓN
//============================================
async function main() {
    console.log('========================================');
    console.log('  Migración Completa: Conceptos y Observaciones');
    console.log('  SQL Server → Supabase');
    console.log('========================================\n');

    try {
        // Conectar a SQL Server
        console.log('🔌 Conectando a SQL Server...');
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado a SQL Server\n');

        // Ejecutar migraciones en orden
        await migrateConceptos(pool);
        await migrateConceptosSocios(pool);
        await migrateObservacionesSocios(pool);

        await pool.close();

        console.log('========================================');
        console.log('✅ MIGRACIÓN COMPLETADA EXITOSAMENTE');
        console.log('========================================\n');

        console.log('📝 Próximos pasos:');
        console.log('   1. Verificar datos en Supabase Table Editor');
        console.log('   2. Ejecutar queries de verificación de integridad');
        console.log('   3. Comparar totales con SQL Server\n');

        process.exit(0);

    } catch (error) {
        console.error('\n💥 ERROR FATAL:', error);
        process.exit(1);
    }
}

main();
