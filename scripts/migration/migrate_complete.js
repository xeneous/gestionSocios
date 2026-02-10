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

// Mapeo de sexo string a int
const sexoMap = {
    'M': 1,
    'F': 2
};

//============================================
// PASO 1: LIMPIAR SUPABASE
//============================================
async function cleanSupabase() {
    console.log('🧹 Limpiando datos en Supabase...\n');

    try {
        // 1) Tablas que usan idtransaccion (no tienen columna id)
        const tablasTransaccion = [
            'operaciones_detalle_cuentas_corrientes',
            'detalle_cuentas_corrientes',
            'cuentas_corrientes',
        ];

        for (const table of tablasTransaccion) {
            console.log(`   Limpiando tabla ${table}...`);
            const { error } = await supabase
                .from(table)
                .delete()
                .gte('idtransaccion', 0);

            if (error) {
                console.error(`   ❌ Error limpiando ${table}:`, error.message);
            } else {
                console.log(`   ✅ ${table} limpiada`);
            }
        }

        // 2) Tablas con columna id (orden: socios primero, luego sus referencias)
        const tablasConId = ['socios', 'tarjetas', 'grupos_agrupados', 'paises', 'provincias', 'sexos'];

        for (const table of tablasConId) {
            console.log(`   Limpiando tabla ${table}...`);
            const { error } = await supabase
                .from(table)
                .delete()
                .neq('id', 0);

            if (error) {
                console.error(`   ❌ Error limpiando ${table}:`, error.message);
            } else {
                console.log(`   ✅ ${table} limpiada`);
            }
        }

        // 3) categorias_iva no tiene columna id, usa id_civa
        console.log(`   Limpiando tabla categorias_iva...`);
        const { error: errorCiva } = await supabase
            .from('categorias_iva')
            .delete()
            .gte('id_civa', 0);

        if (errorCiva) {
            console.error(`   ❌ Error limpiando categorias_iva:`, errorCiva.message);
        } else {
            console.log(`   ✅ categorias_iva limpiada`);
        }

        console.log('\n✅ Limpieza completada\n');
    } catch (err) {
        console.error('💥 Error limpiando Supabase:', err);
        throw err;
    }
}

