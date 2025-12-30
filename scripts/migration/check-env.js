import dotenv from 'dotenv';
dotenv.config();

console.log('Server:', process.env.SQLSERVER_SERVER);
console.log('Database:', process.env.SQLSERVER_DATABASE);
console.log('User:', process.env.SQLSERVER_USER);
console.log('Port:', process.env.SQLSERVER_PORT);
