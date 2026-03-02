import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

// ============================================================================
// Actualiza campos de residencia en socios desde socios_bak
// Equivalente a:
//   UPDATE socios AS s
//   SET categoria_residente = sb.categoria_residente,
//       fecha_inicio_residencia = sb.fecha_inicio_residencia,
//       fecha_fin_residencia = sb.fecha_fin_residencia,
//       lugar_residencia = sb.lugar_residencia
//   FROM socios_bak AS sb
//   WHERE s.id = sb.id;
// ============================================================================

async function updateSociosResidencia() {
    console.log('Leyendo datos de residencia desde socios_bak...');

    const { data: bak, error: errBak } = await supabase
        .from('socios_bak')
        .select('id, categoria_residente, fecha_inicio_residencia, fecha_fin_residencia, lugar_residencia');

    if (errBak) throw new Error(`Error leyendo socios_bak: ${errBak.message}`);

    if (!bak || bak.length === 0) {
        console.log('socios_bak está vacía o no existe. Se omite este paso.');
        return;
    }

    console.log(`Actualizando ${bak.length} socios con datos de residencia...`);

    let actualizados = 0;
    let errores = 0;

    for (const row of bak) {
        const { error } = await supabase
            .from('socios')
            .update({
                categoria_residente: row.categoria_residente,
                fecha_inicio_residencia: row.fecha_inicio_residencia,
                fecha_fin_residencia: row.fecha_fin_residencia,
                lugar_residencia: row.lugar_residencia,
            })
            .eq('id', row.id);

        if (error) {
            console.warn(`  Advertencia socio ${row.id}: ${error.message}`);
            errores++;
        } else {
            actualizados++;
        }
    }

    console.log(`✓ ${actualizados} socios actualizados.`);
    if (errores > 0) console.warn(`  ${errores} errores (socios no encontrados o sin cambios).`);
}

updateSociosResidencia()
    .then(() => process.exit(0))
    .catch(err => {
        console.error('ERROR:', err.message);
        process.exit(1);
    });
