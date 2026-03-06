import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';
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

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function main() {
    console.log('========================================');
    console.log('  Migrar proveedores FALTANTES');
    console.log('  SQL Server → Supabase (upsert)');
    console.log('========================================\n');

    try {
        console.log('🔌 Conectando a SQL Server...');
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado\n');

        // 1. Leer todos los proveedores de SQL Server
        console.log('📋 Leyendo proveedores de SQL Server...');
        const result = await pool.request().query(`
            SELECT Codigo, RazonSocial, Domicilio, Localidad, CodigoPostal, idProvincia,
                   Cuenta, Tipo1, Telefono1, Tipo2, Telefono2, Tipo3, Telefono3,
                   tipo4, telefono4, Tipo5, telefono5, tipo6, telefono6,
                   mail, Notas, Fecha, Vendedor, Hora, idClienteant,
                   Nombre, Apellido, TipoCuenta, Categoria, Cuit, civa,
                   CuentaSubdiario, FechaNac, Activo, codigoexterno,
                   vencimiento, horaAtencion, Alerta, cventa, idZona,
                   fechabaja, TablaGanancia, tipodocto, numerodocto, descuento,
                   ibrutos, percepcionIB, retencionIB, idPais, Jurisdiccion, Adicional
            FROM Proveedores
            ORDER BY Codigo
        `);
        console.log(`   Total en SQL Server: ${result.recordset.length} proveedores`);

        // 2. Leer los codigos que ya existen en Supabase
        console.log('\n📋 Leyendo códigos existentes en Supabase...');
        const { data: existentes, error: errExistentes } = await supabase
            .from('proveedores')
            .select('codigo');

        if (errExistentes) {
            throw new Error('Error leyendo Supabase: ' + errExistentes.message);
        }

        const codigosExistentes = new Set(existentes.map(p => p.codigo));
        console.log(`   Total en Supabase:    ${codigosExistentes.size} proveedores`);

        // 3. Filtrar los faltantes
        const faltantes = result.recordset.filter(p => !codigosExistentes.has(p.Codigo));
        console.log(`\n⚠️  Proveedores faltantes: ${faltantes.length}`);

        if (faltantes.length === 0) {
            console.log('\n✅ No hay proveedores faltantes. Todo está migrado.');
            await pool.close();
            return;
        }

        // Mostrar los primeros 20 faltantes para referencia
        console.log('\nPrimeros faltantes:');
        faltantes.slice(0, 20).forEach(p =>
            console.log(`   [${p.Codigo}] ${p.RazonSocial?.trim()}`)
        );
        if (faltantes.length > 20) {
            console.log(`   ... y ${faltantes.length - 20} más`);
        }

        // 4. Insertar los faltantes en lotes
        console.log('\n📤 Insertando proveedores faltantes...\n');
        const batchSize = 50;
        let migrated = 0;
        let errores = 0;

        for (let i = 0; i < faltantes.length; i += batchSize) {
            const batch = faltantes.slice(i, i + batchSize);

            const toInsert = batch.map(p => ({
                codigo: p.Codigo,
                razon_social: p.RazonSocial?.trim() ?? null,
                domicilio: p.Domicilio?.trim() ?? null,
                localidad: p.Localidad?.trim() ?? null,
                codigo_postal: p.CodigoPostal?.trim() ?? null,
                id_provincia: p.idProvincia ?? null,
                cuenta: p.Cuenta ?? null,
                tipo1: p.Tipo1 ?? null,
                telefono1: p.Telefono1?.trim() ?? null,
                tipo2: p.Tipo2 ?? null,
                telefono2: p.Telefono2?.trim() ?? null,
                tipo3: p.Tipo3 ?? null,
                telefono3: p.Telefono3?.trim() ?? null,
                tipo4: p.tipo4 ?? null,
                telefono4: p.telefono4?.trim() ?? null,
                tipo5: p.Tipo5 ?? null,
                telefono5: p.telefono5?.trim() ?? null,
                tipo6: p.tipo6 ?? null,
                telefono6: p.telefono6?.trim() ?? null,
                mail: p.mail?.trim() ?? null,
                notas: p.Notas ?? null,
                fecha: p.Fecha ?? null,
                vendedor: p.Vendedor ?? null,
                hora: p.Hora ?? null,
                id_cliente_ant: p.idClienteant ?? null,
                nombre: p.Nombre?.trim() ?? null,
                apellido: p.Apellido?.trim() ?? null,
                tipo_cuenta: p.TipoCuenta ?? null,
                categoria: p.Categoria ?? null,
                cuit: p.Cuit?.trim() ?? null,
                civa: p.civa ?? null,
                cuenta_subdiario: p.CuentaSubdiario ?? null,
                fecha_nac: p.FechaNac ?? null,
                activo: 1,
                codigo_externo: p.codigoexterno?.trim() ?? null,
                vencimiento: p.vencimiento ?? null,
                hora_atencion: p.horaAtencion?.trim() ?? null,
                alerta: p.Alerta?.trim() ?? null,
                cventa: p.cventa ?? null,
                id_zona: p.idZona ?? null,
                fecha_baja: p.fechabaja ?? null,
                tabla_ganancia: p.TablaGanancia ?? null,
                tipo_docto: p.tipodocto ?? null,
                numero_docto: p.numerodocto ?? null,
                descuento: p.descuento ?? null,
                ibrutos: p.ibrutos?.trim() ?? null,
                percepcion_ib: p.percepcionIB ?? null,
                retencion_ib: p.retencionIB ?? null,
                id_pais: p.idPais ?? null,
                jurisdiccion: p.Jurisdiccion ?? null,
                adicional: p.Adicional?.trim() ?? null,
            }));

            const { error } = await supabase
                .from('proveedores')
                .insert(toInsert);

            if (error) {
                console.error(`❌ Lote ${Math.floor(i / batchSize) + 1} falló: ${error.message}`);
                // Intentar de a uno para identificar el registro problemático
                for (const registro of toInsert) {
                    const { error: errUno } = await supabase
                        .from('proveedores')
                        .insert(registro);
                    if (errUno) {
                        console.error(`   ⚠️  Código ${registro.codigo} (${registro.razon_social}): ${errUno.message}`);
                        errores++;
                    } else {
                        migrated++;
                    }
                }
            } else {
                migrated += toInsert.length;
                console.log(`   ✅ Lote ${Math.floor(i / batchSize) + 1}: ${toInsert.length} proveedores insertados`);
            }
        }

        // 5. Resetear secuencia
        console.log('\n🔄 Reseteando secuencia de proveedores...');
        await supabase.rpc('reset_sequence', {
            table_name: 'proveedores',
            column_name: 'codigo'
        });

        await pool.close();

        console.log('\n========================================');
        console.log(`✅ Migrados: ${migrated} proveedores`);
        if (errores > 0) {
            console.log(`⚠️  Errores:  ${errores} registros con problemas (ver arriba)`);
        }
        console.log('========================================\n');

        process.exit(0);

    } catch (error) {
        console.error('\n💥 ERROR FATAL:', error);
        process.exit(1);
    }
}

main();
