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

// Mapeo de tipo de documento
const tipoDocumentoMap = {
    1: 'DNI',
    2: 'LC',
    3: 'LE',
    4: 'PAS'
};

// Función para migrar socios
async function migrateSocios() {
    console.log('🔄 Iniciando migración de socios...');

    try {
        // PASO 1: Limpiar y migrar tarjetas primero
        console.log('\n📋 PASO 1: Preparando tarjetas...');
        console.log('🧹 Limpiando tabla tarjetas...');
        const { error: deleteTarjetasError } = await supabase
            .from('tarjetas')
            .delete()
            .neq('id', -1); // Delete all

        if (deleteTarjetasError) {
            console.error('❌ Error limpiando tarjetas:', deleteTarjetasError.message);
        } else {
            console.log('✅ Tabla tarjetas limpiada');
        }

        // Conectar a SQL Server para migrar tarjetas
        const pool = await sql.connect(sqlConfig);
        console.log('📖 Migrando tarjetas desde SQL Server...');
        const tarjetasResult = await pool.request().query('SELECT IdTarjeta, Descripcion FROM Tarjetas ORDER BY IdTarjeta');

        if (tarjetasResult.recordset.length > 0) {
            const { error: tarjetasError } = await supabase
                .from('tarjetas')
                .insert(tarjetasResult.recordset.map(t => ({
                    id: t.IdTarjeta,
                    codigo: t.IdTarjeta,
                    descripcion: t.Descripcion?.trim()
                })));

            if (tarjetasError) {
                console.error('❌ Error migrando tarjetas:', tarjetasError.message);
                throw tarjetasError;
            } else {
                console.log(`✅ ${tarjetasResult.recordset.length} tarjetas migradas (incluyendo ID=0)`);
            }
        }

        // PASO 2: Cargar mapeo de provincias (codigo -> id)
        console.log('\n📋 PASO 2: Cargando mapeo de provincias...');
        const { data: provinciasData, error: provError } = await supabase
            .from('provincias')
            .select('id, codigo');

        if (provError) {
            console.error('❌ Error cargando provincias:', provError);
            throw provError;
        }

        const provinciaMap = {};
        provinciasData.forEach(p => {
            provinciaMap[p.codigo] = p.id;
        });
        console.log(`✅ Cargadas ${Object.keys(provinciaMap).length} provincias`);

        // PASO 3: Limpiar tabla socios y migrar
        console.log('\n📋 PASO 3: Migrando socios...');
        console.log('🧹 Limpiando tabla socios...');
        const { error: deleteSociosError } = await supabase
            .from('socios')
            .delete()
            .neq('id', -1); // Delete all

        if (deleteSociosError) {
            console.error('❌ Error limpiando socios:', deleteSociosError.message);
        } else {
            console.log('✅ Tabla socios limpiada');
        }

        console.log('📖 Leyendo socios de SQL Server...');

        // Leer socios de SQL Server
        const result = await pool.request().query(`
      SELECT 
        socio,
        Apellido,
        nombre,
        tipodocto,
        numedocto,
        cuil,
        Nacionalidad,
        Sexo,
        Nacido as fechanac,
        
        -- Datos profesionales
        Grupo,
        gDesde,
        Residente,
        fresidencia,
        nroMatricula,
        Matricula,
        FechaIngreso,
        
        -- Domicilio
        Domicilio,
        localidad,
        provincia,
        cpostal,
        pais,
        telefono,
        Fax,
        
        -- Email
        Email,
        EmailAlt1,
        
        -- Débito automático
        Tarjeta,
        numero,
        Adherido,
        Vencimiento,
        DebitarDesde,
        
        -- Estado
        FechaBaja
        
      FROM socios
      WHERE socio IS NOT NULL
      ORDER BY socio
    `);

        console.log(`📊 Encontrados ${result.recordset.length} socios en SQL Server`);

        // Transformar y migrar en lotes
        const batchSize = 100;
        let migrated = 0;
        let errors = 0;

        for (let i = 0; i < result.recordset.length; i += batchSize) {
            const batch = result.recordset.slice(i, i + batchSize);

            const sociosToInsert = batch.map(row => ({
                // ID original (CRÍTICO: preservar el número de socio)
                id: row.socio,

                // Datos Personales
                apellido: row.Apellido?.trim() || '',
                nombre: row.nombre?.trim() || '',
                tipo_documento: tipoDocumentoMap[row.tipodocto] || 'DNI',
                numero_documento: row.numedocto?.toString(),
                cuil: row.cuil?.trim(),
                nacionalidad_id: row.Nacionalidad,
                sexo: row.Sexo?.toString(),
                fecha_nacimiento: row.fechanac,

                // Datos Profesionales
                grupo: row.Grupo?.trim(),
                grupo_desde: row.gDesde,
                residente: row.Residente === 'S' || row.Residente === '1',
                fecha_fin_residencia: row.fresidencia,
                matricula_nacional: row.nroMatricula?.trim(),
                matricula_provincial: row.Matricula?.trim(),
                fecha_ingreso: row.FechaIngreso,

                // Domicilio
                domicilio: row.Domicilio?.trim(),
                localidad: row.localidad?.trim(),
                provincia_id: row.provincia ? provinciaMap[row.provincia] : null,
                codigo_postal: row.cpostal?.trim(),
                pais_id: row.pais,
                telefono: row.telefono?.trim(),
                telefono_secundario: row.Fax?.trim(),

                // Contacto Email
                email: row.Email?.trim(),
                email_alternativo: row.EmailAlt1?.trim(),

                // Débito Automático
                tarjeta_id: row.Tarjeta || 0, // Map from SQL Server Tarjeta field, 0 if null
                numero_tarjeta: row.numero?.trim(),
                adherido_debito: row.Adherido === 'S' || row.Adherido === '1',
                vencimiento_tarjeta: row.Vencimiento,
                debitar_desde: row.DebitarDesde,

                // Estado
                activo: !row.FechaBaja,
                fecha_baja: row.FechaBaja,
            }));

            // Insertar en Supabase
            const { data, error } = await supabase
                .from('socios')
                .insert(sociosToInsert);

            if (error) {
                console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
                errors += batch.length;
            } else {
                migrated += batch.length;
                console.log(`✅ Migrados ${migrated} de ${result.recordset.length} socios`);
            }
        }

        console.log(`\n📊 Resumen de migración:`);
        console.log(`   ✅ Migrados exitosamente: ${migrated}`);
        console.log(`   ❌ Errores: ${errors}`);
        console.log(`   📦 Total procesados: ${result.recordset.length}`);

        // Resetear la secuencia de IDs para que los próximos inserts usen el número correcto
        console.log('\n🔧 Reseteando secuencia de IDs...');
        await resetSequence('socios');

        await pool.close();

    } catch (err) {
        console.error('💥 Error en migración:', err);
        throw err;
    }
}

