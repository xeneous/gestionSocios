import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function verifySocio3321() {
    console.log('🔍 Verificando socio 3321...\n');

    try {
        const { data: socio, error } = await supabase
            .from('socios')
            .select(`
                id,
                apellido,
                nombre,
                tarjeta_id,
                numero_tarjeta,
                adherido_debito,
                tarjetas:tarjeta_id (
                    id,
                    descripcion
                )
            `)
            .eq('id', 3321)
            .single();

        if (error) {
            console.error('Error:', error);
            return;
        }

        console.log('📋 Datos del socio 3321:');
        console.log(`   Nombre: ${socio.apellido}, ${socio.nombre}`);
        console.log(`   Tarjeta ID: ${socio.tarjeta_id}`);
        console.log(`   Tarjeta: ${socio.tarjetas?.descripcion || 'N/A'}`);
        console.log(`   Número de tarjeta: ${socio.numero_tarjeta || 'N/A'}`);
        console.log(`   Adherido a débito: ${socio.adherido_debito ? 'Sí' : 'No'}`);

        if (socio.tarjeta_id === 1) {
            console.log('\n✅ CORRECTO! El socio 3321 tiene VISA (ID 1)');
        } else {
            console.log('\n❌ ERROR! El socio debería tener tarjeta ID 1 (VISA)');
        }

        // Ver distribución de tarjetas
        console.log('\n📊 Distribución de tarjetas en todos los socios:');
        const { data: stats } = await supabase
            .from('socios')
            .select('tarjeta_id, tarjetas:tarjeta_id(descripcion)');

        const counts = {};
        stats?.forEach(s => {
            const key = `${s.tarjeta_id}`;
            if (!counts[key]) {
                counts[key] = { count: 0, desc: s.tarjetas?.descripcion || 'N/A' };
            }
            counts[key].count++;
        });

        Object.keys(counts).sort((a, b) => parseInt(a) - parseInt(b)).forEach(id => {
            console.log(`   ID ${id} (${counts[id].desc}): ${counts[id].count} socios`);
        });

    } catch (err) {
        console.error('Error:', err);
    }
}

verifySocio3321()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
