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
        const { error: connError } = await supabase.from('socios').select('id').limit(1);
        if (connError) throw connError;
        console.log('✅ Conectado a Supabase\n');

        // Intentar llamar a la función RPC
        console.log('🔧 Ejecutando reset_all_sequences()...');
        const { error: rpcError } = await supabase.rpc('reset_all_sequences');

        if (rpcError) {
            if (rpcError.message.includes('function') && rpcError.message.includes('does not exist')) {
                console.log('\n⚠️  La función reset_all_sequences() no existe.');
                console.log('\nEjecuta este SQL en Supabase SQL Editor para crearla:\n');
                console.log(`CREATE OR REPLACE FUNCTION reset_all_sequences()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    max_val BIGINT;
BEGIN
    SELECT COALESCE(MAX(id), 0) INTO max_val FROM valores_tesoreria;
    PERFORM setval('valores_tesoreria_id_seq', max_val + 1, false);

    SELECT COALESCE(MAX(idtransaccion), 0) INTO max_val FROM cuentas_corrientes;
    PERFORM setval('cuentas_corrientes_idtransaccion_seq', max_val + 1, false);

    SELECT COALESCE(MAX(id), 0) INTO max_val FROM socios;
    PERFORM setval('socios_id_seq', max_val + 1, false);

    SELECT COALESCE(MAX(id), 0) INTO max_val FROM tarjetas;
    PERFORM setval('tarjetas_id_seq', max_val + 1, false);
END;
$$;`);
                console.log('\nLuego vuelve a ejecutar este script.');
                process.exit(1);
            }
            throw rpcError;
        }

        console.log('✅ Secuencias reseteadas correctamente\n');

        // Mostrar valores actuales
        console.log('📊 Verificando máximos IDs:\n');

        const maxValoresTesoreria = await getMaxId('valores_tesoreria', 'id');
        console.log(`   valores_tesoreria.id: ${maxValoresTesoreria}`);

        const maxCuentasCorrientes = await getMaxId('cuentas_corrientes', 'idtransaccion');
        console.log(`   cuentas_corrientes.idtransaccion: ${maxCuentasCorrientes}`);

        const maxSocios = await getMaxId('socios', 'id');
        console.log(`   socios.id: ${maxSocios}`);

        const maxTarjetas = await getMaxId('tarjetas', 'id');
        console.log(`   tarjetas.id: ${maxTarjetas}`);

        console.log('\n========================================');
        console.log('✅ RESET DE SECUENCIAS COMPLETADO');
        console.log('========================================');

        process.exit(0);

    } catch (error) {
        console.error('\n💥 ERROR:', error.message);
        process.exit(1);
    }
}

resetSequences();
