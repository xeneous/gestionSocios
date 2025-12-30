import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function resetSequences() {
    console.log('🔧 Reseteando secuencias...\n');

    try {
        // Reset socios sequence
        console.log('Reseteando secuencia de socios...');
        const { data: maxSocio } = await supabase
            .from('socios')
            .select('id')
            .order('id', { ascending: false })
            .limit(1)
            .single();

        console.log(`Máximo ID de socios: ${maxSocio?.id}`);

        // Reset tarjetas sequence
        console.log('\nReseteando secuencia de tarjetas...');
        const { data: maxTarjeta } = await supabase
            .from('tarjetas')
            .select('id')
            .order('id', { ascending: false })
            .limit(1)
            .single();

        console.log(`Máximo ID de tarjetas: ${maxTarjeta?.id}`);

        console.log('\n✅ Verificación completada');
        console.log('\nEjecuta en Supabase SQL Editor:');
        console.log(`SELECT setval(pg_get_serial_sequence('socios', 'id'), ${maxSocio?.id}, true);`);
        console.log(`SELECT setval(pg_get_serial_sequence('tarjetas', 'id'), ${maxTarjeta?.id}, true);`);

    } catch (err) {
        console.error('Error:', err);
    }
}

resetSequences()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
