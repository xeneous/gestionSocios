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

async function migrateCuentasCorrientes() {
  let pool;

  try {
    console.log('🔄 Conectando a SQL Server...');
    pool = await sql.connect(sqlConfig);

    // ============================================================================
    // MIGRAR HEADERS DE CUENTAS CORRIENTES
    // ============================================================================
    console.log('\n📋 Migrando headers de cuentas corrientes...');

    const headersResult = await pool.request().query(`
      SELECT
        IdTransaccion,
        socio,
        Entidad,
        Fecha,
        RTRIM(LTRIM(Concepto)) as Concepto,
        PuntodeVenta,
        DocumentoNumero,
        FechaRendicion,
        Rendicion,
        importe,
        Cancelado,
        vencimiento
      FROM cuentascorrientes
      WHERE socio < 10000 AND Entidad IN (0, 1)
      ORDER BY IdTransaccion
    `);

    console.log(`✅ Encontrados ${headersResult.recordset.length} headers en SQL Server`);

    // Limpiar tabla en Supabase
    console.log('🗑️  Limpiando tabla cuentas_corrientes en Supabase...');
    const { error: deleteError } = await supabase
      .from('cuentas_corrientes')
      .delete()
      .neq('idtransaccion', 0);

    if (deleteError) {
      console.error('❌ Error limpiando cuentas_corrientes:', deleteError);
    }

    // DEBUGGING: Verificar tipos de comprobante válidos
    console.log('\n🔍 Verificando tipos de comprobante en Supabase...');
    const { data: tiposComprobante, error: tiposError } = await supabase
      .from('tipos_comprobante_socios')
      .select('comprobante')
      .order('comprobante');

    if (tiposError) {
      console.error('❌ Error consultando tipos_comprobante_socios:', tiposError);
    } else {
      console.log('✅ Tipos de comprobante válidos:', tiposComprobante.map(t => `"${t.comprobante}"`).join(', '));
    }

    // DEBUGGING: Verificar tipos de comprobante únicos en SQL Server
    console.log('\n🔍 Verificando tipos de comprobante únicos en SQL Server...');
    const uniqueConceptosResult = await pool.request().query(`
      SELECT DISTINCT RTRIM(LTRIM(Concepto)) as Concepto
      FROM cuentascorrientes
      WHERE socio < 10000 AND Entidad IN (0, 1)
      ORDER BY Concepto
    `);
    console.log('✅ Tipos de comprobante en SQL Server:', uniqueConceptosResult.recordset.map(r => `"${r.Concepto}"`).join(', '));

    // Encontrar comprobantes que no existen en Supabase
    const validComprobantes = new Set(tiposComprobante.map(t => t.comprobante));
    const invalidComprobantes = uniqueConceptosResult.recordset
      .filter(r => !validComprobantes.has(r.Concepto))
      .map(r => r.Concepto);

    if (invalidComprobantes.length > 0) {
      console.warn('⚠️  ADVERTENCIA: Los siguientes comprobantes NO existen en Supabase:', invalidComprobantes.map(c => `"${c}"`).join(', '));
    }

    // Obtener todos los socios e IDs válidos desde Supabase (sin límite)
    console.log('\n🔍 Obteniendo socios válidos desde Supabase...');

    let allSocios = [];
    let from = 0;
    const pageSize = 1000;

    while (true) {
      const { data: sociosData, error: sociosError } = await supabase
        .from('socios')
        .select('id')
        .range(from, from + pageSize - 1);

      if (sociosError) {
        console.error('❌ Error consultando socios:', sociosError);
        throw sociosError;
      }

      if (!sociosData || sociosData.length === 0) break;

      allSocios = allSocios.concat(sociosData);

      if (sociosData.length < pageSize) break;
      from += pageSize;
    }

    const validSocioIds = new Set(allSocios.map(s => s.id));
    console.log(`✅ Encontrados ${validSocioIds.size} socios válidos en Supabase`);

    // Obtener todos los profesionales válidos desde Supabase (sin límite)
    console.log('🔍 Obteniendo profesionales válidos desde Supabase...');

    let allProfesionales = [];
    from = 0;

    while (true) {
      const { data: profesionalesData, error: profesionalesError } = await supabase
        .from('profesionales')
        .select('id')
        .range(from, from + pageSize - 1);

      if (profesionalesError) {
        console.error('❌ Error consultando profesionales:', profesionalesError);
        throw profesionalesError;
      }

      if (!profesionalesData || profesionalesData.length === 0) break;

      allProfesionales = allProfesionales.concat(profesionalesData);

      if (profesionalesData.length < pageSize) break;
      from += pageSize;
    }

    const validProfesionalIds = new Set(allProfesionales.map(p => p.id));
    console.log(`✅ Encontrados ${validProfesionalIds.size} profesionales válidos en Supabase`);

    // Insertar en lotes
    const BATCH_SIZE = 1000;
    let insertedHeaders = 0;
    let skippedHeaders = 0;

    for (let i = 0; i < headersResult.recordset.length; i += BATCH_SIZE) {
      const batch = headersResult.recordset.slice(i, i + BATCH_SIZE);

      const dataToInsert = batch
        .map(row => {
          // Si Entidad = 0 -> usar socio como socio_id
          // Si Entidad = 1 -> usar socio como profesional_id
          const entidadId = row.Entidad;
          const socioId = entidadId === 0 ? row.socio : null;
          const profesionalId = entidadId === 1 ? row.socio : null;

          // Validar que el socio o profesional exista en Supabase
          if (socioId && !validSocioIds.has(socioId)) {
            skippedHeaders++;
            return null;  // Skip este registro
          }
          if (profesionalId && !validProfesionalIds.has(profesionalId)) {
            skippedHeaders++;
            return null;  // Skip este registro
          }

          // Normalizar tipo_comprobante: algunos tienen espacio final en Supabase
          let tipoComprobante = row.Concepto || null;
          if (tipoComprobante && !validComprobantes.has(tipoComprobante)) {
            // Intentar con espacio al final
            const withSpace = tipoComprobante + ' ';
            if (validComprobantes.has(withSpace)) {
              tipoComprobante = withSpace;
            }
          }

          return {
            idtransaccion: row.IdTransaccion,
            socio_id: socioId,
            profesional_id: profesionalId,
            entidad_id: entidadId,
            fecha: row.Fecha?.toISOString().split('T')[0] || null,
            tipo_comprobante: tipoComprobante,
            punto_venta: row.PuntodeVenta?.toString().trim() || null,
            documento_numero: row.DocumentoNumero?.toString().trim() || null,
            fecha_rendicion: row.FechaRendicion?.toISOString().split('T')[0] || null,
            rendicion: row.Rendicion?.toString().trim() || null,
            importe: row.importe || 0,
            cancelado: row.Cancelado || 0,
            vencimiento: row.vencimiento?.toISOString().split('T')[0] || null,
          };
        })
        .filter(row => row !== null);  // Eliminar registros skipped

      const { error: insertError } = await supabase
        .from('cuentas_corrientes')
        .insert(dataToInsert);

      if (insertError) {
        console.error(`❌ Error insertando lote ${i / BATCH_SIZE + 1}:`, insertError);
        throw insertError;
      }

      insertedHeaders += dataToInsert.length;
      console.log(`✅ Insertados ${insertedHeaders} / ${headersResult.recordset.length} headers (${skippedHeaders} omitidos)`);
    }

    console.log(`\n✅ Migración de headers completada: ${insertedHeaders} registros insertados, ${skippedHeaders} omitidos`);

    // ============================================================================
    // MIGRAR DETALLE DE CUENTAS CORRIENTES
    // ============================================================================
    console.log('\n📋 Migrando detalle de cuentas corrientes...');

    // Obtener todos los idtransaccion que se insertaron en Supabase (sin límite)
    console.log('🔍 Obteniendo idtransacciones válidos desde Supabase...');

    let allTransacciones = [];
    let fromTx = 0;
    const pageSizeTx = 1000;

    while (true) {
      const { data: transaccionesData, error: transaccionesError } = await supabase
        .from('cuentas_corrientes')
        .select('idtransaccion')
        .range(fromTx, fromTx + pageSizeTx - 1);

      if (transaccionesError) {
        console.error('❌ Error consultando cuentas_corrientes:', transaccionesError);
        throw transaccionesError;
      }

      if (!transaccionesData || transaccionesData.length === 0) break;

      allTransacciones = allTransacciones.concat(transaccionesData);

      if (transaccionesData.length < pageSizeTx) break;
      fromTx += pageSizeTx;
    }

    const validTransaccionIds = new Set(allTransacciones.map(t => t.idtransaccion));
    console.log(`✅ Encontrados ${validTransaccionIds.size} transacciones válidas en Supabase`);

    // Obtener todos los conceptos válidos desde Supabase
    console.log('🔍 Obteniendo conceptos válidos desde Supabase...');
    const { data: conceptosData, error: conceptosError } = await supabase
      .from('conceptos')
      .select('concepto');

    if (conceptosError) {
      console.error('❌ Error consultando conceptos:', conceptosError);
      throw conceptosError;
    }

    const validConceptos = new Set(conceptosData.map(c => c.concepto));
    console.log(`✅ Encontrados ${validConceptos.size} conceptos válidos en Supabase`);

    const itemsResult = await pool.request().query(`
      SELECT
        idTransaccion,
        Item,
        Concepto,
        Cantidad,
        Importe
      FROM detallecuentascorrientes
      ORDER BY idTransaccion, Item
    `);

    console.log(`✅ Encontrados ${itemsResult.recordset.length} items en SQL Server`);

    // Limpiar tabla en Supabase
    console.log('🗑️  Limpiando tabla detalle_cuentas_corrientes en Supabase...');

    // Eliminar todos los registros (usar condición que siempre sea verdadera)
    const { error: deleteItemsError } = await supabase
      .from('detalle_cuentas_corrientes')
      .delete()
      .gte('item', 0);  // Condición que siempre es verdadera para item >= 0

    if (deleteItemsError) {
      console.error('❌ Error limpiando detalle_cuentas_corrientes:', deleteItemsError);
    }

    // Insertar items en lotes
    let insertedItems = 0;
    let skippedItems = 0;

    for (let i = 0; i < itemsResult.recordset.length; i += BATCH_SIZE) {
      const batch = itemsResult.recordset.slice(i, i + BATCH_SIZE);

      const dataToInsert = batch
        .filter(row => {
          // Solo insertar items cuyo idtransaccion exista en cuentas_corrientes
          if (!validTransaccionIds.has(row.idTransaccion)) {
            skippedItems++;
            return false;
          }
          return true;
        })
        .map(row => {
          // Normalizar concepto: algunos conceptos tienen espacio
          let concepto = row.Concepto?.toString().trim() || null;
          if (concepto && !validConceptos.has(concepto)) {
            // Intentar con espacio al final
            const withSpace = concepto + ' ';
            if (validConceptos.has(withSpace)) {
              concepto = withSpace;
            } else {
              // Intentar sin espacio
              const withoutSpace = concepto.trim();
              if (validConceptos.has(withoutSpace)) {
                concepto = withoutSpace;
              }
            }
          }

          return {
            idtransaccion: row.idTransaccion,
            item: row.Item,
            concepto: concepto,
            cantidad: row.Cantidad || 1,
            importe: row.Importe || 0,
          };
        })
        .filter(row => {
          // Validar que el concepto exista
          if (!validConceptos.has(row.concepto)) {
            skippedItems++;
            return false;
          }
          return true;
        });

      if (dataToInsert.length === 0) continue;

      // Eliminar duplicados dentro del mismo lote usando Map
      const uniqueData = Array.from(
        new Map(
          dataToInsert.map(item => [`${item.idtransaccion}-${item.item}`, item])
        ).values()
      );

      const { error: insertError } = await supabase
        .from('detalle_cuentas_corrientes')
        .insert(uniqueData);

      if (insertError) {
        console.error(`❌ Error insertando lote de items ${i / BATCH_SIZE + 1}:`, insertError);
        throw insertError;
      }

      insertedItems += dataToInsert.length;
      console.log(`✅ Insertados ${insertedItems} / ${itemsResult.recordset.length} items (${skippedItems} omitidos)`);
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
migrateCuentasCorrientes()
  .then(() => {
    console.log('\n✅ Script finalizado correctamente');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script finalizado con errores:', error);
    process.exit(1);
  });
