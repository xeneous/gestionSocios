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

async function migrateSociosOnly() {
    console.log('========================================');
    console.log('  Migración de Socios Únicamente');
    console.log('========================================\n');

    try {
        // 1. Conectar a SQL Server
        console.log('🔌 Conectando a SQL Server...');
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado a SQL Server\n');

        // 2. Limpiar tabla socios en Supabase
        console.log('🧹 Limpiando tabla socios en Supabase...');
        const { error: deleteError } = await supabase
            .from('socios')
            .delete()
            .neq('id', 0);

        if (deleteError) {
            console.error('❌ Error limpiando socios:', deleteError.message);
        } else {
            console.log('✅ Tabla socios limpiada\n');
        }

        // 3. Cargar mapeos de tablas de referencia de Supabase
        console.log('📋 Cargando mapeos de tablas de referencia...');

        // Mapeo provincias (codigo -> id)
        const { data: provinciasData } = await supabase
            .from('provincias')
            .select('codigo, id');
        const provinciaMap = {};
        provinciasData?.forEach(p => {
            provinciaMap[p.codigo] = p.id;
        });
        console.log(`   ✅ ${Object.keys(provinciaMap).length} provincias`);

        // Mapeo paises (idPais -> id)
        const { data: paisesData } = await supabase
            .from('paises')
            .select('idPais, id');
        const paisMap = {};
        paisesData?.forEach(p => {
            paisMap[p.idPais] = p.id;
        });
        console.log(`   ✅ ${Object.keys(paisMap).length} países\n`);

        // 4. Leer socios de SQL Server
        console.log('📖 Leyendo socios de SQL Server...');
        const result = await pool.request().query(`
            SELECT
                socio, Apellido, nombre, tipodocto, numedocto, cuil,
                Nacionalidad, Sexo, Nacido as fechanac,
                Grupo, gDesde, Residente, fresidencia, nroMatricula, Matricula,
                FechaIngreso, Domicilio, localidad, provincia, cpostal, pais,
                telefono, Fax, Email, EmailAlt1,
                Tarjeta, numero, Adherido, Vencimiento, DebitarDesde
            FROM socios
        `);

        console.log(`✅ ${result.recordset.length} socios leídos de SQL Server\n`);

        // Debug: mostrar primeros socios con Residente=1
        const residentes = result.recordset.filter(s => s.Residente === 1 || s.Residente === true || s.Residente === '1');
        console.log(`📊 Socios con Residente=1 en SQL Server: ${residentes.length}`);
        if (residentes.length > 0) {
            console.log(`   Ejemplo: socio ${residentes[0].socio}, Residente=${residentes[0].Residente} (tipo: ${typeof residentes[0].Residente})`);
        }
        console.log('');

        // 5. Migrar socios en lotes
        console.log('💾 Migrando socios a Supabase...\n');
        const batchSize = 100;
        let migrated = 0;
        let errors = 0;

        for (let i = 0; i < result.recordset.length; i += batchSize) {
            const batch = result.recordset.slice(i, i + batchSize);

            const sociosToInsert = batch.map(s => ({
                id: s.socio,
                apellido: s.Apellido?.trim() || '',
                nombre: s.nombre?.trim() || '',
                tipo_documento: tipoDocumentoMap[s.tipodocto] || 'DNI',
                numero_documento: s.numedocto?.toString().trim(),
                cuil: s.cuil?.trim(),
                sexo: s.Sexo ? (sexoMap[typeof s.Sexo === 'string' ? s.Sexo.trim() : s.Sexo] || 0) : 0,
                fecha_nacimiento: s.fechanac,
                grupo: s.Grupo?.trim(),
                grupo_desde: s.gDesde,
                residente: s.Residente === 1 || s.Residente === true || s.Residente === '1' || (s.Residente && s.Residente !== 0 && s.Residente !== '0'),
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
                debitar_desde: s.DebitarDesde
            }));

            const { error } = await supabase
                .from('socios')
                .insert(sociosToInsert);

            if (error) {
                console.error(`   ❌ Error en lote ${i / batchSize + 1}:`, error.message);
                errors++;
            } else {
                migrated += sociosToInsert.length;
                console.log(`   ✅ Lote ${i / batchSize + 1}: ${sociosToInsert.length} socios migrados`);
            }
        }

        await pool.close();

        console.log('\n========================================');
        console.log(`✅ MIGRACIÓN COMPLETADA`);
        console.log(`   Total migrados: ${migrated} socios`);
        if (errors > 0) {
            console.log(`   ⚠️  Lotes con errores: ${errors}`);
        }
        console.log('========================================\n');

        process.exit(0);

    } catch (error) {
        console.error('\n💥 ERROR FATAL:', error);
        process.exit(1);
    }
}

migrateSociosOnly();
