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

const pool = await sql.connect(sqlConfig);
const result = await pool.request().query('SELECT Grupo, Descripcion FROM Grupos_Agrupados ORDER BY Grupo');

console.log('Grupos en SQL Server:');
result.recordset.forEach(g => {
    console.log(`  ${g.Grupo} - ${g.Descripcion}`);
});

console.log(`\nTotal: ${result.recordset.length} grupos`);

// Buscar duplicados
const codes = result.recordset.map(g => g.Grupo?.trim()).filter(Boolean);
const duplicates = codes.filter((item, index) => codes.indexOf(item) !== index);
if (duplicates.length > 0) {
    console.log('\n❌ Códigos duplicados:', duplicates);
} else {
    console.log('\n✅ No hay códigos duplicados');
}

await pool.close();
