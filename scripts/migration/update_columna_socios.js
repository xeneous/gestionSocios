import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

// ============================================================
//  Script genérico: actualizar UNA columna de socios
//  desde SQL Server hacia Supabase sin tocar el resto.
//
//  Uso:
//    node update_columna_socios.js
//    node update_columna_socios.js --columna-sql NroMatricula2 --columna-supa matricula_provincial
//    node update_columna_socios.js --columna-sql Matricula --columna-supa matricula_provincial --dry-run
//
//  Flags:
//    --columna-sql   Nombre de la columna en SQL Server (default: Matricula)
//    --columna-supa  Nombre de la columna en Supabase   (default: matricula_provincial)
//    --dry-run       Solo muestra qué haría, sin escribir en Supabase
//    --solo-vacios   Solo actualiza registros donde Supabase tiene NULL/vacío
// ============================================================

// --- Parseo de argumentos ---
const args = process.argv.slice(2);
function getArg(name, defaultVal) {
    const idx = args.indexOf(name);
    if (idx === -1) return defaultVal;
    return args[idx + 1] || defaultVal;
}
const dryRun = args.includes('--dry-run');
const soloVacios = args.includes('--solo-vacios');
const columnaSql = getArg('--columna-sql', 'Matricula');
const columnaSupa = getArg('--columna-supa', 'matricula_provincial');

// --- Configuración SQL Server (solo lectura) ---
const sqlConfig = {
    server: process.env.SQLSERVER_SERVER,
    port: parseInt(process.env.SQLSERVER_PORT),
    user: process.env.SQLSERVER_USER,
    password: process.env.SQLSERVER_PASSWORD,
    database: process.env.SQLSERVER_DATABASE,
    options: {
        encrypt: false,
        trustServerCertificate: true
    }
};

// --- Configuración Supabase ---
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function updateColumna() {
    console.log('========================================');
    console.log('  Actualización parcial de socios');
    console.log('========================================');
    console.log(`  SQL Server:  socios.${columnaSql}`);
    console.log(`  Supabase:    socios.${columnaSupa}`);
    console.log(`  Dry run:     ${dryRun ? 'SÍ (no escribe)' : 'NO (escribe en Supabase)'}`);
    console.log(`  Solo vacíos: ${soloVacios ? 'SÍ' : 'NO'}`);
    console.log('========================================\n');

    let pool;
    try {
        // 1. Conectar a SQL Server
        console.log('Conectando a SQL Server...');
        pool = await sql.connect(sqlConfig);
        console.log('Conectado a SQL Server\n');

        // 2. Leer columna desde SQL Server
        console.log(`Leyendo socio + ${columnaSql} de SQL Server...`);
        const result = await pool.request().query(`
            SELECT socio, ${columnaSql}
            FROM socios
            ORDER BY socio
        `);
        console.log(`${result.recordset.length} registros leídos\n`);

        // Armar mapa socio -> valor
        const valoresMap = {};
        let conValor = 0;
        let sinValor = 0;
        for (const row of result.recordset) {
            const valor = row[columnaSql];
            const valorLimpio = valor != null ? valor.toString().trim() : null;
            valoresMap[row.socio] = valorLimpio || null;
            if (valorLimpio) conValor++;
            else sinValor++;
        }
        console.log(`  Con valor: ${conValor}`);
        console.log(`  Sin valor (NULL/vacío): ${sinValor}\n`);

        // 3. Si --solo-vacios, leer valores actuales de Supabase para filtrar
        let sociosConValorEnSupa = new Set();
        if (soloVacios) {
            console.log(`Leyendo valores actuales de ${columnaSupa} en Supabase...`);
            const { data, error } = await supabase
                .from('socios')
                .select(`id, ${columnaSupa}`);
            if (error) throw new Error(`Error leyendo Supabase: ${error.message}`);
            for (const row of data) {
                if (row[columnaSupa] != null && row[columnaSupa] !== '') {
                    sociosConValorEnSupa.add(row.id);
                }
            }
            console.log(`  ${sociosConValorEnSupa.size} socios ya tienen valor en Supabase (se saltean)\n`);
        }

        // 4. Preparar updates
        const updates = [];
        for (const [socioId, valor] of Object.entries(valoresMap)) {
            const id = parseInt(socioId);
            if (soloVacios && sociosConValorEnSupa.has(id)) continue;
            updates.push({ id, valor });
        }

        console.log(`${updates.length} registros a actualizar\n`);

        if (updates.length === 0) {
            console.log('Nada que actualizar.');
            return;
        }

        // 5. Preview de los primeros 10
        console.log('Preview (primeros 10):');
        for (const u of updates.slice(0, 10)) {
            console.log(`  Socio ${u.id}: ${columnaSupa} = "${u.valor ?? 'NULL'}"`);
        }
        if (updates.length > 10) {
            console.log(`  ... y ${updates.length - 10} más\n`);
        }

        if (dryRun) {
            console.log('\n-- DRY RUN: no se escribió nada en Supabase --');
            return;
        }

        // 6. Actualizar en lotes
        console.log('\nActualizando Supabase...');
        const batchSize = 50;
        let actualizados = 0;
        let errores = 0;

        for (let i = 0; i < updates.length; i += batchSize) {
            const batch = updates.slice(i, i + batchSize);

            // Supabase no tiene bulk update por PK, hacemos uno por uno en paralelo
            const promises = batch.map(u =>
                supabase
                    .from('socios')
                    .update({ [columnaSupa]: u.valor })
                    .eq('id', u.id)
            );

            const results = await Promise.all(promises);

            for (let j = 0; j < results.length; j++) {
                if (results[j].error) {
                    console.error(`  Error socio ${batch[j].id}: ${results[j].error.message}`);
                    errores++;
                } else {
                    actualizados++;
                }
            }

            const progreso = Math.min(i + batchSize, updates.length);
            process.stdout.write(`  ${progreso}/${updates.length} procesados\r`);
        }

        console.log('\n');
        console.log('========================================');
        console.log('  Resultado');
        console.log('========================================');
        console.log(`  Actualizados: ${actualizados}`);
        console.log(`  Errores:      ${errores}`);
        console.log('========================================');

    } catch (err) {
        console.error('\nError fatal:', err.message);
        process.exit(1);
    } finally {
        if (pool) await pool.close();
    }
}

updateColumna();
