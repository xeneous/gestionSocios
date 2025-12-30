import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

// Configuración SQL Server
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

// Configuración Supabase
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function migrateTarjetas() {
    console.log('🔄 Migrando tarjetas desde SQL Server...\n');

    try {
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado a SQL Server');

        // Migrar tarjetas
        console.log('\n📋 Leyendo tarjetas desde SQL Server...');
        const tarjetas = await pool.request().query('SELECT IdTarjeta, Descripcion FROM Tarjetas ORDER BY IdTarjeta');

        console.log(`Encontradas ${tarjetas.recordset.length} tarjetas`);

        if (tarjetas.recordset.length > 0) {
            console.log('\nTarjetas a migrar:');
            tarjetas.recordset.forEach(t => {
                console.log(`   ID ${t.IdTarjeta}: ${t.Descripcion}`);
            });

            console.log('\n📤 Insertando en Supabase...');
            const { data, error } = await supabase
                .from('tarjetas')
                .insert(tarjetas.recordset.map(t => ({
                    id: t.IdTarjeta,              // PRESERVAR EL ID ORIGINAL
                    codigo: t.IdTarjeta,
                    descripcion: t.Descripcion?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando tarjetas:', error.message);
                console.error('Detalles:', error);
            } else {
                console.log(`✅ ${tarjetas.recordset.length} tarjetas migradas exitosamente`);
                console.log('   IDs preservados desde MS SQL Server');
            }
        }

        await pool.close();

        // Verificar resultado
        console.log('\n📊 Verificando en Supabase...');
        const { data: verifyData, count } = await supabase
            .from('tarjetas')
            .select('*', { count: 'exact' })
            .order('id');

        console.log(`Total de tarjetas en Supabase: ${count}`);
        if (verifyData) {
            console.log('\nTarjetas en Supabase:');
            verifyData.forEach(t => {
                console.log(`   ID ${t.id}: ${t.descripcion} (código: ${t.codigo})`);
            });
        }

        console.log('\n✅ Migración de tarjetas completada');

    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

migrateTarjetas()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
