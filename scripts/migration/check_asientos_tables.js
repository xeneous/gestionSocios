import sql from 'mssql';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

const sqlConfig = {
  server: process.env.SQLSERVER_SERVER,
  port: parseInt(process.env.SQLSERVER_PORT),
  user: process.env.SQLSERVER_USER,
  password: process.env.SQLSERVER_PASSWORD,
  database: process.env.SQLSERVER_DATABASE,
  options: {
    encrypt: false,
    trustServerCertificate: true,
  },
};

async function checkTables() {
  let pool;
  try {
    console.log('🔍 Conectando a SQL Server...');
    pool = await sql.connect(sqlConfig);

    // Buscar tablas relacionadas con asientos
    const result = await pool.request().query(`
      SELECT TABLE_NAME
      FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_TYPE = 'BASE TABLE'
      AND TABLE_NAME LIKE '%asient%'
      ORDER BY TABLE_NAME
    `);

    console.log('\n📋 Tablas encontradas con "asient":');
    result.recordset.forEach(r => {
      console.log(`   - ${r.TABLE_NAME}`);
    });

    // Si encontramos alguna tabla, mostrar su estructura
    if (result.recordset.length > 0) {
      for (const table of result.recordset) {
        console.log(`\n📊 Estructura de ${table.TABLE_NAME}:`);
        const cols = await pool.request().query(`
          SELECT COLUMN_NAME, DATA_TYPE
          FROM INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_NAME = '${table.TABLE_NAME}'
          ORDER BY ORDINAL_POSITION
        `);
        cols.recordset.forEach(c => {
          console.log(`   - ${c.COLUMN_NAME} (${c.DATA_TYPE})`);
        });
      }
    }

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    if (pool) {
      await pool.close();
    }
  }
}

checkTables();
