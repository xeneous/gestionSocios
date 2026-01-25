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

//============================================
// PASO 0: LIMPIAR TODAS LAS TABLAS (orden correcto por FK)
//============================================
async function cleanAllTables() {
    console.log('🧹 Limpiando todas las tablas CLIPRO...\n');

    try {
        // Primero las tablas hijas (items)
        console.log('   Eliminando comp_prov_items...');
        await supabase.from('comp_prov_items').delete().neq('id_campo', -999);

        console.log('   Eliminando comp_prov_header...');
        await supabase.from('comp_prov_header').delete().neq('id_transaccion', -999);

        console.log('   Eliminando ven_cli_items...');
        await supabase.from('ven_cli_items').delete().neq('id_campo', -999);

        console.log('   Eliminando ven_cli_header...');
        await supabase.from('ven_cli_header').delete().neq('id_transaccion', -999);

        console.log('   Eliminando tip_comp_mod_items...');
        await supabase.from('tip_comp_mod_items').delete().neq('id', -999);

        console.log('   Eliminando tip_comp_mod_header...');
        await supabase.from('tip_comp_mod_header').delete().neq('codigo', -999);

        console.log('   Eliminando tip_vent_mod_items...');
        await supabase.from('tip_vent_mod_items').delete().neq('id', -999);

        console.log('   Eliminando tip_vent_mod_header...');
        await supabase.from('tip_vent_mod_header').delete().neq('codigo', -999);

        console.log('   Eliminando contactos_proveedores...');
        await supabase.from('contactos_proveedores').delete().neq('id_contacto', -999);

        console.log('   Eliminando contactos_clientes...');
        await supabase.from('contactos_clientes').delete().neq('id_contacto', -999);

        console.log('   Eliminando proveedores...');
        await supabase.from('proveedores').delete().neq('codigo', -999);

        console.log('   Eliminando clientes...');
        await supabase.from('clientes').delete().neq('codigo', -999);

        console.log('   Eliminando categorias_iva...');
        await supabase.from('categorias_iva').delete().neq('id_civa', -999);

        console.log('\n✅ Todas las tablas limpiadas\n');
    } catch (err) {
        console.error('❌ Error limpiando tablas:', err.message);
        throw err;
    }
}

