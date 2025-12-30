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
    options: {
        encrypt: false,
        trustServerCertificate: true
    }
};

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

(async () => {
    try {
        // Get conceptos from Supabase
        const { data: supabaseConceptos } = await supabase
            .from('conceptos')
            .select('concepto');

        const supabaseSet = new Set(supabaseConceptos.map(c => c.concepto));
        console.log(`Conceptos en Supabase: ${supabaseSet.size}`);

        // Get conceptos from SQL Server (only for socio < 10000)
        const pool = await sql.connect(sqlConfig);
        const sqlQuery = `
            SELECT DISTINCT dcc.Concepto
            FROM detallecuentascorrientes dcc
            INNER JOIN cuentascorrientes cc ON dcc.idtransaccion = cc.IdTransaccion
            WHERE cc.socio < 10000
        `;
        const result = await pool.request().query(sqlQuery);

        const sqlConceptos = result.recordset
            .map(r => r.Concepto?.trim())
            .filter(c => c);

        console.log(`Conceptos únicos en SQL Server: ${new Set(sqlConceptos).size}`);

        // Find missing conceptos
        const missing = sqlConceptos.filter(c => !supabaseSet.has(c));
        const uniqueMissing = [...new Set(missing)];

        console.log(`\nConceptos faltantes en Supabase: ${uniqueMissing.length}`);
        console.log(JSON.stringify(uniqueMissing, null, 2));

        await pool.close();
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
})();
