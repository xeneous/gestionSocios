import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const sqlConfig = {
    server: process.env.SQLSERVER_SERVER,
    port: parseInt(process.env.SQLSERVER_PORT),
    user: process.env.SQLSERVER_USER,
    password: process.env.SQLSERVER_PASSWORD,
    database: process.env.SQLSERVER_DATABASE,
    options: { encrypt: false, trustServerCertificate: true }
};

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

const FECHA_IMPORTACION = new Date().toISOString();
const USUARIO_IMPORTACION = 'Migración sistema anterior';

async function main() {
    console.log('Conectando a SQL Server (legacy)...');
    const pool = await sql.connect(sqlConfig);

    const result = await pool.request().query(`
        SELECT socio, Observa1
        FROM socios
        WHERE socio > 0
          AND Observa1 IS NOT NULL AND LTRIM(RTRIM(Observa1)) <> ''
        ORDER BY socio
    `);

    await pool.close();

    console.log(`Encontrados ${result.recordset.length} socios con Observa1 en SQL Server.\n`);

    // IDs de socios que sí existen en Supabase, para no violar la FK
    // (paginado: el default de Supabase corta en 1000 filas por consulta)
    const idsExistentes = new Set();
    let from = 0;
    const pageSize = 1000;
    while (true) {
        const { data: page, error: errSocios } = await supabase
            .from('socios')
            .select('id')
            .range(from, from + pageSize - 1);
        if (errSocios) throw errSocios;
        page.forEach(s => idsExistentes.add(s.id));
        if (page.length < pageSize) break;
        from += pageSize;
    }
    console.log(`IDs de socios cargados desde Supabase: ${idsExistentes.size}`);

    const rows = result.recordset
        .filter(r => idsExistentes.has(r.socio))
        .map(r => ({
            socio_id: r.socio,
            fecha: FECHA_IMPORTACION,
            observacion: `[Importado del sistema anterior] ${String(r.Observa1).trim()}`,
            usuario: USUARIO_IMPORTACION,
        }));

    const omitidos = result.recordset.length - rows.length;
    if (omitidos > 0) {
        console.log(`⚠️  ${omitidos} socios de SQL Server no existen en Supabase, se omiten.`);
    }

    const batchSize = 100;
    let migrados = 0;
    let errores = 0;

    for (let i = 0; i < rows.length; i += batchSize) {
        const batch = rows.slice(i, i + batchSize);
        const { error } = await supabase.from('observaciones_socios').insert(batch);
        if (error) {
            console.error(`❌ Error en lote ${Math.floor(i / batchSize) + 1}:`, error.message);
            errores += batch.length;
        } else {
            migrados += batch.length;
            console.log(`✅ Lote ${Math.floor(i / batchSize) + 1}: ${batch.length} observaciones importadas`);
        }
    }

    console.log(`\nTotal importadas: ${migrados}`);
    if (errores > 0) console.log(`Errores: ${errores}`);
}

main().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
