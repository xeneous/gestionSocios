import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function cleanTarjetas() {
    console.log('🧹 Limpiando tabla tarjetas completamente...\n');

    try {
        // Eliminar TODAS las tarjetas (incluyendo ID 0)
        console.log('Eliminando todas las tarjetas...');
        const { error } = await supabase
            .from('tarjetas')
            .delete()
            .gte('id', 0); // Delete all including 0

        if (error) {
            console.error('❌ Error:', error.message);
        } else {
            console.log('✅ Todas las tarjetas eliminadas');
        }

        // Verificar
        const { data, count } = await supabase
            .from('tarjetas')
            .select('*', { count: 'exact' });

        console.log(`\nTarjetas restantes: ${count || 0}`);
        if (data && data.length > 0) {
            console.log('Tarjetas encontradas:', data);
        }

    } catch (err) {
        console.error('💥 Error:', err);
    }
}

cleanTarjetas()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
