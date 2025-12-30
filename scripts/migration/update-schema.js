import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

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

async function updateSchema() {
    console.log('🔄 Actualizando schema de Supabase...\n');

    try {
        // Limpiar tablas para re-migrar
        console.log('🗑️  Limpiando tablas...');

        const { error: err1 } = await supabase.from('provincias').delete().neq('id', 0);
        if (err1) console.error('   Error limpiando provincias:', err1.message);
        else console.log('   ✅ provincias limpiada');

        const { error: err2 } = await supabase.from('categorias_iva').delete().neq('id', 0);
        if (err2) console.error('   Error limpiando categorias_iva:', err2.message);
        else console.log('   ✅ categorias_iva limpiada');

        const { error: err3 } = await supabase.from('grupos_agrupados').delete().neq('id', 0);
        if (err3) console.error('   Error limpiando grupos_agrupados:', err3.message);
        else console.log('   ✅ grupos_agrupados limpiada');

        console.log('\n✅ Tablas limpiadas. Ahora ejecutá en Supabase SQL Editor:');
        console.log(`
ALTER TABLE categorias_iva 
    ADD COLUMN IF NOT EXISTS ganancias INTEGER,
    ADD COLUMN IF NOT EXISTS tipo_factura_compras CHAR(1),
    ADD COLUMN IF NOT EXISTS tipo_factura_ventas CHAR(1),
    ADD COLUMN IF NOT EXISTS resumido VARCHAR(10);
        `);

    } catch (err) {
        console.error('💥 Error:', err.message);
    }
}

updateSchema();