// Función para resetear la secuencia de una tabla
async function resetSequence(tableName) {
    try {
        const { data, error } = await supabase.rpc('reset_sequence', {
            table_name: tableName
        });

        if (error) {
            console.error(`❌ Error reseteando secuencia de ${tableName}:`, error);
            // Intentar método alternativo usando query directa
            console.log('⚠️  Intentando método alternativo...');
            const { error: altError } = await supabase.rpc('exec_sql', {
                sql: `SELECT setval(pg_get_serial_sequence('${tableName}', 'id'), COALESCE(MAX(id), 1)) FROM ${tableName};`
            });

            if (altError) {
                console.error('❌ Error en método alternativo:', altError);
                console.log('\n⚠️  IMPORTANTE: Debes ejecutar manualmente en Supabase SQL Editor:');
                console.log(`   SELECT setval(pg_get_serial_sequence('${tableName}', 'id'), COALESCE(MAX(id), 1)) FROM ${tableName};`);
            } else {
                console.log(`✅ Secuencia de ${tableName} reseteada (método alternativo)`);
            }
        } else {
            console.log(`✅ Secuencia de ${tableName} reseteada correctamente`);
        }
    } catch (err) {
        console.error('❌ Error reseteando secuencia:', err.message);
        console.log('\n⚠️  IMPORTANTE: Debes ejecutar manualmente en Supabase SQL Editor:');
        console.log(`   SELECT setval(pg_get_serial_sequence('${tableName}', 'id'), COALESCE(MAX(id), 1)) FROM ${tableName};`);
    }
}