//============================================
// PASO 2: MIGRAR SEXOS
//============================================
async function migrateSexos() {
    console.log('📋 Migrando tabla sexos...\n');

    try {
        const sexos = [
            { id: 0, descripcion: 'No informado' },
            { id: 1, descripcion: 'Masculino' },
            { id: 2, descripcion: 'Femenino' }
        ];

        const { error } = await supabase
            .from('sexos')
            .insert(sexos);

        if (error) {
            console.error('❌ Error migrando sexos:', error.message);
        } else {
            console.log(`✅ ${sexos.length} registros de sexos migrados\n`);
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 3: MIGRAR PROVINCIAS
//============================================
async function migrateProvincias(pool) {
    console.log('📋 Migrando provincias...\n');

    try {
        const result = await pool.request().query('SELECT provincia, Descripcion FROM Provincias');

        if (result.recordset.length > 0) {
            const { error } = await supabase
                .from('provincias')
                .insert(result.recordset.map(p => ({
                    codigo: p.provincia,
                    descripcion: p.Descripcion?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando provincias:', error.message);
            } else {
                console.log(`✅ ${result.recordset.length} provincias migradas\n`);
            }
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 4: MIGRAR PAISES
//============================================
async function migratePaises(pool) {
    console.log('📋 Migrando países...\n');

    try {
        const result = await pool.request().query('SELECT idPais, Nombre FROM paises');

        if (result.recordset.length > 0) {
            const { error } = await supabase
                .from('paises')
                .insert(result.recordset.map(p => ({
                    idPais: p.idPais,
                    Nombre: p.Nombre?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando países:', error.message);
            } else {
                console.log(`✅ ${result.recordset.length} países migrados\n`);
            }
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 5: MIGRAR GRUPOS AGRUPADOS
//============================================
async function migrateGrupos(pool) {
    console.log('📋 Migrando grupos agrupados...\n');

    try {
        const result = await pool.request().query('SELECT Grupo, Descripcion FROM Grupos_Agrupados');

        if (result.recordset.length > 0) {
            const { error } = await supabase
                .from('grupos_agrupados')
                .insert(result.recordset.map(g => ({
                    codigo: g.Grupo?.trim(),
                    descripcion: g.Descripcion?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando grupos:', error.message);
            } else {
                console.log(`✅ ${result.recordset.length} grupos migrados\n`);
            }
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 6: MIGRAR CATEGORIAS IVA
//============================================
async function migrateCategoriasIVA(pool) {
    console.log('📋 Migrando categorías IVA...\n');

    try {
        const result = await pool.request().query('SELECT IdCiva, Descripcion FROM Categorias_Iva');

        if (result.recordset.length > 0) {
            const { error } = await supabase
                .from('categorias_iva')
                .insert(result.recordset.map(c => ({
                    codigo: c.IdCiva?.toString(),
                    descripcion: c.Descripcion?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando categorías IVA:', error.message);
            } else {
                console.log(`✅ ${result.recordset.length} categorías IVA migradas\n`);
            }
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 7: MIGRAR TARJETAS
//============================================
async function migrateTarjetas(pool) {
    console.log('📋 Migrando tarjetas...\n');

    try {
        const result = await pool.request().query('SELECT IdTarjeta, Descripcion FROM Tarjetas ORDER BY IdTarjeta');

        if (result.recordset.length > 0) {
            const { error } = await supabase
                .from('tarjetas')
                .insert(result.recordset.map(t => ({
                    id: t.IdTarjeta,
                    codigo: t.IdTarjeta,
                    descripcion: t.Descripcion?.trim()
                })));

            if (error) {
                console.error('❌ Error migrando tarjetas:', error.message);
            } else {
                console.log(`✅ ${result.recordset.length} tarjetas migradas (preservando IDs)\n`);
            }
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 8: MIGRAR SOCIOS
//============================================
async function migrateSocios(pool) {
    console.log('📋 Migrando socios...\n');

    try {
        // 1. Cargar mapeo de provincias
        const { data: provinciasData } = await supabase
            .from('provincias')
            .select('codigo, id');

        const provinciaMap = {};
        provinciasData?.forEach(p => {
            provinciaMap[p.codigo] = p.id;
        });
        console.log(`   Cargado mapeo de ${Object.keys(provinciaMap).length} provincias`);

        // 2. Cargar mapeo de paises
        const { data: paisesData } = await supabase
            .from('paises')
            .select('idPais, id');

        const paisMap = {};
        paisesData?.forEach(p => {
            paisMap[p.idPais] = p.id;
        });
        console.log(`   Cargado mapeo de ${Object.keys(paisMap).length} países`);

        // 3. Leer socios de SQL Server
        const result = await pool.request().query(`
            SELECT 
                socio, Apellido, nombre, tipodocto, numedocto, cuil,
                Nacionalidad, Sexo, Nacido as fechanac,
                Grupo, gDesde, Residente, fresidencia, nroMatricula, Matricula,
                FechaIngreso, Domicilio, localidad, provincia, cpostal, pais,
                telefono, Fax, Email, EmailAlt1,
                Tarjeta, numero, Adherido, Vencimiento, DebitarDesde,
                CategoriaIVA
            FROM socios
        `);

        console.log(`   Leyendo ${result.recordset.length} socios de SQL Server...`);

        // 4. Transformar y migrar socios en lotes
        const batchSize = 100;
        let migrated = 0;

        for (let i = 0; i < result.recordset.length; i += batchSize) {
            const batch = result.recordset.slice(i, i + batchSize);

            const sociosToInsert = batch.map(s => ({
                id: s.socio,
                apellido: s.Apellido?.trim() || '',
                nombre: s.nombre?.trim() || '',
                tipo_documento: tipoDocumentoMap[s.tipodocto] || 'DNI',
                numero_documento: s.numedocto?.toString().trim(),
                cuil: s.cuil?.trim(),
                sexo: s.Sexo ? (sexoMap[s.Sexo.trim()] || 0) : 0,
                fecha_nacimiento: s.fechanac,
                grupo: s.Grupo?.trim(),
                grupo_desde: s.gDesde,
                residente: s.Residente === 1 || s.Residente === true,
                fecha_inicio_residencia: s.fresidencia,
                matricula_nacional: s.nroMatricula?.toString().trim(),
                matricula_provincial: s.Matricula?.toString().trim(),
                fecha_ingreso: s.FechaIngreso,
                domicilio: s.Domicilio?.trim(),
                localidad: s.localidad?.trim(),
                provincia_id: provinciaMap[s.provincia] || null,
                codigo_postal: s.cpostal?.toString().trim(),
                pais_id: paisMap[s.pais] || null,
                telefono: s.telefono?.trim(),
                telefono_secundario: s.Fax?.trim(),
                email: s.Email?.trim(),
                email_alternativo: s.EmailAlt1?.trim(),
                adherido_debito: s.Adherido === 1 || s.Adherido === true,
                tarjeta_id: s.Tarjeta || 0,
                numero_tarjeta: s.numero?.toString().trim(),
                vencimiento_tarjeta: s.Vencimiento,
                debitar_desde: s.DebitarDesde,
                categoria_iva: s.CategoriaIVA?.trim()
            }));

            const { error } = await supabase
                .from('socios')
                .insert(sociosToInsert);

            if (error) {
                console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
            } else {
                migrated += sociosToInsert.length;
                console.log(`   ✅ Lote ${i / batchSize + 1}: ${sociosToInsert.length} socios`);
            }
        }

        console.log(`\n✅ Total migrados: ${migrated} socios\n`);

    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// MAIN: EJECUTAR MIGRACIÓN COMPLETA
//============================================
async function main() {
    console.log('========================================');
    console.log('  Migración Completa SQL Server → Supabase');
    console.log('========================================\n');

    try {
        // Conectar a SQL Server
        console.log('🔌 Conectando a SQL Server...');
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado a SQL Server\n');

        // Ejecutar migración en orden
        await cleanSupabase();
        await migrateSexos();
        await migrateProvincias(pool);
        await migratePaises(pool);
        await migrateGrupos(pool);
        await migrateCategoriasIVA(pool);
        await migrateTarjetas(pool);
        await migrateSocios(pool);

        await pool.close();

        console.log('========================================');
        console.log('✅ MIGRACIÓN COMPLETADA EXITOSAMENTE');
        console.log('========================================\n');

        process.exit(0);

    } catch (error) {
        console.error('\n💥 ERROR FATAL:', error);
        process.exit(1);
    }
}

main();
