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

async function checkSociosStructure() {
  let pool;
  try {
    console.log('🔍 Conectando a SQL Server...');
    pool = await sql.connect(sqlConfig);

    console.log('\n📊 Estructura de tabla socios:');
    const cols = await pool.request().query(`
      SELECT COLUMN_NAME, DATA_TYPE
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_NAME = 'socios'
      ORDER BY ORDINAL_POSITION
    `);

    cols.recordset.forEach(c => {
      console.log(`   - ${c.COLUMN_NAME} (${c.DATA_TYPE})`);
    });

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    if (pool) {
      await pool.close();
    }
  }
}

checkSociosStructure();