// Función para migrar tablas de referencia
async function migrateReferenciaTables() {
    console.log('🔄 Iniciando migración de tablas de referencia...');

    try {
        const pool = await sql.connect(sqlConfig);

        // Migrar provincias
        console.log('\n📋 Migrando provincias...');
        const provincias = await pool.request().query('SELECT provincia, Descripcion FROM Provincias');
        if (provincias.recordset.length > 0) {
            const { error } = await supabase
                .from('provincias')
                .insert(provincias.recordset.map(p => ({
                    codigo: p.provincia,
                    descripcion: p.Descripcion?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando provincias:', error.message);
            } else {
                console.log(`✅ ${provincias.recordset.length} provincias migradas`);
            }
        }

        // Migrar categorias_iva
        console.log('\n📋 Migrando categorías IVA...');
        const categorias = await pool.request().query('SELECT IdCiva, Descripcion, Ganancias, TipoFacturaCompras, TipoFacturaVentas, Resumido FROM Categorias_Iva');
        if (categorias.recordset.length > 0) {
            const { error } = await supabase
                .from('categorias_iva')
                .insert(categorias.recordset.map(c => ({
                    codigo: c.IdCiva?.toString(),
                    descripcion: c.Descripcion?.trim(),
                    ganancias: c.Ganancias,
                    tipo_factura_compras: c.TipoFacturaCompras?.trim(),
                    tipo_factura_ventas: c.TipoFacturaVentas?.trim(),
                    resumido: c.Resumido?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando categorías IVA:', error.message);
            } else {
                console.log(`✅ ${categorias.recordset.length} categorías IVA migradas`);
            }
        }

        // Migrar grupos_agrupados
        console.log('\n📋 Migrando grupos agrupados...');
        const grupos = await pool.request().query('SELECT Grupo, Descripcion FROM Grupos_Agrupados');
        if (grupos.recordset.length > 0) {
            const { error } = await supabase
                .from('grupos_agrupados')
                .insert(grupos.recordset.map(g => ({
                    codigo: g.Grupo?.trim(),
                    descripcion: g.Descripcion?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando grupos:', error.message);
            } else {
                console.log(`✅ ${grupos.recordset.length} grupos migrados`);
            }
        }

        // Migrar paises
        console.log('\n📋 Migrando países...');
        const paises = await pool.request().query('SELECT idPais, Nombre FROM paises');
        if (paises.recordset.length > 0) {
            const { error } = await supabase
                .from('paises')
                .insert(paises.recordset.map(p => ({
                    id: p.idPais,  // idPais de SQL Server -> id en Supabase
                    nombre: p.Nombre?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando países:', error.message);
            } else {
                console.log(`✅ ${paises.recordset.length} países migrados`);
            }
        }

        // Migrar tarjetas
        console.log('\n📋 Migrando tarjetas...');
        const tarjetas = await pool.request().query('SELECT IdTarjeta, Descripcion FROM Tarjetas ORDER BY IdTarjeta');
        if (tarjetas.recordset.length > 0) {
            const { error } = await supabase
                .from('tarjetas')
                .insert(tarjetas.recordset.map(t => ({
                    id: t.IdTarjeta,              // PRESERVAR EL ID ORIGINAL
                    codigo: t.IdTarjeta,
                    descripcion: t.Descripcion?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando tarjetas:', error.message);
            } else {
                console.log(`✅ ${tarjetas.recordset.length} tarjetas migradas`);
                console.log('   IDs preservados desde MS SQL Server');
            }
        }

        await pool.close();
        console.log('\n✅ Migración de tablas de referencia completada');

    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

// Función para migrar conceptos (maestro)
async function migrateConceptos() {
    console.log('\n📚 Migrando conceptos...');

    try {
        const pool = await sql.connect(sqlConfig);
        const result = await pool.request().query(`
            SELECT 
                Concepto, Entidad, Descripcion, Modalidad, Importe,
                mes, ano, Imputacion_Contable, Seguro, Grupo,
                Concepto_Muni, Modalidad_Muni, Importe_Muni,
                Cobertura, Comision, idCobertura
            FROM conceptos
        `);

        console.log(`✅ Obtenidos ${result.recordset.length} conceptos de SQL Server`);

        // Limpiar tabla
        const { error: deleteError } = await supabase.from('conceptos').delete().neq('id', -1);
        if (deleteError) console.error('❌ Error limpiando conceptos:', deleteError.message);

        // Insertar conceptos
        const conceptosToInsert = result.recordset.map(row => ({
            codigo: row.Concepto?.trim(),
            entidad: row.Entidad,
            descripcion: row.Descripcion?.trim(),
            modalidad: row.Modalidad?.trim(),
            importe: row.Importe,
            mes: row.mes,
            ano: row.ano,
            imputacion_contable: row.Imputacion_Contable,
            seguro: row.Seguro,
            grupo: row.Grupo?.trim(),
            concepto_muni: row.Concepto_Muni?.trim(),
            modalidad_muni: row.Modalidad_Muni?.trim(),
            importe_muni: row.Importe_Muni,
            cobertura: row.Cobertura,
            comision: row.Comision,
            id_cobertura: row.idCobertura
        }));

        const { data, error } = await supabase.from('conceptos').insert(conceptosToInsert).select();
        if (error) throw new Error(`Error insertando conceptos: ${error.message}`);

        console.log(`✅ ${data.length} conceptos migrados`);
        return data;
    } catch (error) {
        console.error('❌ Error en migración de conceptos:', error);
        throw error;
    }
}

// Función para migrar conceptos_socios
async function migrateConceptosSocios() {
    console.log('\n🔗 Migrando conceptos_socios...');

    try {
        const pool = await sql.connect(sqlConfig);
        const result = await pool.request().query(`
            SELECT socio, Concepto, FechaAlta, FecHaVigencia, Importe, FechaBaja,
                   MotivoBaja, Activo, Cuotas, Moneda, idCampoTarjeta,
                   Rechazos, Presentadas, TipoCambio, ValorOrigen
            FROM conceptos_socios
        `);

        console.log(`✅ Obtenidos ${result.recordset.length} conceptos_socios`);

        const { error: deleteError } = await supabase.from('conceptos_socios').delete().neq('id', -1);
        if (deleteError) console.error('❌ Error limpiando:', deleteError.message);

        let migrated = 0;
        const batchSize = 100;

        for (let i = 0; i < result.recordset.length; i += batchSize) {
            const batch = result.recordset.slice(i, i + batchSize).map(row => ({
                socio_id: row.socio,
                concepto_codigo: row.Concepto?.trim(),
                fecha_alta: row.FechaAlta,
                fecha_vigencia: row.FecHaVigencia,
                importe: row.Importe,
                fecha_baja: row.FechaBaja,
                motivo_baja: row.MotivoBaja,
                activo: row.FechaBaja == null,
                cuotas: row.Cuotas,
                moneda: row.Moneda,
                id_campo_tarjeta: row.idCampoTarjeta,
                rechazos: row.Rechazos || 0,
                presentadas: row.Presentadas || 0,
                tipo_cambio: row.TipoCambio,
                valor_origen: row.ValorOrigen
            }));

            const { data, error } = await supabase.from('conceptos_socios').insert(batch).select();
            if (error) {
                console.error(`❌ Error lote ${i / batchSize + 1}:`, error.message);
            } else {
                migrated += data.length;
            }
        }

        console.log(`✅ ${migrated} conceptos_socios migrados`);
    } catch (error) {
        console.error('❌ Error:', error);
        throw error;
    }
}

// Función para migrar observaciones_socios
async function migrateObservacionesSocios() {
    console.log('\n📝 Migrando observaciones_socios...');

    try {
        const pool = await sql.connect(sqlConfig);
        const result = await pool.request().query(`
            SELECT Socio, fecha, observacion
            FROM observaciones_socios
            WHERE Socio IS NOT NULL
            ORDER BY fecha DESC
        `);

        console.log(`✅ Obtenidos ${result.recordset.length} observaciones`);

        const { error: deleteError } = await supabase.from('observaciones_socios').delete().neq('id', -1);
        if (deleteError) console.error('❌ Error limpiando:', deleteError.message);

        let migrated = 0;
        const batchSize = 100;

        for (let i = 0; i < result.recordset.length; i += batchSize) {
            const batch = result.recordset.slice(i, i + batchSize).map(row => ({
                socio_id: row.Socio,
                fecha: row.fecha || new Date(),
                observacion: row.observacion?.trim() || '',
                usuario: 'Migración'
            }));

            const { data, error } = await supabase.from('observaciones_socios').insert(batch).select();
            if (error) {
                console.error(`❌ Error lote ${i / batchSize + 1}:`, error.message);
            } else {
                migrated += data.length;
            }
        }

        console.log(`✅ ${migrated} observaciones migradas`);
    } catch (error) {
        console.error('❌ Error:', error);
        throw error;
    }
}

// Menú principal
async function main() {
    console.log('========================================');
    console.log('  Migración SQL Server → Supabase');
    console.log('========================================\n');

    const args = process.argv.slice(2);
    const command = args[0];

    try {
        switch (command) {
            case 'referencias':
                await migrateReferenciaTables();
                break;
            case 'socios':
                await migrateSocios();
                break;
            case 'conceptos':
                await migrateConceptos();
                await migrateConceptosSocios();
                await migrateObservacionesSocios();
                break;
            case 'all':
                await migrateReferenciaTables();
                await migrateSocios();
                await migrateConceptos();
                await migrateConceptosSocios();
                await migrateObservacionesSocios();
                break;
            default:
                console.log('Uso:');
                console.log('  node migrate.js referencias  - Migrar tablas de referencia');
                console.log('  node migrate.js socios      - Migrar solo socios');
                console.log('  node migrate.js conceptos   - Migrar conceptos y observaciones');
                console.log('  node migrate.js all         - Migrar todo');
        }

        console.log('\n✅ Migración completada exitosamente');
        process.exit(0);

    } catch (error) {
        console.error('\n💥 Error fatal:', error);
        process.exit(1);
    }
}

main();
