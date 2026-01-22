import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

// Configuración Supabase
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

// ============================================================================
// Función para limpiar tablas usando la API de Supabase
// ============================================================================

async function limpiarTabla(tabla, columnaId = 'id', condicion = null) {
    try {
        let query = supabase.from(tabla).delete();

        if (condicion) {
            // Condición específica (ej: para socios mantener id=0)
            query = query.neq(columnaId, condicion);
        } else {
            // Borrar todo usando neq con valor imposible
            query = query.neq(columnaId, -999999999);
        }

        const { error } = await query;

        if (error) {
            // Si el error es de RLS, indicarlo claramente
            if (error.message.includes('violates row-level security') ||
                error.message.includes('row-level security')) {
                console.log(`   ⚠️  ${tabla}: RLS activo - ejecuta deshabilitar_rls.sql primero`);
                return { success: false, rls: true };
            }
            console.log(`   ⚠️  ${tabla}: ${error.message}`);
            return { success: false, rls: false };
        }

        console.log(`   ✅ ${tabla} limpiada`);
        return { success: true, rls: false };

    } catch (e) {
        console.log(`   ⚠️  ${tabla}: ${e.message}`);
        return { success: false, rls: false };
    }
}

async function limpiarTablasDirecto() {
    console.log('\n📋 Limpiando tablas para re-migración...\n');

    let rlsProblems = false;

    // Orden correcto: de dependientes a padres
    // IMPORTANTE: respetar foreign keys
    const tablas = [
        { nombre: 'asientos_items', columna: 'id' },
        { nombre: 'asientos_header', columna: 'id' },
        { nombre: 'operaciones_detalle_valores_tesoreria', columna: 'id' },
        { nombre: 'valores_tesoreria', columna: 'id' },
        { nombre: 'operaciones_detalle_cuentas_corrientes', columna: 'id' },
        { nombre: 'detalle_cuentas_corrientes', columna: 'idtransaccion' },
        { nombre: 'cuentas_corrientes', columna: 'idtransaccion' },
        { nombre: 'conceptos_socios', columna: 'id' },
        { nombre: 'observaciones_socios', columna: 'id' },
    ];

    for (const tabla of tablas) {
        const result = await limpiarTabla(tabla.nombre, tabla.columna);
        if (result.rls) rlsProblems = true;
    }

    // Socios - mantener id=0
    const resultSocios = await limpiarTabla('socios', 'id', 0);
    if (resultSocios.rls) rlsProblems = true;

    // Limpiar conceptos y cuentas (en orden por FK)
    console.log('   Preparando para limpiar conceptos y cuentas...');
    try {
        // 1. Borrar conceptos (que tiene FK a cuentas)
        const resultConceptos = await limpiarTabla('conceptos', 'concepto');
        if (resultConceptos.rls) rlsProblems = true;

        // 2. Ahora sí podemos borrar cuentas
        const resultCuentas = await limpiarTabla('cuentas', 'cuenta');
        if (resultCuentas.rls) rlsProblems = true;
    } catch (e) {
        console.log(`   ⚠️  Error limpiando conceptos/cuentas: ${e.message}`);
    }

    return !rlsProblems;
}

async function limpiarEspaciosTiposComprobante() {
    console.log('\n📋 Limpiando espacios en tipos de comprobante...');

    try {
        // Obtener tipos con espacios
        const { data: tipos, error } = await supabase
            .from('tipos_comprobante_socios')
            .select('*');

        if (error) {
            console.log(`   ⚠️  Error leyendo tipos: ${error.message}`);
            return;
        }

        const tiposConEspacios = tipos?.filter(t => t.comprobante !== t.comprobante.trim()) || [];

        if (tiposConEspacios.length === 0) {
            console.log('   ✅ No hay tipos con espacios');
            return;
        }

        console.log(`   Encontrados ${tiposConEspacios.length} tipos con espacios`);

        // Para cada tipo con espacios, crear versión sin espacios si no existe
        for (const tipo of tiposConEspacios) {
            const trimmed = tipo.comprobante.trim();
            const existe = tipos.find(t => t.comprobante === trimmed);

            if (!existe) {
                const { error: insertError } = await supabase
                    .from('tipos_comprobante_socios')
                    .insert({
                        comprobante: trimmed,
                        descripcion: tipo.descripcion,
                        id_tipo_movimiento: tipo.id_tipo_movimiento,
                        signo: tipo.signo
                    });

                if (insertError) {
                    console.log(`   ⚠️  Error insertando ${trimmed}: ${insertError.message}`);
                }
            }
        }

        console.log('   ✅ Completado');

    } catch (e) {
        console.log(`   ⚠️  Error: ${e.message}`);
    }
}

// ============================================================================
// Main
// ============================================================================

async function main() {
    console.log('========================================');
    console.log('  Preparación para Migración');
    console.log('========================================');
    console.log('');

    try {
        // Verificar conexión
        console.log('🔌 Verificando conexión a Supabase...');
        const { data, error } = await supabase.from('socios').select('id').limit(1);
        if (error) throw error;
        console.log('✅ Conectado a Supabase');

        // Ejecutar limpieza directa
        const limpiezaOk = await limpiarTablasDirecto();

        // Limpiar espacios en tipos de comprobante
        await limpiarEspaciosTiposComprobante();

        if (!limpiezaOk) {
            console.log('\n========================================');
            console.log('⚠️  ATENCIÓN: Algunas tablas tienen RLS activo');
            console.log('========================================');
            console.log('\nDebes ejecutar primero en Supabase SQL Editor:');
            console.log('  database/migrations/deshabilitar_rls.sql');
            console.log('\nLuego vuelve a ejecutar este script.');
            process.exit(1);
        }

        console.log('\n========================================');
        console.log('✅ PREPARACIÓN COMPLETADA');
        console.log('========================================');
        console.log('\nPróximo paso: ejecutar los scripts de migración');

        process.exit(0);

    } catch (error) {
        console.error('\n💥 ERROR:', error.message);
        process.exit(1);
    }
}

main();
