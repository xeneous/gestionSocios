import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function cleanDatabase() {
    console.log('🧹 Limpiando base de datos Supabase...\n');

    try {
        // Paso 1: Eliminar socios
        console.log('1️⃣ Eliminando socios...');
        const { error: sociosError } = await supabase
            .from('socios')
            .delete()
            .neq('id', 0); // Delete all

        if (sociosError) {
            console.error('❌ Error eliminando socios:', sociosError.message);
        } else {
            console.log('✅ Socios eliminados');
        }

        // Paso 2: Eliminar tarjetas (excepto ID 0)
        console.log('\n2️⃣ Eliminando tarjetas...');
        const { error: tarjetasError } = await supabase
            .from('tarjetas')
            .delete()
            .neq('id', 0);

        if (tarjetasError) {
            console.error('❌ Error eliminando tarjetas:', tarjetasError.message);
        } else {
            console.log('✅ Tarjetas eliminadas (preservado ID 0)');
        }

        // Paso 3: Eliminar grupos_agrupados
        console.log('\n3️⃣ Eliminando grupos agrupados...');
        const { error: gruposError } = await supabase
            .from('grupos_agrupados')
            .delete()
            .neq('id', 0);

        if (gruposError) {
            console.error('❌ Error eliminando grupos:', gruposError.message);
        } else {
            console.log('✅ Grupos agrupados eliminados');
        }

        // Paso 4: Eliminar provincias
        console.log('\n4️⃣ Eliminando provincias...');
        const { error: provError } = await supabase
            .from('provincias')
            .delete()
            .neq('id', 0);

        if (provError) {
            console.error('❌ Error eliminando provincias:', provError.message);
        } else {
            console.log('✅ Provincias eliminadas');
        }

        // Paso 5: Eliminar categorías IVA
        console.log('\n5️⃣ Eliminando categorías IVA...');
        const { error: ivaError } = await supabase
            .from('categorias_iva')
            .delete()
            .neq('id', 0);

        if (ivaError) {
            console.error('❌ Error eliminando categorías IVA:', ivaError.message);
        } else {
            console.log('✅ Categorías IVA eliminadas');
        }

        // Verificar estado
        console.log('\n📊 Verificando estado...');
        const { data: sociosCount } = await supabase
            .from('socios')
            .select('id', { count: 'exact', head: true });

        const { data: tarjetasCount } = await supabase
            .from('tarjetas')
            .select('id', { count: 'exact', head: true });

        console.log(`   Socios restantes: ${sociosCount?.length || 0}`);
        console.log(`   Tarjetas restantes: ${tarjetasCount?.length || 0}`);

        console.log('\n✅ Base de datos limpia y lista para re-migración');

    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

cleanDatabase()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
