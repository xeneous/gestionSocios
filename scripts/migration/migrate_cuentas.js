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
// MIGRAR PLAN DE CUENTAS
//============================================
async function migrateCuentas(pool) {
    console.log('📋 Migrando PLAN DE CUENTAS...\n');

    try {
        // Leer cuentas de SQL Server
        const result = await pool.request().query(`
            SELECT 
                cuenta, descripcion, Resumida, sigla, 
                tipocuentaContable, imputable, Rubro, subrubro, UBBalance, UBResultado, CLResultado
            FROM cuentas
            ORDER BY cuenta
        `);

        console.log(`   📊 Encontradas ${result.recordset.length} cuentas en SQL Server`);

        if (result.recordset.length > 0) {
            // Transformar datos
            const cuentasToInsert = result.recordset.map(c => ({
                cuenta: c.cuenta,  // PK ahora (sin id)
                descripcion: c.descripcion?.trim() || '',
                descripcion_resumida: c.Resumida?.trim(),
                sigla: c.sigla?.trim(),
                tipo_cuenta_contable: c.tipocuentaContable,
                imputable: c.imputable === 1 || c.imputable === true,
                rubro: c.Rubro,
                subrubro: c.subrubro,
                activo: true  // Todas empiezan activas
            }));

            // Validar que no haya NULL en cuenta
            const invalid = cuentasToInsert.filter(c => c.cuenta === null || c.cuenta === undefined);
            if (invalid.length > 0) {
                console.error(`❌ ADVERTENCIA: ${invalid.length} cuentas con número NULL/undefined`);
                console.table(invalid);
                throw new Error('Hay cuentas sin número de cuenta válido');
            }

            // Insertar en lotes
            const batchSize = 100;
            let migrated = 0;
            let errors = 0;

            for (let i = 0; i < cuentasToInsert.length; i += batchSize) {
                const batch = cuentasToInsert.slice(i, i + batchSize);

                const { error } = await supabase
                    .from('cuentas')
                    .insert(batch);

                if (error) {
                    console.error(`   ❌ Error en lote ${Math.floor(i / batchSize) + 1}:`, error.message);
                    console.error('   Detalles:', error);
                    errors += batch.length;
                } else {
                    migrated += batch.length;
                    console.log(`   ✅ Lote ${Math.floor(i / batchSize) + 1}: ${batch.length} cuentas`);
                }
            }

            console.log(`\n✅ Total migradas: ${migrated} cuentas`);
            if (errors > 0) {
                console.log(`⚠️  Errores: ${errors} registros`);
            }
            console.log('');

            // Verificar algunas cuentas clave
            console.log('📋 Verificando cuentas migradas en Supabase...');
            const { data: sampleCuentas, error: selectError } = await supabase
                .from('cuentas')
                .select('cuenta, descripcion, imputable')
                .limit(10);

            if (selectError) {
                console.error('Error leyendo cuentas:', selectError);
            } else {
                console.log('\nMuestra de cuentas migradas:');
                console.table(sampleCuentas);
            }
        }

    } catch (err) {
        console.error('💥 Error migrando cuentas:', err);
        throw err;
    }
}

//============================================
// MAIN: EJECUTAR MIGRACIÓN
//============================================
async function main() {
    console.log('========================================');
    console.log('  Migración Plan de Cuentas');
    console.log('  SQL Server → Supabase');
    console.log('========================================\n');

    try {
        // Conectar a SQL Server
        console.log('🔌 Conectando a SQL Server...');
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado a SQL Server\n');

        // Ejecutar migración
        await migrateCuentas(pool);

        await pool.close();

        console.log('========================================');
        console.log('✅ MIGRACIÓN COMPLETADA EXITOSAMENTE');
        console.log('========================================\n');

        console.log('📝 Próximos pasos:');
        console.log('   1. Verificar datos en Supabase Table Editor');
        console.log('   2. Comparar total de cuentas con SQL Server');
        console.log('   3. Migrar conceptos (dependen de cuentas)\n');

        process.exit(0);

    } catch (error) {
        console.error('\n💥 ERROR FATAL:', error);
        process.exit(1);
    }
}

main();
