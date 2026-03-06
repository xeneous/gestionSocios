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
    console.log('  Migrar clientes FALTANTES');
    console.log('  SQL Server → Supabase (upsert)');
    console.log('========================================\n');

    try {
        console.log('🔌 Conectando a SQL Server...');
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado\n');

        // 1. Leer todos los clientes de SQL Server
        console.log('📋 Leyendo clientes de SQL Server...');
        const result = await pool.request().query(`
            SELECT Codigo, RazonSocial, Domicilio, Localidad, CodigoPostal, idProvincia,
                   Tipo1, Telefono1, Tipo2, Telefono2, Tipo3, Telefono3,
                   tipo4, telefono4, Tipo5, telefono5, tipo6, telefono6,
                   mail, Notas, Fecha, Vendedor, Hora, idClienteant,
                   Nombre, Apellido, TipoCuenta, Categoria, Cuit, civa,
                   Cuenta, CuentaSubdiario, FechaNac, Activo, codigoexterno,
                   vencimiento, horaAtencion, Alerta, cventa, tablaganancia,
                   idZona, Fechabaja, tipodocto, numerodocto, Descuento,
                   TipoCuentaComis, ibrutos, percepcionIB, retencionIB,
                   idPais, Jurisdiccion, Adicional
            FROM Clientes
            ORDER BY Codigo
        `);
        console.log(`   Total en SQL Server: ${result.recordset.length} clientes`);

        // 2. Leer los codigos que ya existen en Supabase
        console.log('\n📋 Leyendo códigos existentes en Supabase...');
        const { data: existentes, error: errExistentes } = await supabase
            .from('clientes')
            .select('codigo');

        if (errExistentes) {
            throw new Error('Error leyendo Supabase: ' + errExistentes.message);
        }

        const codigosExistentes = new Set(existentes.map(c => c.codigo));
        console.log(`   Total en Supabase:    ${codigosExistentes.size} clientes`);

        // 3. Filtrar los faltantes
        const faltantes = result.recordset.filter(c => !codigosExistentes.has(c.Codigo));
        console.log(`\n⚠️  Clientes faltantes: ${faltantes.length}`);

        if (faltantes.length === 0) {
            console.log('\n✅ No hay clientes faltantes. Todo está migrado.');
            await pool.close();
            return;
        }

        // Mostrar los primeros 20 faltantes para referencia
        console.log('\nPrimeros faltantes:');
        faltantes.slice(0, 20).forEach(c =>
            console.log(`   [${c.Codigo}] ${c.RazonSocial?.trim()}`)
        );
        if (faltantes.length > 20) {
            console.log(`   ... y ${faltantes.length - 20} más`);
        }

        // 4. Insertar los faltantes en lotes
        console.log('\n📤 Insertando clientes faltantes...\n');
        const batchSize = 50;
        let migrated = 0;
        let errores = 0;

        for (let i = 0; i < faltantes.length; i += batchSize) {
            const batch = faltantes.slice(i, i + batchSize);

            const toInsert = batch.map(c => ({
                codigo: c.Codigo,
                razon_social: c.RazonSocial?.trim() ?? null,
                domicilio: c.Domicilio?.trim() ?? null,
                localidad: c.Localidad?.trim() ?? null,
                codigo_postal: c.CodigoPostal?.trim() ?? null,
                id_provincia: c.idProvincia ?? null,
                tipo1: c.Tipo1 ?? null,
                telefono1: c.Telefono1?.trim() ?? null,
                tipo2: c.Tipo2 ?? null,
                telefono2: c.Telefono2?.trim() ?? null,
                tipo3: c.Tipo3 ?? null,
                telefono3: c.Telefono3?.trim() ?? null,
                tipo4: c.tipo4 ?? null,
                telefono4: c.telefono4?.trim() ?? null,
                tipo5: c.Tipo5 ?? null,
                telefono5: c.telefono5?.trim() ?? null,
                tipo6: c.tipo6 ?? null,
                telefono6: c.telefono6?.trim() ?? null,
                mail: c.mail?.trim() ?? null,
                notas: c.Notas ?? null,
                fecha: c.Fecha ?? null,
                vendedor: c.Vendedor ?? null,
                hora: c.Hora ?? null,
                id_cliente_ant: c.idClienteant ?? null,
                nombre: c.Nombre?.trim() ?? null,
                apellido: c.Apellido?.trim() ?? null,
                tipo_cuenta: c.TipoCuenta ?? null,
                categoria: c.Categoria ?? null,
                cuit: c.Cuit?.trim() ?? null,
                civa: c.civa ?? null,
                cuenta: c.Cuenta ?? null,
                cuenta_subdiario: c.CuentaSubdiario ?? null,
                fecha_nac: c.FechaNac ?? null,
                activo: 1,
                codigo_externo: c.codigoexterno?.trim() ?? null,
                vencimiento: c.vencimiento ?? null,
                hora_atencion: c.horaAtencion?.trim() ?? null,
                alerta: c.Alerta?.trim() ?? null,
                cventa: c.cventa ?? null,
                tabla_ganancia: c.tablaganancia ?? null,
                id_zona: c.idZona ?? null,
                fecha_baja: c.Fechabaja ?? null,
                tipo_docto: c.tipodocto ?? null,
                numero_docto: c.numerodocto ?? null,
                descuento: c.Descuento ?? null,
                tipo_cuenta_comis: c.TipoCuentaComis ?? null,
                ibrutos: c.ibrutos?.trim() ?? null,
                percepcion_ib: c.percepcionIB ?? null,
                retencion_ib: c.retencionIB ?? null,
                id_pais: c.idPais ?? null,
                jurisdiccion: c.Jurisdiccion ?? null,
                adicional: c.Adicional?.trim() ?? null,
            }));

            const { error } = await supabase
                .from('clientes')
                .insert(toInsert);

            if (error) {
                console.error(`❌ Lote ${Math.floor(i / batchSize) + 1} falló: ${error.message}`);
                // Reintentar de a uno para identificar el registro problemático
                for (const registro of toInsert) {
                    const { error: errUno } = await supabase
                        .from('clientes')
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
                console.log(`   ✅ Lote ${Math.floor(i / batchSize) + 1}: ${toInsert.length} clientes insertados`);
            }
        }

        // 5. Resetear secuencia
        console.log('\n🔄 Reseteando secuencia de clientes...');
        await supabase.rpc('reset_sequence', {
            table_name: 'clientes',
            column_name: 'codigo'
        });

        await pool.close();

        console.log('\n========================================');
        console.log(`✅ Migrados: ${migrated} clientes`);
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
