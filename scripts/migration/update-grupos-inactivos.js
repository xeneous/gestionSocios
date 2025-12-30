import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function reorganizarGrupos() {
    console.log('🔄 Reorganizando grupos...\n');

    try {
        // 1. Marcar grupos como inactivos: R, F, B, M
        const gruposInactivos = ['R', 'F', 'B', 'M'];

        console.log('📝 Marcando grupos como inactivos...');
        const { data: inactivos, error: errorInactivos } = await supabase
            .from('grupos_agrupados')
            .update({ activo: false })
            .in('codigo', gruposInactivos)
            .select();

        if (errorInactivos) {
            console.error('❌ Error actualizando grupos inactivos:', errorInactivos.message);
            return;
        }

        console.log(`✅ ${inactivos.length} grupos marcados como inactivos:`);
        inactivos.forEach(grupo => {
            console.log(`   - ${grupo.codigo}: ${grupo.descripcion}`);
        });

        // 2. Verificar si hay socios usando los grupos a eliminar
        const gruposAEliminar = ['C', 'G', 'N', 'P'];

        console.log('\n🔍 Verificando socios con grupos a eliminar...');
        const { data: sociosAfectados, error: errorCheck } = await supabase
            .from('socios')
            .select('id, apellido, nombre, grupo')
            .in('grupo', gruposAEliminar);

        if (errorCheck) {
            console.error('❌ Error verificando socios:', errorCheck.message);
            return;
        }

        if (sociosAfectados && sociosAfectados.length > 0) {
            console.log(`\n⚠️  ADVERTENCIA: Hay ${sociosAfectados.length} socio(s) usando estos grupos:`);
            sociosAfectados.forEach(socio => {
                console.log(`   - ${socio.apellido} ${socio.nombre} (Grupo: ${socio.grupo})`);
            });
            console.log('\n❌ No se pueden eliminar grupos con socios asignados.');
            console.log('   Por favor, reasigna estos socios a otros grupos primero.\n');
            return;
        }

        console.log('✅ No hay socios usando estos grupos\n');

        // 3. Eliminar grupos C, G, N, P
        console.log('🗑️  Eliminando grupos...');
        const { data: eliminados, error: errorDelete } = await supabase
            .from('grupos_agrupados')
            .delete()
            .in('codigo', gruposAEliminar)
            .select();

        if (errorDelete) {
            console.error('❌ Error eliminando grupos:', errorDelete.message);
            return;
        }

        console.log(`✅ ${eliminados.length} grupos eliminados:`);
        eliminados.forEach(grupo => {
            console.log(`   - ${grupo.codigo}: ${grupo.descripcion}`);
        });

        // 4. Mostrar estado final
        console.log('\n📋 Estado final de grupos:');
        const { data: todosGrupos, error: errorLista } = await supabase
            .from('grupos_agrupados')
            .select('*')
            .order('codigo');

        if (errorLista) {
            console.error('❌ Error listando grupos:', errorLista.message);
            return;
        }

        console.log('\n✅ GRUPOS ACTIVOS:');
        todosGrupos.filter(g => g.activo).forEach(grupo => {
            console.log(`   ${grupo.codigo} - ${grupo.descripcion}`);
        });

        console.log('\n❌ GRUPOS INACTIVOS:');
        todosGrupos.filter(g => !g.activo).forEach(grupo => {
            console.log(`   ${grupo.codigo} - ${grupo.descripcion}`);
        });

        console.log(`\nTotal: ${todosGrupos.length} grupos (${todosGrupos.filter(g => g.activo).length} activos, ${todosGrupos.filter(g => !g.activo).length} inactivos)`);

    } catch (err) {
        console.error('💥 Error:', err.message);
    }
}

reorganizarGrupos();
