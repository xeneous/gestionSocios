import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config({ path: join(__dirname, '.env') });

// Configuración SQL Server
const sqlConfig = {
  server: process.env.SQLSERVER_SERVER,
  port: parseInt(process.env.SQLSERVER_PORT),
  user: process.env.SQLSERVER_USER,
  password: process.env.SQLSERVER_PASSWORD,
  database: process.env.SQLSERVER_DATABASE,
  options: {
    encrypt: false,
    trustServerCertificate: true,
    enableArithAbort: true,
  },
  connectionTimeout: 30000,
  requestTimeout: 60000,
};

// Configuración Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      persistSession: false
    }
  }
);

async function migrateAsientosDiario() {
  let pool;

  try {
    console.log('🔄 Conectando a SQL Server...');
    pool = await sql.connect(sqlConfig);

    // ============================================================================
    // MIGRAR HEADERS DE ASIENTOS
    // ============================================================================
    console.log('\n📋 Migrando headers de asientos de diario...');

    const headersResult = await pool.request().query(`
      SELECT
        asiento,
        aniomes,
        tipoasiento,
        fecha,
        detalle,
        centrocosto
      FROM AsientosDiariosHeader
      ORDER BY asiento, aniomes, tipoasiento
    `);

    console.log(`✅ Encontrados ${headersResult.recordset.length} asientos en SQL Server`);

    // Limpiar tabla en Supabase
    console.log('🗑️  Limpiando tabla asientos_header en Supabase...');
    const { error: deleteError } = await supabase
      .from('asientos_header')
      .delete()
      .gte('asiento', 0);

    if (deleteError) {
      console.error('❌ Error limpiando asientos_header:', deleteError);
    }

    // Insertar en lotes
    const BATCH_SIZE = 1000;
    let insertedHeaders = 0;
    let skippedHeaders = 0;

    for (let i = 0; i < headersResult.recordset.length; i += BATCH_SIZE) {
      const batch = headersResult.recordset.slice(i, i + BATCH_SIZE);

      const dataToInsert = batch.map(row => {
        return {
          asiento: row.asiento,
          anio_mes: row.aniomes,
          tipo_asiento: row.tipoasiento,
          fecha: row.fecha?.toISOString().split('T')[0] || null,
          detalle: row.detalle?.trim() || null,
          centro_costo: row.centrocosto || null,
        };
      });

      const { error: insertError } = await supabase
        .from('asientos_header')
        .insert(dataToInsert);

      if (insertError) {
        console.error(`❌ Error insertando lote ${i / BATCH_SIZE + 1}:`, insertError);
        skippedHeaders += dataToInsert.length;
      } else {
        insertedHeaders += dataToInsert.length;
        console.log(`✅ Insertados ${insertedHeaders} / ${headersResult.recordset.length} headers`);
      }
    }

    console.log(`\n✅ Migración de headers completada: ${insertedHeaders} registros insertados, ${skippedHeaders} omitidos`);

    // ============================================================================
    // MIGRAR ITEMS DE ASIENTOS
    // ============================================================================
    console.log('\n📋 Migrando items de asientos de diario...');

    // Obtener todos los asientos válidos desde Supabase (con clave compuesta)
    console.log('🔍 Obteniendo asientos válidos desde Supabase...');

    let allAsientos = [];
    let fromAsiento = 0;
    const pageSizeAsiento = 1000;

    while (true) {
      const { data: asientosData, error: asientosError } = await supabase
        .from('asientos_header')
        .select('asiento, anio_mes, tipo_asiento')
        .range(fromAsiento, fromAsiento + pageSizeAsiento - 1);

      if (asientosError) {
        console.error('❌ Error consultando asientos_header:', asientosError);
        throw asientosError;
      }

      if (!asientosData || asientosData.length === 0) break;

      allAsientos = allAsientos.concat(asientosData);

      if (asientosData.length < pageSizeAsiento) break;
      fromAsiento += pageSizeAsiento;
    }

    // Crear Set con clave compuesta
    const validAsientoKeys = new Set(
      allAsientos.map(a => `${a.asiento}-${a.anio_mes}-${a.tipo_asiento}`)
    );
    console.log(`✅ Encontrados ${validAsientoKeys.size} asientos válidos en Supabase`);

    // Obtener todos los items de asientos desde SQL Server
    const itemsResult = await pool.request().query(`
      SELECT
        asiento,
        aniomes,
        tipoasiento,
        item,
        cuenta,
        debe,
        haber,
        observacion
      FROM AsientosDiariosItems
      ORDER BY asiento, aniomes, tipoasiento, item
    `);

    console.log(`✅ Encontrados ${itemsResult.recordset.length} items en SQL Server`);

    // Limpiar tabla en Supabase
    console.log('🗑️  Limpiando tabla asientos_items en Supabase...');

    const { error: deleteItemsError } = await supabase
      .from('asientos_items')
      .delete()
      .gte('item', 0);

    if (deleteItemsError) {
      console.error('❌ Error limpiando asientos_items:', deleteItemsError);
    }

    // Obtener todas las cuentas válidas desde Supabase y crear mapeo
    console.log('🔍 Obteniendo cuentas válidas desde Supabase...');

    // Primero vamos a verificar qué columnas tiene la tabla
    const { data: sampleCuenta, error: sampleError } = await supabase
      .from('cuentas')
      .select('*')
      .limit(1);

    if (sampleError) {
      console.error('❌ Error consultando muestra de cuentas:', sampleError);
      throw sampleError;
    }

    console.log('📋 Columnas disponibles en cuentas:', sampleCuenta && sampleCuenta.length > 0 ? Object.keys(sampleCuenta[0]) : 'Tabla vacía');

    // Intentar obtener cuenta, id si existe, sino solo cuenta
    let cuentasData;
    let cuentasError;

    if (sampleCuenta && sampleCuenta.length > 0 && sampleCuenta[0].hasOwnProperty('id')) {
      // La tabla tiene columna id
      const result = await supabase
        .from('cuentas')
        .select('id, cuenta');
      cuentasData = result.data;
      cuentasError = result.error;
    } else {
      // La tabla NO tiene columna id, solo cuenta
      const result = await supabase
        .from('cuentas')
        .select('cuenta');
      cuentasData = result.data;
      cuentasError = result.error;
    }

    if (cuentasError) {
      console.error('❌ Error consultando cuentas:', cuentasError);
      throw cuentasError;
    }

    const hasIdColumn = cuentasData && cuentasData.length > 0 && cuentasData[0].hasOwnProperty('id');
    const cuentaToIdMap = hasIdColumn
      ? new Map(cuentasData.map(c => [c.cuenta, c.id]))
      : new Map(cuentasData.map(c => [c.cuenta, c.cuenta])); // Usar cuenta como ID si no existe id

    console.log(`✅ Encontradas ${cuentaToIdMap.size} cuentas válidas en Supabase (usa columna ${hasIdColumn ? 'id' : 'cuenta'})`);

    // Insertar items en lotes
    let insertedItems = 0;
    let skippedItems = 0;

    for (let i = 0; i < itemsResult.recordset.length; i += BATCH_SIZE) {
      const batch = itemsResult.recordset.slice(i, i + BATCH_SIZE);

      const dataToInsert = batch
        .filter(row => {
          // Solo insertar items cuyo asiento exista en asientos_header (validar clave compuesta)
          const key = `${row.asiento}-${row.aniomes}-${row.tipoasiento}`;
          if (!validAsientoKeys.has(key)) {
            skippedItems++;
            return false;
          }
          return true;
        })
        .map(row => {
          // Validar que la cuenta exista y obtener su ID
          const cuentaNumero = row.cuenta;
          const cuentaId = cuentaToIdMap.get(cuentaNumero);

          if (cuentaNumero && !cuentaId) {
            console.log(`⚠️  Advertencia: Cuenta ${cuentaNumero} no existe en Supabase (asiento ${row.asiento}/${row.aniomes}/${row.tipoasiento}, item ${row.item})`);
          }

          return {
            asiento: row.asiento,
            anio_mes: row.aniomes,
            tipo_asiento: row.tipoasiento,
            item: row.item,
            cuenta_id: cuentaId || null,
            debe: row.debe || 0,
            haber: row.haber || 0,
            observacion: row.observacion?.trim() || null,
          };
        });

      if (dataToInsert.length === 0) continue;

      // Eliminar duplicados dentro del mismo lote usando Map
      const uniqueData = Array.from(
        new Map(
          dataToInsert.map(item => [`${item.asiento}-${item.anio_mes}-${item.tipo_asiento}-${item.item}`, item])
        ).values()
      );

      const { error: insertError } = await supabase
        .from('asientos_items')
        .insert(uniqueData);

      if (insertError) {
        console.error(`❌ Error insertando lote de items ${i / BATCH_SIZE + 1}:`, insertError);
        skippedItems += dataToInsert.length;
      } else {
        insertedItems += dataToInsert.length;
        console.log(`✅ Insertados ${insertedItems} / ${itemsResult.recordset.length} items (${skippedItems} omitidos)`);
      }
    }

    console.log(`\n✅ Migración de items completada: ${insertedItems} registros insertados, ${skippedItems} omitidos`);

    // ============================================================================
    // RESUMEN
    // ============================================================================
    console.log('\n' + '='.repeat(80));
    console.log('🎉 MIGRACIÓN COMPLETADA EXITOSAMENTE');
    console.log('='.repeat(80));
    console.log(`📊 Headers migrados: ${insertedHeaders}`);
    console.log(`📊 Items migrados: ${insertedItems}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error('\n❌ Error en la migración:', error);
    throw error;
  } finally {
    if (pool) {
      await pool.close();
      console.log('\n🔌 Conexión a SQL Server cerrada');
    }
  }
}

// Ejecutar migración
migrateAsientosDiario()
  .then(() => {
    console.log('\n✅ Script finalizado correctamente');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script finalizado con errores:', error);
    process.exit(1);
  });
