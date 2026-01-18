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

async function migrateValoresTesoreria() {
  let pool;

  try {
    console.log('🔄 Conectando a SQL Server...');
    pool = await sql.connect(sqlConfig);

    // ============================================================================
    // MIGRAR CONCEPTOS_TESORERIA
    // ============================================================================
    console.log('\n📋 Migrando Conceptos_Tesoreria...');

    // Obtener todos los registros de Conceptos_Tesoreria
    const conceptosQuery = `
      SELECT
        idConcepto_Tesoreria,
        Descripcion,
        Imputacion_Contable,
        Modalidad,
        CI,
        CE,
        Unificador,
        Mostrador,
        MonedaExtranjera
      FROM Conceptos_Tesoreria
      ORDER BY idConcepto_Tesoreria
    `;

    const conceptosResult = await pool.request().query(conceptosQuery);
    const conceptos = conceptosResult.recordset;
    console.log(`✅ Obtenidos ${conceptos.length} registros de Conceptos_Tesoreria`);

    // Preparar datos para Supabase
    let insertados = 0;
    let omitidos = 0;
    const batchSize = 100;

    for (let i = 0; i < conceptos.length; i += batchSize) {
      const batch = conceptos.slice(i, i + batchSize);
      const dataToInsert = batch.map(row => ({
        id: row.idConcepto_Tesoreria,
        descripcion: row.Descripcion || null,
        imputacion_contable: row.Imputacion_Contable || null,
        modalidad: row.Modalidad || 0,
        ci: row.CI || 'N',
        ce: row.CE || 'N',
        unificador: row.Unificador || null,
        mostrador: row.Mostrador || 0,
        moneda_extranjera: row.MonedaExtranjera || 0,
      }));

      // Insertar en Supabase con UPSERT
      const { data, error } = await supabase
        .from('conceptos_tesoreria')
        .upsert(dataToInsert, { onConflict: 'id' });

      if (error) {
        console.error(`❌ Error insertando batch ${i / batchSize + 1}:`, error);
        omitidos += batch.length;
      } else {
        insertados += batch.length;
        console.log(`✅ Insertados ${insertados} de ${conceptos.length} conceptos...`);
      }
    }

    console.log(`\n✅ Migración de Conceptos_Tesoreria completada:`);
    console.log(`   - Insertados: ${insertados}`);
    console.log(`   - Omitidos: ${omitidos}`);

    // ============================================================================
    // MIGRAR VALORESTESORERIA
    // ============================================================================
    console.log('\n📋 Migrando ValoresTesoreria...');

    // Obtener todos los registros de ValoresTesoreria
    const valoresQuery = `
      SELECT
        idTransaccion,
        idTransaccionOrigen,
        TipoMovimiento,
        idConcepto_Tesoreria,
        FechaEmision,
        Vencimiento,
        Banco,
        Cuenta,
        Sucursal,
        Numero,
        NumeroInterno,
        Firma,
        importe,
        Cancelado,
        idOperador,
        Observaciones,
        locked,
        cobrador,
        Corregido,
        tipocambio,
        base
      FROM ValoresTesoreria
      ORDER BY idTransaccion
    `;

    const valoresResult = await pool.request().query(valoresQuery);
    const valores = valoresResult.recordset;
    console.log(`✅ Obtenidos ${valores.length} registros de ValoresTesoreria`);

    // Validar FKs: obtener todos los IDs válidos de conceptos_tesoreria
    console.log('\n🔍 Validando conceptos_tesoreria...');
    const { data: validConceptos, error: conceptosError } = await supabase
      .from('conceptos_tesoreria')
      .select('id');

    if (conceptosError) {
      throw new Error(`Error al obtener conceptos_tesoreria: ${conceptosError.message}`);
    }

    const validConceptosSet = new Set(validConceptos.map(c => c.id));
    console.log(`✅ Conceptos válidos: ${validConceptosSet.size}`);

    // Preparar datos para Supabase
    let insertadosValores = 0;
    let omitidosValores = 0;
    const batchSizeValores = 100;

    for (let i = 0; i < valores.length; i += batchSizeValores) {
      const batch = valores.slice(i, i + batchSizeValores);
      const dataToInsert = [];

      for (const row of batch) {
        // Validar FK de concepto_tesoreria
        if (row.idConcepto_Tesoreria && !validConceptosSet.has(row.idConcepto_Tesoreria)) {
          console.log(`⚠️  Omitiendo valor ${row.idTransaccion}: concepto_tesoreria ${row.idConcepto_Tesoreria} no existe`);
          omitidosValores++;
          continue;
        }

        // Convertir locked de Buffer a boolean
        let lockedValue = false;
        if (row.locked) {
          if (Buffer.isBuffer(row.locked)) {
            // Si es un Buffer, verificar si tiene algún byte distinto de 0
            lockedValue = Array.from(row.locked).some(byte => byte !== 0);
          } else {
            lockedValue = Boolean(row.locked);
          }
        }

        dataToInsert.push({
          id: row.idTransaccion,
          idtransaccion_origen: row.idTransaccionOrigen || null,
          tipo_movimiento: row.TipoMovimiento || null,
          idconcepto_tesoreria: row.idConcepto_Tesoreria || null,
          fecha_emision: row.FechaEmision || null,
          vencimiento: row.Vencimiento || null,
          banco: row.Banco || null,
          cuenta: row.Cuenta || null,
          sucursal: row.Sucursal || null,
          numero: row.Numero || null,
          numero_interno: row.NumeroInterno || null,
          firma: row.Firma || null,
          importe: row.importe || 0,
          cancelado: row.Cancelado || 0,
          idoperador: row.idOperador || null,
          observaciones: row.Observaciones || null,
          locked: lockedValue,
          cobrador: row.cobrador || null,
          // idop_cobrador omitido - no se migra
          corregido: row.Corregido || null,
          tipocambio: row.tipocambio || null,
          base: row.base || null,
        });
      }

      if (dataToInsert.length > 0) {
        // Insertar en Supabase con UPSERT
        const { data, error } = await supabase
          .from('valores_tesoreria')
          .upsert(dataToInsert, { onConflict: 'id' });

        if (error) {
          console.error(`❌ Error insertando batch ${i / batchSizeValores + 1}:`, error);
          // Log primer registro del batch para debug
          if (dataToInsert.length > 0) {
            console.log('Primer registro del batch con error:', JSON.stringify(dataToInsert[0], null, 2));
          }
          omitidosValores += dataToInsert.length;
        } else {
          insertadosValores += dataToInsert.length;
          console.log(`✅ Insertados ${insertadosValores} de ${valores.length} valores...`);
        }
      }
    }

    console.log(`\n✅ Migración de ValoresTesoreria completada:`);
    console.log(`   - Insertados: ${insertadosValores}`);
    console.log(`   - Omitidos: ${omitidosValores}`);

    console.log(`\n🎉 MIGRACIÓN TOTAL COMPLETADA:`);
    console.log(`   - Conceptos Tesorería: ${insertados} insertados, ${omitidos} omitidos`);
    console.log(`   - Valores Tesorería: ${insertadosValores} insertados, ${omitidosValores} omitidos`);

    // Resetear la secuencia de valores_tesoreria para que el próximo ID sea MAX(id) + 1
    console.log('\n🔄 Reseteando secuencia de valores_tesoreria...');
    const { error: seqError } = await supabase.rpc('reset_sequence', {
      p_table_name: 'valores_tesoreria',
      p_column_name: 'id'
    });

    if (seqError) {
      // Si la función RPC no existe, intentar con SQL directo
      console.log('⚠️ Función RPC no disponible, ejecutar manualmente:');
      console.log("   SELECT setval('valores_tesoreria_id_seq', COALESCE((SELECT MAX(id) FROM valores_tesoreria), 0) + 1, false);");
    } else {
      console.log('✅ Secuencia reseteada correctamente');
    }

  } catch (error) {
    console.error('❌ Error:', error);
    throw error;
  } finally {
    if (pool) {
      await pool.close();
      console.log('🔌 Conexión a SQL Server cerrada');
    }
  }
}

// Ejecutar migración
migrateValoresTesoreria()
  .then(() => {
    console.log('\n✅ Proceso completado');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Error en la migración:', error);
    process.exit(1);
  });
