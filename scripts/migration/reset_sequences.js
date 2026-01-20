import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function getMaxId(tabla, columna = 'id') {
    const { data, error } = await supabase
        .from(tabla)
        .select(columna)
        .order(columna, { ascending: false })
        .limit(1)
        .single();

    if (error && error.code !== 'PGRST116') { // PGRST116 = no rows
        console.log(`   ⚠️  Error obteniendo max ${columna} de ${tabla}: ${error.message}`);
        return 0;
    }
    return data?.[columna] || 0;
}

async function resetSequences() {
    console.log('========================================');
    console.log('  Reset de Secuencias');
    console.log('========================================\n');

    try {
        // Verificar conexión
        console.log('🔌 Verificando conexión a Supabase...');
        const { error } = await supabase.from('socios').select('id').limit(1);
        if (error) throw error;
        console.log('✅ Conectado a Supabase\n');

        // Obtener máximos IDs
        console.log('📊 Obteniendo máximos IDs...\n');

        const maxValoresTesoreria = await getMaxId('valores_tesoreria', 'id');
        console.log(`   valores_tesoreria.id: ${maxValoresTesoreria}`);

        const maxCuentasCorrientes = await getMaxId('cuentas_corrientes', 'idtransaccion');
        console.log(`   cuentas_corrientes.idtransaccion: ${maxCuentasCorrientes}`);

        const maxDetalleCuentasCorrientes = await getMaxId('detalle_cuentas_corrientes', 'id');
        console.log(`   detalle_cuentas_corrientes.id: ${maxDetalleCuentasCorrientes}`);

        const maxSocios = await getMaxId('socios', 'id');
        console.log(`   socios.id: ${maxSocios}`);

        const maxTarjetas = await getMaxId('tarjetas', 'id');
        console.log(`   tarjetas.id: ${maxTarjetas}`);

        // Generar SQL para resetear secuencias
        console.log('\n========================================');
        console.log('📋 SQL para resetear secuencias:');
        console.log('========================================\n');

        const sqlStatements = [
            `SELECT setval('valores_tesoreria_id_seq', ${maxValoresTesoreria + 1}, false);`,
            `SELECT setval('cuentas_corrientes_idtransaccion_seq', ${maxCuentasCorrientes + 1}, false);`,
            `SELECT setval('detalle_cuentas_corrientes_id_seq', ${maxDetalleCuentasCorrientes + 1}, false);`,
            `SELECT setval('socios_id_seq', ${maxSocios + 1}, false);`,
            `SELECT setval('tarjetas_id_seq', ${maxTarjetas + 1}, false);`,
        ];

        sqlStatements.forEach(sql => console.log(sql));

        console.log('\n========================================');
        console.log('✅ VERIFICACIÓN COMPLETADA');
        console.log('========================================');
        console.log('\nNOTA: Las secuencias deben resetearse manualmente en Supabase');
        console.log('      SQL Editor porque la API no tiene permisos para setval().');
        console.log('\nCopia y ejecuta los comandos SQL mostrados arriba.');

        process.exit(0);

    } catch (error) {
        console.error('\n💥 ERROR:', error.message);
        process.exit(1);
    }
}

resetSequences();
