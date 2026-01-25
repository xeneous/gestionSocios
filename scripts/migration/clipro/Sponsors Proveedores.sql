USE [BaseCrm]
GO
/****** Object:  Table [dbo].[Categorias_Iva]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Categorias_Iva](
	[IdCiva] [int] IDENTITY(1,1) NOT NULL,
	[Descripcion] [char](25) NULL,
	[Ganancias] [int] NULL,
	[TipoFacturaCompras] [char](1) NULL,
	[TipoFacturaVentas] [char](1) NULL,
	[Resumido] [char](4) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Clientes]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Clientes](
	[Codigo] [int] IDENTITY(1,1) NOT NULL,
	[RazonSocial] [nvarchar](60) NULL,
	[Domicilio] [nvarchar](40) NULL,
	[Localidad] [nvarchar](40) NULL,
	[CodigoPostal] [varchar](8) NULL,
	[idProvincia] [int] NULL,
	[Tipo1] [tinyint] NULL,
	[Telefono1] [nvarchar](40) NULL,
	[Tipo2] [tinyint] NULL,
	[Telefono2] [nvarchar](40) NULL,
	[Tipo3] [tinyint] NULL,
	[Telefono3] [nvarchar](40) NULL,
	[tipo4] [tinyint] NULL,
	[telefono4] [nvarchar](40) NULL,
	[Tipo5] [tinyint] NULL,
	[telefono5] [nvarchar](40) NULL,
	[tipo6] [tinyint] NULL,
	[telefono6] [nvarchar](40) NULL,
	[mail] [nvarchar](50) NULL,
	[Notas] [ntext] NULL,
	[Fecha] [smalldatetime] NULL,
	[Vendedor] [smallint] NULL,
	[Hora] [datetime] NULL,
	[idClienteant] [int] NULL,
	[Nombre] [nvarchar](30) NULL,
	[Apellido] [nvarchar](30) NULL,
	[TipoCuenta] [tinyint] NULL,
	[Categoria] [tinyint] NULL,
	[Cuit] [nvarchar](13) NULL,
	[civa] [tinyint] NULL,
	[Cuenta] [int] NULL,
	[CuentaSubdiario] [int] NULL,
	[FechaNac] [datetime] NULL,
	[Activo] [int] NULL,
	[codigoexterno] [varchar](20) NULL,
	[vencimiento] [datetime] NULL,
	[horaAtencion] [varchar](50) NULL,
	[Alerta] [varchar](255) NULL,
	[cventa] [int] NULL,
	[tablaganancia] [int] NULL,
	[idZona] [int] NULL,
	[Fechabaja] [datetime] NULL,
	[tipodocto] [int] NULL,
	[numerodocto] [int] NULL,
	[Descuento] [numeric](18, 2) NULL,
	[TipoCuentaComis] [int] NULL,
	[ibrutos] [varchar](12) NULL,
	[percepcionIB] [numeric](8, 2) NULL,
	[retencionIB] [numeric](8, 2) NULL,
	[idPais] [int] NULL,
	[Jurisdiccion] [int] NULL,
	[Adicional] [varchar](60) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CompProvHeader]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CompProvHeader](
	[idtransaccion] [int] IDENTITY(1,1) NOT NULL,
	[comprobante] [int] NOT NULL,
	[aniomes] [int] NOT NULL,
	[fecha] [datetime] NOT NULL,
	[proveedor] [int] NOT NULL,
	[tipocomprobante] [int] NOT NULL,
	[nrocomprobante] [char](12) NOT NULL,
	[tipofactura] [char](1) NULL,
	[totalimporte] [numeric](18, 2) NOT NULL,
	[cancelado] [numeric](18, 2) NULL,
	[fecha1venc] [datetime] NULL,
	[fecha2venc] [datetime] NULL,
	[estado] [char](1) NOT NULL,
	[fechareal] [datetime] NOT NULL,
	[centrocosto] [int] NULL,
	[DescripcionImporte] [varchar](255) NULL,
	[Moneda] [int] NULL,
	[ImporteOrigen] [numeric](18, 2) NULL,
	[TC] [numeric](18, 3) NULL,
	[doc_c] [numeric](18, 0) NULL,
	[CanceladoOrigen] [numeric](18, 2) NULL,
 CONSTRAINT [PK_CompProvHeader] PRIMARY KEY CLUSTERED 
(
	[idtransaccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[CompProvItems]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CompProvItems](
	[idTransaccion] [int] NULL,
	[comprobante] [int] NOT NULL,
	[aniomes] [int] NOT NULL,
	[item] [int] NOT NULL,
	[concepto] [char](3) NOT NULL,
	[cuenta] [int] NOT NULL,
	[importe] [numeric](18, 4) NOT NULL,
	[BaseContable] [numeric](18, 2) NOT NULL,
	[Area] [int] NULL,
	[Detalle] [varchar](60) NULL,
	[Alicuota] [numeric](18, 2) NOT NULL,
	[Grilla] [varchar](30) NULL,
	[idCampo] [int] IDENTITY(1,1) NOT NULL,
	[Base] [numeric](18, 2) NULL,
	[FechaCierre] [datetime] NULL,
	[Factura] [varchar](20) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ContactosClientes]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ContactosClientes](
	[idContacto] [int] IDENTITY(1,1) NOT NULL,
	[Codigo] [int] NULL,
	[nyap] [nvarchar](50) NULL,
	[Sector] [nvarchar](60) NULL,
	[telefono] [nvarchar](50) NULL,
	[mail] [nvarchar](50) NULL,
	[observacion] [nvarchar](60) NULL,
	[Nacido] [datetime] NULL,
	[Sucursal] [varchar](60) NULL,
	[Cargo] [varchar](60) NULL,
	[Alta] [datetime] NULL,
	[baja] [datetime] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ContactosProveedores]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ContactosProveedores](
	[idContacto] [int] IDENTITY(1,1) NOT NULL,
	[Codigo] [int] NULL,
	[nyap] [nvarchar](50) NULL,
	[Sector] [nvarchar](60) NULL,
	[telefono] [nvarchar](50) NULL,
	[mail] [nvarchar](50) NULL,
	[observacion] [nvarchar](60) NULL,
	[Nacido] [datetime] NULL,
	[Sucursal] [varchar](60) NULL,
	[Cargo] [varchar](60) NULL,
	[Alta] [datetime] NULL,
	[baja] [datetime] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Proveedores]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Proveedores](
	[Codigo] [int] IDENTITY(1,1) NOT NULL,
	[RazonSocial] [nvarchar](60) NULL,
	[Domicilio] [nvarchar](40) NULL,
	[Localidad] [nvarchar](40) NULL,
	[CodigoPostal] [varchar](8) NULL,
	[idProvincia] [int] NULL,
	[Cuenta] [int] NULL,
	[Tipo1] [tinyint] NULL,
	[Telefono1] [nvarchar](40) NULL,
	[Tipo2] [tinyint] NULL,
	[Telefono2] [nvarchar](40) NULL,
	[Tipo3] [tinyint] NULL,
	[Telefono3] [nvarchar](40) NULL,
	[tipo4] [tinyint] NULL,
	[telefono4] [nvarchar](40) NULL,
	[Tipo5] [tinyint] NULL,
	[telefono5] [nvarchar](40) NULL,
	[tipo6] [tinyint] NULL,
	[telefono6] [nvarchar](40) NULL,
	[mail] [nvarchar](50) NULL,
	[Notas] [ntext] NULL,
	[Fecha] [smalldatetime] NULL,
	[Vendedor] [smallint] NULL,
	[Hora] [datetime] NULL,
	[idClienteant] [int] NULL,
	[Nombre] [nvarchar](30) NULL,
	[Apellido] [nvarchar](30) NULL,
	[TipoCuenta] [tinyint] NULL,
	[Categoria] [tinyint] NULL,
	[Cuit] [nvarchar](13) NULL,
	[civa] [tinyint] NULL,
	[CuentaSubdiario] [int] NULL,
	[FechaNac] [datetime] NULL,
	[Activo] [int] NULL,
	[codigoexterno] [varchar](20) NULL,
	[vencimiento] [datetime] NULL,
	[horaAtencion] [varchar](50) NULL,
	[Alerta] [varchar](255) NULL,
	[cventa] [int] NULL,
	[idZona] [int] NULL,
	[fechabaja] [datetime] NULL,
	[TablaGanancia] [int] NULL,
	[tipodocto] [int] NULL,
	[numerodocto] [int] NULL,
	[descuento] [numeric](18, 2) NULL,
	[ibrutos] [varchar](12) NULL,
	[percepcionIB] [numeric](8, 2) NULL,
	[retencionIB] [numeric](8, 2) NULL,
	[idPais] [int] NULL,
	[Jurisdiccion] [int] NULL,
	[Adicional] [varchar](60) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TipCompModHeader]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TipCompModHeader](
	[codigo] [int] IDENTITY(0,1) NOT NULL,
	[comprobante] [char](5) NOT NULL,
	[descripcion] [varchar](25) NOT NULL,
	[signo] [int] NULL,
	[Multiplicador] [int] NULL,
	[Sicore] [char](2) NULL,
	[TIpoStock] [int] NULL,
	[c_mov] [int] NULL,
	[comp] [varchar](50) NULL,
	[ivaCompras] [varchar](1) NULL,
	[IE] [int] NULL,
	[BR] [varchar](2) NULL,
	[Modulo] [int] NULL,
 CONSTRAINT [PK_TipCompModHeader] PRIMARY KEY CLUSTERED 
(
	[codigo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TipCompModItems]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TipCompModItems](
	[codigo] [int] NOT NULL,
	[concepto] [char](5) NOT NULL,
	[signo] [int] NOT NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tipventModHeader]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tipventModHeader](
	[codigo] [int] IDENTITY(0,1) NOT NULL,
	[comprobante] [char](5) NOT NULL,
	[descripcion] [varchar](25) NOT NULL,
	[signo] [int] NULL,
	[Multiplicador] [int] NULL,
	[Sicore] [varchar](2) NULL,
	[TipoStock] [int] NULL,
	[Modulo] [int] NULL,
	[IvaVentas] [char](1) NULL,
	[c_mov] [int] NULL,
	[comp] [varchar](10) NULL,
	[concCompra] [varchar](3) NULL,
	[IE] [int] NULL,
	[WSA] [int] NULL,
	[WSB] [int] NULL,
	[WSE] [int] NULL,
	[wsc] [int] NULL,
 CONSTRAINT [PK_tipventModHeader] PRIMARY KEY CLUSTERED 
(
	[codigo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY],
 CONSTRAINT [IX_tipventModHeader] UNIQUE NONCLUSTERED 
(
	[comprobante] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[tipventModItems]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[tipventModItems](
	[codigo] [int] NOT NULL,
	[concepto] [char](5) NOT NULL,
	[signo] [int] NOT NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[VenCliHeader]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[VenCliHeader](
	[idtransaccion] [int] IDENTITY(1,1) NOT NULL,
	[comprobante] [int] NOT NULL,
	[aniomes] [int] NOT NULL,
	[fecha] [datetime] NOT NULL,
	[cliente] [int] NOT NULL,
	[tipocomprobante] [int] NOT NULL,
	[nrocomprobante] [char](12) NULL,
	[tipofactura] [char](1) NULL,
	[totalimporte] [numeric](18, 2) NOT NULL,
	[cancelado] [numeric](18, 2) NULL,
	[fecha1venc] [datetime] NULL,
	[fecha2venc] [datetime] NULL,
	[estado] [char](2) NULL,
	[fechareal] [datetime] NOT NULL,
	[centrocosto] [int] NULL,
	[DescripcionImporte] [varchar](255) NULL,
	[Moneda] [int] NULL,
	[ImporteOrigen] [numeric](18, 2) NULL,
	[TC] [numeric](18, 4) NULL,
	[doc_c] [numeric](18, 0) NULL,
	[CanceladoOrigen] [numeric](18, 2) NULL,
 CONSTRAINT [PK_VenCliHeader] PRIMARY KEY CLUSTERED 
(
	[idtransaccion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Vencliitems]    Script Date: 24/1/2026 17:52:56 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Vencliitems](
	[idTransaccion] [int] NULL,
	[comprobante] [int] NOT NULL,
	[aniomes] [int] NOT NULL,
	[item] [int] NOT NULL,
	[concepto] [char](3) NOT NULL,
	[cuenta] [int] NOT NULL,
	[importe] [numeric](18, 2) NOT NULL,
	[BaseContable] [numeric](18, 2) NOT NULL,
	[Area] [int] NULL,
	[Detalle] [varchar](60) NULL,
	[Alicuota] [numeric](18, 2) NOT NULL,
	[Grilla] [varchar](30) NULL,
	[idCampo] [int] IDENTITY(1,1) NOT NULL,
	[Base] [numeric](18, 2) NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[tipventModHeader] ADD  CONSTRAINT [DF_tipventModHeader_IvaVentas]  DEFAULT ('S') FOR [IvaVentas]
GO