//============================================
// PASO 1: MIGRAR CATEGORIAS IVA (CLIPRO)
//============================================
async function migrateCategoriasIvaCLIPRO(pool) {
    console.log('📋 Migrando categorías IVA (CLIPRO)...\n');

    try {
        const result = await pool.request().query(`
            SELECT IdCiva, Descripcion, Ganancias, TipoFacturaCompras,
                   TipoFacturaVentas, Resumido
            FROM Categorias_Iva
            ORDER BY IdCiva
        `);

        if (result.recordset.length > 0) {
            const { error } = await supabase
                .from('categorias_iva')
                .insert(result.recordset.map(c => ({
                    id_civa: c.IdCiva,
                    descripcion: c.Descripcion?.trim(),
                    ganancias: c.Ganancias,
                    tipo_factura_compras: c.TipoFacturaCompras?.trim(),
                    tipo_factura_ventas: c.TipoFacturaVentas?.trim(),
                    resumido: c.Resumido?.trim()
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
// PASO 2: MIGRAR CLIENTES (SPONSORS)
//============================================
async function migrateClientes(pool) {
    console.log('📋 Migrando clientes (sponsors)...\n');

    try {
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

        console.log(`   Leyendo ${result.recordset.length} clientes de SQL Server...`);

        if (result.recordset.length > 0) {
            const batchSize = 100;
            let migrated = 0;

            for (let i = 0; i < result.recordset.length; i += batchSize) {
                const batch = result.recordset.slice(i, i + batchSize);

                const clientesToInsert = batch.map(c => ({
                    codigo: c.Codigo,
                    razon_social: c.RazonSocial?.trim(),
                    domicilio: c.Domicilio?.trim(),
                    localidad: c.Localidad?.trim(),
                    codigo_postal: c.CodigoPostal?.trim(),
                    id_provincia: c.idProvincia,
                    tipo1: c.Tipo1,
                    telefono1: c.Telefono1?.trim(),
                    tipo2: c.Tipo2,
                    telefono2: c.Telefono2?.trim(),
                    tipo3: c.Tipo3,
                    telefono3: c.Telefono3?.trim(),
                    tipo4: c.tipo4,
                    telefono4: c.telefono4?.trim(),
                    tipo5: c.Tipo5,
                    telefono5: c.telefono5?.trim(),
                    tipo6: c.tipo6,
                    telefono6: c.telefono6?.trim(),
                    mail: c.mail?.trim(),
                    notas: c.Notas,
                    fecha: c.Fecha,
                    vendedor: c.Vendedor,
                    hora: c.Hora,
                    id_cliente_ant: c.idClienteant,
                    nombre: c.Nombre?.trim(),
                    apellido: c.Apellido?.trim(),
                    tipo_cuenta: c.TipoCuenta,
                    categoria: c.Categoria,
                    cuit: c.Cuit?.trim(),
                    civa: c.civa,
                    cuenta: c.Cuenta,
                    cuenta_subdiario: c.CuentaSubdiario,
                    fecha_nac: c.FechaNac,
                    activo: c.Activo,
                    codigo_externo: c.codigoexterno?.trim(),
                    vencimiento: c.vencimiento,
                    hora_atencion: c.horaAtencion?.trim(),
                    alerta: c.Alerta?.trim(),
                    cventa: c.cventa,
                    tabla_ganancia: c.tablaganancia,
                    id_zona: c.idZona,
                    fecha_baja: c.Fechabaja,
                    tipo_docto: c.tipodocto,
                    numero_docto: c.numerodocto,
                    descuento: c.Descuento,
                    tipo_cuenta_comis: c.TipoCuentaComis,
                    ibrutos: c.ibrutos?.trim(),
                    percepcion_ib: c.percepcionIB,
                    retencion_ib: c.retencionIB,
                    id_pais: c.idPais,
                    jurisdiccion: c.Jurisdiccion,
                    adicional: c.Adicional?.trim()
                }));

                const { error } = await supabase
                    .from('clientes')
                    .insert(clientesToInsert);

                if (error) {
                    console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
                } else {
                    migrated += clientesToInsert.length;
                    console.log(`   ✅ Lote ${i / batchSize + 1}: ${clientesToInsert.length} clientes`);
                }
            }

            console.log(`\n✅ Total migrados: ${migrated} clientes\n`);
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 3: MIGRAR CONTACTOS CLIENTES
//============================================
async function migrateContactosClientes(pool) {
    console.log('📋 Migrando contactos de clientes...\n');

    try {
        const result = await pool.request().query(`
            SELECT idContacto, Codigo, nyap, Sector, telefono, mail,
                   observacion, Nacido, Sucursal, Cargo, Alta, baja
            FROM ContactosClientes
            ORDER BY idContacto
        `);

        if (result.recordset.length > 0) {
            const batchSize = 100;
            let migrated = 0;

            for (let i = 0; i < result.recordset.length; i += batchSize) {
                const batch = result.recordset.slice(i, i + batchSize);

                const contactosToInsert = batch.map(c => ({
                    id_contacto: c.idContacto,
                    codigo: c.Codigo,
                    nyap: c.nyap?.trim(),
                    sector: c.Sector?.trim(),
                    telefono: c.telefono?.trim(),
                    mail: c.mail?.trim(),
                    observacion: c.observacion?.trim(),
                    nacido: c.Nacido,
                    sucursal: c.Sucursal?.trim(),
                    cargo: c.Cargo?.trim(),
                    alta: c.Alta,
                    baja: c.baja
                }));

                const { error } = await supabase
                    .from('contactos_clientes')
                    .insert(contactosToInsert);

                if (error) {
                    console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
                } else {
                    migrated += contactosToInsert.length;
                }
            }

            console.log(`✅ ${migrated} contactos de clientes migrados\n`);
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 4: MIGRAR PROVEEDORES
//============================================
async function migrateProveedores(pool) {
    console.log('📋 Migrando proveedores...\n');

    try {
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

        console.log(`   Leyendo ${result.recordset.length} proveedores de SQL Server...`);

        if (result.recordset.length > 0) {
            const batchSize = 100;
            let migrated = 0;

            for (let i = 0; i < result.recordset.length; i += batchSize) {
                const batch = result.recordset.slice(i, i + batchSize);

                const proveedoresToInsert = batch.map(p => ({
                    codigo: p.Codigo,
                    razon_social: p.RazonSocial?.trim(),
                    domicilio: p.Domicilio?.trim(),
                    localidad: p.Localidad?.trim(),
                    codigo_postal: p.CodigoPostal?.trim(),
                    id_provincia: p.idProvincia,
                    cuenta: p.Cuenta,
                    tipo1: p.Tipo1,
                    telefono1: p.Telefono1?.trim(),
                    tipo2: p.Tipo2,
                    telefono2: p.Telefono2?.trim(),
                    tipo3: p.Tipo3,
                    telefono3: p.Telefono3?.trim(),
                    tipo4: p.tipo4,
                    telefono4: p.telefono4?.trim(),
                    tipo5: p.Tipo5,
                    telefono5: p.telefono5?.trim(),
                    tipo6: p.tipo6,
                    telefono6: p.telefono6?.trim(),
                    mail: p.mail?.trim(),
                    notas: p.Notas,
                    fecha: p.Fecha,
                    vendedor: p.Vendedor,
                    hora: p.Hora,
                    id_cliente_ant: p.idClienteant,
                    nombre: p.Nombre?.trim(),
                    apellido: p.Apellido?.trim(),
                    tipo_cuenta: p.TipoCuenta,
                    categoria: p.Categoria,
                    cuit: p.Cuit?.trim(),
                    civa: p.civa,
                    cuenta_subdiario: p.CuentaSubdiario,
                    fecha_nac: p.FechaNac,
                    activo: p.Activo,
                    codigo_externo: p.codigoexterno?.trim(),
                    vencimiento: p.vencimiento,
                    hora_atencion: p.horaAtencion?.trim(),
                    alerta: p.Alerta?.trim(),
                    cventa: p.cventa,
                    id_zona: p.idZona,
                    fecha_baja: p.fechabaja,
                    tabla_ganancia: p.TablaGanancia,
                    tipo_docto: p.tipodocto,
                    numero_docto: p.numerodocto,
                    descuento: p.descuento,
                    ibrutos: p.ibrutos?.trim(),
                    percepcion_ib: p.percepcionIB,
                    retencion_ib: p.retencionIB,
                    id_pais: p.idPais,
                    jurisdiccion: p.Jurisdiccion,
                    adicional: p.Adicional?.trim()
                }));

                const { error } = await supabase
                    .from('proveedores')
                    .insert(proveedoresToInsert);

                if (error) {
                    console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
                } else {
                    migrated += proveedoresToInsert.length;
                    console.log(`   ✅ Lote ${i / batchSize + 1}: ${proveedoresToInsert.length} proveedores`);
                }
            }

            console.log(`\n✅ Total migrados: ${migrated} proveedores\n`);
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 5: MIGRAR CONTACTOS PROVEEDORES
//============================================
async function migrateContactosProveedores(pool) {
    console.log('📋 Migrando contactos de proveedores...\n');

    try {
        const result = await pool.request().query(`
            SELECT idContacto, Codigo, nyap, Sector, telefono, mail,
                   observacion, Nacido, Sucursal, Cargo, Alta, baja
            FROM ContactosProveedores
            ORDER BY idContacto
        `);

        if (result.recordset.length > 0) {
            const batchSize = 100;
            let migrated = 0;

            for (let i = 0; i < result.recordset.length; i += batchSize) {
                const batch = result.recordset.slice(i, i + batchSize);

                const contactosToInsert = batch.map(c => ({
                    id_contacto: c.idContacto,
                    codigo: c.Codigo,
                    nyap: c.nyap?.trim(),
                    sector: c.Sector?.trim(),
                    telefono: c.telefono?.trim(),
                    mail: c.mail?.trim(),
                    observacion: c.observacion?.trim(),
                    nacido: c.Nacido,
                    sucursal: c.Sucursal?.trim(),
                    cargo: c.Cargo?.trim(),
                    alta: c.Alta,
                    baja: c.baja
                }));

                const { error } = await supabase
                    .from('contactos_proveedores')
                    .insert(contactosToInsert);

                if (error) {
                    console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
                } else {
                    migrated += contactosToInsert.length;
                }
            }

            console.log(`✅ ${migrated} contactos de proveedores migrados\n`);
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 6: MIGRAR TIPOS COMPROBANTE VENTAS
//============================================
async function migrateTipVentMod(pool) {
    console.log('📋 Migrando tipos de comprobante de ventas...\n');

    try {
        // Header
        const headerResult = await pool.request().query(`
            SELECT codigo, comprobante, descripcion, signo, Multiplicador, Sicore,
                   TipoStock, Modulo, IvaVentas, c_mov, comp, concCompra,
                   IE, WSA, WSB, WSE, wsc
            FROM tipventModHeader
            ORDER BY codigo
        `);

        if (headerResult.recordset.length > 0) {
            const { error: headerError } = await supabase
                .from('tip_vent_mod_header')
                .insert(headerResult.recordset.map(h => ({
                    codigo: h.codigo,
                    comprobante: h.comprobante?.trim(),
                    descripcion: h.descripcion?.trim(),
                    signo: h.signo,
                    multiplicador: h.Multiplicador,
                    sicore: h.Sicore?.trim(),
                    tipo_stock: h.TipoStock,
                    modulo: h.Modulo,
                    iva_ventas: h.IvaVentas?.trim(),
                    c_mov: h.c_mov,
                    comp: h.comp?.trim(),
                    conc_compra: h.concCompra?.trim(),
                    ie: h.IE,
                    wsa: h.WSA,
                    wsb: h.WSB,
                    wse: h.WSE,
                    wsc: h.wsc
                })));

            if (headerError) {
                console.error('❌ Error migrando tip_vent_mod_header:', headerError.message);
            } else {
                console.log(`✅ ${headerResult.recordset.length} tipos de comprobante ventas (header) migrados`);
            }
        }

        // Items
        const itemsResult = await pool.request().query(`
            SELECT codigo, concepto, signo
            FROM tipventModItems
            ORDER BY codigo, concepto
        `);

        if (itemsResult.recordset.length > 0) {
            const { error: itemsError } = await supabase
                .from('tip_vent_mod_items')
                .insert(itemsResult.recordset.map(i => ({
                    codigo: i.codigo,
                    concepto: i.concepto?.trim(),
                    signo: i.signo
                })));

            if (itemsError) {
                console.error('❌ Error migrando tip_vent_mod_items:', itemsError.message);
            } else {
                console.log(`✅ ${itemsResult.recordset.length} tipos de comprobante ventas (items) migrados\n`);
            }
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 7: MIGRAR TIPOS COMPROBANTE COMPRAS
//============================================
async function migrateTipCompMod(pool) {
    console.log('📋 Migrando tipos de comprobante de compras...\n');

    try {
        // Header
        const headerResult = await pool.request().query(`
            SELECT codigo, comprobante, descripcion, signo, Multiplicador, Sicore,
                   TIpoStock, c_mov, comp, ivaCompras, IE, BR, Modulo
            FROM TipCompModHeader
            ORDER BY codigo
        `);

        if (headerResult.recordset.length > 0) {
            const { error: headerError } = await supabase
                .from('tip_comp_mod_header')
                .insert(headerResult.recordset.map(h => ({
                    codigo: h.codigo,
                    comprobante: h.comprobante?.trim(),
                    descripcion: h.descripcion?.trim(),
                    signo: h.signo,
                    multiplicador: h.Multiplicador,
                    sicore: h.Sicore?.trim(),
                    tipo_stock: h.TIpoStock,
                    c_mov: h.c_mov,
                    comp: h.comp?.trim(),
                    iva_compras: h.ivaCompras?.trim(),
                    ie: h.IE,
                    br: h.BR?.trim(),
                    modulo: h.Modulo
                })));

            if (headerError) {
                console.error('❌ Error migrando tip_comp_mod_header:', headerError.message);
            } else {
                console.log(`✅ ${headerResult.recordset.length} tipos de comprobante compras (header) migrados`);
            }
        }

        // Items
        const itemsResult = await pool.request().query(`
            SELECT codigo, concepto, signo
            FROM TipCompModItems
            ORDER BY codigo, concepto
        `);

        if (itemsResult.recordset.length > 0) {
            const { error: itemsError } = await supabase
                .from('tip_comp_mod_items')
                .insert(itemsResult.recordset.map(i => ({
                    codigo: i.codigo,
                    concepto: i.concepto?.trim(),
                    signo: i.signo
                })));

            if (itemsError) {
                console.error('❌ Error migrando tip_comp_mod_items:', itemsError.message);
            } else {
                console.log(`✅ ${itemsResult.recordset.length} tipos de comprobante compras (items) migrados\n`);
            }
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 8: MIGRAR CTA CTE CLIENTES
//============================================
async function migrateVenCliHeader(pool) {
    console.log('📋 Migrando cuenta corriente clientes (header)...\n');

    try {
        const result = await pool.request().query(`
            SELECT idtransaccion, comprobante, aniomes, fecha, cliente, tipocomprobante,
                   nrocomprobante, tipofactura, totalimporte, cancelado,
                   fecha1venc, fecha2venc, estado, fechareal, centrocosto,
                   DescripcionImporte, Moneda, ImporteOrigen, TC, doc_c, CanceladoOrigen
            FROM VenCliHeader
            ORDER BY idtransaccion
        `);

        console.log(`   Leyendo ${result.recordset.length} transacciones de clientes...`);

        if (result.recordset.length > 0) {
            const batchSize = 500;
            let migrated = 0;

            for (let i = 0; i < result.recordset.length; i += batchSize) {
                const batch = result.recordset.slice(i, i + batchSize);

                const transToInsert = batch.map(t => ({
                    id_transaccion: t.idtransaccion,
                    comprobante: t.comprobante,
                    anio_mes: t.aniomes,
                    fecha: t.fecha,
                    cliente: t.cliente,
                    tipo_comprobante: t.tipocomprobante,
                    nro_comprobante: t.nrocomprobante?.trim(),
                    tipo_factura: t.tipofactura?.trim(),
                    total_importe: t.totalimporte,
                    cancelado: t.cancelado,
                    fecha1_venc: t.fecha1venc,
                    fecha2_venc: t.fecha2venc,
                    estado: t.estado?.trim(),
                    fecha_real: t.fechareal,
                    centro_costo: t.centrocosto,
                    descripcion_importe: t.DescripcionImporte?.trim(),
                    moneda: t.Moneda,
                    importe_origen: t.ImporteOrigen,
                    tc: t.TC,
                    doc_c: t.doc_c,
                    cancelado_origen: t.CanceladoOrigen
                }));

                const { error } = await supabase
                    .from('ven_cli_header')
                    .insert(transToInsert);

                if (error) {
                    console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
                } else {
                    migrated += transToInsert.length;
                    console.log(`   ✅ Lote ${i / batchSize + 1}: ${transToInsert.length} transacciones`);
                }
            }

            console.log(`\n✅ Total migrados: ${migrated} transacciones cta cte clientes (header)\n`);
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

async function migrateVenCliItems(pool) {
    console.log('📋 Migrando cuenta corriente clientes (items)...\n');

    try {
        const result = await pool.request().query(`
            SELECT idCampo, idTransaccion, comprobante, aniomes, item, concepto,
                   cuenta, importe, BaseContable, Area, Detalle, Alicuota, Grilla, Base
            FROM Vencliitems
            ORDER BY idCampo
        `);

        console.log(`   Leyendo ${result.recordset.length} items de transacciones...`);

        if (result.recordset.length > 0) {
            const batchSize = 500;
            let migrated = 0;

            for (let i = 0; i < result.recordset.length; i += batchSize) {
                const batch = result.recordset.slice(i, i + batchSize);

                const itemsToInsert = batch.map(t => ({
                    id_campo: t.idCampo,
                    id_transaccion: t.idTransaccion,
                    comprobante: t.comprobante,
                    anio_mes: t.aniomes,
                    item: t.item,
                    concepto: t.concepto?.trim(),
                    cuenta: t.cuenta,
                    importe: t.importe,
                    base_contable: t.BaseContable,
                    area: t.Area,
                    detalle: t.Detalle?.trim(),
                    alicuota: t.Alicuota,
                    grilla: t.Grilla?.trim(),
                    base: t.Base
                }));

                const { error } = await supabase
                    .from('ven_cli_items')
                    .insert(itemsToInsert);

                if (error) {
                    console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
                } else {
                    migrated += itemsToInsert.length;
                    console.log(`   ✅ Lote ${i / batchSize + 1}: ${itemsToInsert.length} items`);
                }
            }

            console.log(`\n✅ Total migrados: ${migrated} items cta cte clientes\n`);
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 9: MIGRAR CTA CTE PROVEEDORES
//============================================
async function migrateCompProvHeader(pool) {
    console.log('📋 Migrando cuenta corriente proveedores (header)...\n');

    try {
        const result = await pool.request().query(`
            SELECT idtransaccion, comprobante, aniomes, fecha, proveedor, tipocomprobante,
                   nrocomprobante, tipofactura, totalimporte, cancelado,
                   fecha1venc, fecha2venc, estado, fechareal, centrocosto,
                   DescripcionImporte, Moneda, ImporteOrigen, TC, doc_c, CanceladoOrigen
            FROM CompProvHeader
            ORDER BY idtransaccion
        `);

        console.log(`   Leyendo ${result.recordset.length} transacciones de proveedores...`);

        if (result.recordset.length > 0) {
            const batchSize = 500;
            let migrated = 0;

            for (let i = 0; i < result.recordset.length; i += batchSize) {
                const batch = result.recordset.slice(i, i + batchSize);

                const transToInsert = batch.map(t => ({
                    id_transaccion: t.idtransaccion,
                    comprobante: t.comprobante,
                    anio_mes: t.aniomes,
                    fecha: t.fecha,
                    proveedor: t.proveedor,
                    tipo_comprobante: t.tipocomprobante,
                    nro_comprobante: t.nrocomprobante?.trim(),
                    tipo_factura: t.tipofactura?.trim(),
                    total_importe: t.totalimporte,
                    cancelado: t.cancelado,
                    fecha1_venc: t.fecha1venc,
                    fecha2_venc: t.fecha2venc,
                    estado: t.estado?.trim(),
                    fecha_real: t.fechareal,
                    centro_costo: t.centrocosto,
                    descripcion_importe: t.DescripcionImporte?.trim(),
                    moneda: t.Moneda,
                    importe_origen: t.ImporteOrigen,
                    tc: t.TC,
                    doc_c: t.doc_c,
                    cancelado_origen: t.CanceladoOrigen
                }));

                const { error } = await supabase
                    .from('comp_prov_header')
                    .insert(transToInsert);

                if (error) {
                    console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
                } else {
                    migrated += transToInsert.length;
                    console.log(`   ✅ Lote ${i / batchSize + 1}: ${transToInsert.length} transacciones`);
                }
            }

            console.log(`\n✅ Total migrados: ${migrated} transacciones cta cte proveedores (header)\n`);
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

async function migrateCompProvItems(pool) {
    console.log('📋 Migrando cuenta corriente proveedores (items)...\n');

    try {
        const result = await pool.request().query(`
            SELECT idCampo, idTransaccion, comprobante, aniomes, item, concepto,
                   cuenta, importe, BaseContable, Area, Detalle, Alicuota, Grilla,
                   Base, FechaCierre, Factura
            FROM CompProvItems
            ORDER BY idCampo
        `);

        console.log(`   Leyendo ${result.recordset.length} items de transacciones...`);

        if (result.recordset.length > 0) {
            const batchSize = 500;
            let migrated = 0;

            for (let i = 0; i < result.recordset.length; i += batchSize) {
                const batch = result.recordset.slice(i, i + batchSize);

                const itemsToInsert = batch.map(t => ({
                    id_campo: t.idCampo,
                    id_transaccion: t.idTransaccion,
                    comprobante: t.comprobante,
                    anio_mes: t.aniomes,
                    item: t.item,
                    concepto: t.concepto?.trim(),
                    cuenta: t.cuenta,
                    importe: t.importe,
                    base_contable: t.BaseContable,
                    area: t.Area,
                    detalle: t.Detalle?.trim(),
                    alicuota: t.Alicuota,
                    grilla: t.Grilla?.trim(),
                    base: t.Base,
                    fecha_cierre: t.FechaCierre,
                    factura: t.Factura?.trim()
                }));

                const { error } = await supabase
                    .from('comp_prov_items')
                    .insert(itemsToInsert);

                if (error) {
                    console.error(`❌ Error en lote ${i / batchSize + 1}:`, error.message);
                } else {
                    migrated += itemsToInsert.length;
                    console.log(`   ✅ Lote ${i / batchSize + 1}: ${itemsToInsert.length} items`);
                }
            }

            console.log(`\n✅ Total migrados: ${migrated} items cta cte proveedores\n`);
        }
    } catch (err) {
        console.error('💥 Error:', err);
        throw err;
    }
}

//============================================
// PASO 10: RESETEAR SECUENCIAS
//============================================
async function resetSequences() {
    console.log('🔄 Reseteando secuencias...\n');

    const sequences = [
        { table: 'categorias_iva', column: 'id_civa' },
        { table: 'clientes', column: 'codigo' },
        { table: 'contactos_clientes', column: 'id_contacto' },
        { table: 'proveedores', column: 'codigo' },
        { table: 'contactos_proveedores', column: 'id_contacto' },
        { table: 'tip_vent_mod_header', column: 'codigo' },
        { table: 'tip_vent_mod_items', column: 'id' },
        { table: 'tip_comp_mod_header', column: 'codigo' },
        { table: 'tip_comp_mod_items', column: 'id' },
        { table: 'ven_cli_header', column: 'id_transaccion' },
        { table: 'ven_cli_items', column: 'id_campo' },
        { table: 'comp_prov_header', column: 'id_transaccion' },
        { table: 'comp_prov_items', column: 'id_campo' }
    ];

    for (const seq of sequences) {
        try {
            const { data, error } = await supabase.rpc('reset_sequence', {
                table_name: seq.table,
                column_name: seq.column
            });

            if (error) {
                console.log(`   ⚠️  ${seq.table}: necesita reseteo manual`);
            } else {
                console.log(`   ✅ ${seq.table}.${seq.column} reseteada`);
            }
        } catch (err) {
            console.log(`   ⚠️  ${seq.table}: ${err.message}`);
        }
    }

    console.log('\n   Nota: Si hay errores, ejecutar manualmente en Supabase:\n');
    console.log('   SELECT setval(pg_get_serial_sequence(\'tabla\', \'columna\'), (SELECT MAX(columna) FROM tabla));\n');
}

//============================================
// MAIN: EJECUTAR MIGRACIÓN CLIPRO
//============================================
async function main() {
    console.log('========================================');
    console.log('  Migración CLIPRO SQL Server → Supabase');
    console.log('  (Clientes/Proveedores)');
    console.log('========================================\n');

    const args = process.argv.slice(2);
    const skipCtaCte = args.includes('--skip-ctacte');

    try {
        // Conectar a SQL Server
        console.log('🔌 Conectando a SQL Server...');
        const pool = await sql.connect(sqlConfig);
        console.log('✅ Conectado a SQL Server\n');

        // Limpiar todas las tablas primero
        await cleanAllTables();

        // Ejecutar migración en orden
        await migrateCategoriasIvaCLIPRO(pool);
        await migrateClientes(pool);
        await migrateContactosClientes(pool);
        await migrateProveedores(pool);
        await migrateContactosProveedores(pool);
        await migrateTipVentMod(pool);
        await migrateTipCompMod(pool);

        if (!skipCtaCte) {
            await migrateVenCliHeader(pool);
            await migrateVenCliItems(pool);
            await migrateCompProvHeader(pool);
            await migrateCompProvItems(pool);
        } else {
            console.log('⏭️  Saltando migración de cuentas corrientes (--skip-ctacte)\n');
        }

        await resetSequences();

        await pool.close();

        console.log('========================================');
        console.log('✅ MIGRACIÓN CLIPRO COMPLETADA');
        console.log('========================================\n');

        process.exit(0);

    } catch (error) {
        console.error('\n💥 ERROR FATAL:', error);
        process.exit(1);
    }
}

main();
