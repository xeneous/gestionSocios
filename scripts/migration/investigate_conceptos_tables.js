import sql from 'mssql';
import dotenv from 'dotenv';

dotenv.config();

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

async function investigateTables() {
    console.log('🔍 Investigando estructura de tablas en SQL Server...\n');

    try {
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado a SQL Server\n');

        // 1. Investigar CONCEPTOS
        console.log('============================================');
        console.log('TABLA: conceptos');
        console.log('============================================');
        const conceptosSchema = await pool.request().query(`
            SELECT 
                COLUMN_NAME,
                DATA_TYPE,
                CHARACTER_MAXIMUM_LENGTH,
                IS_NULLABLE,
                ORDINAL_POSITION
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'conceptos'
            ORDER BY ORDINAL_POSITION
        `);
        console.table(conceptosSchema.recordset);

        console.log('\nDatos de muestra:');
        const conceptosSample = await pool.request().query('SELECT TOP 3 * FROM conceptos');
        console.table(conceptosSample.recordset);

        // 2. Investigar CONCEPTOS_SOCIOS
        console.log('\n============================================');
        console.log('TABLA: conceptos_socios');
        console.log('============================================');
        const conceptosSociosSchema = await pool.request().query(`
            SELECT 
                COLUMN_NAME,
                DATA_TYPE,
                CHARACTER_MAXIMUM_LENGTH,
                IS_NULLABLE,
                ORDINAL_POSITION
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'conceptos_socios'
            ORDER BY ORDINAL_POSITION
        `);
        console.table(conceptosSociosSchema.recordset);

        console.log('\nDatos de muestra:');
        const conceptosSociosSample = await pool.request().query('SELECT TOP 3 * FROM conceptos_socios');
        console.table(conceptosSociosSample.recordset);

        // 3. Investigar OBSERVACIONES_SOCIOS
        console.log('\n============================================');
        console.log('TABLA: observaciones_socios');
        console.log('============================================');
        const observacionesSchema = await pool.request().query(`
            SELECT 
                COLUMN_NAME,
                DATA_TYPE,
                CHARACTER_MAXIMUM_LENGTH,
                IS_NULLABLE,
                ORDINAL_POSITION
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = 'observaciones_socios'
            ORDER BY ORDINAL_POSITION
        `);
        console.table(observacionesSchema.recordset);

        console.log('\nDatos de muestra:');
        const observacionesSample = await pool.request().query('SELECT TOP 3 * FROM observaciones_socios ORDER BY fecha DESC');
        console.table(observacionesSample.recordset);

        // Conteos
        console.log('\n============================================');
        console.log('CONTEOS DE REGISTROS');
        console.log('============================================');
        const counts = await pool.request().query(`
            SELECT 'conceptos' as tabla, COUNT(*) as total FROM conceptos
            UNION ALL
            SELECT 'conceptos_socios', COUNT(*) FROM conceptos_socios
            UNION ALL
            SELECT 'observaciones_socios', COUNT(*) FROM observaciones_socios
        `);
        console.table(counts.recordset);

        await pool.close();
        process.exit(0);

    } catch (error) {
        console.error('💥 ERROR:', error);
        process.exit(1);
    }
}

investigateTables();
