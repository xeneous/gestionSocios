import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/socio_model.dart';
import '../../models/tipo_documento_model.dart';
import '../../providers/socios_provider.dart';
import '../../providers/grupos_agrupados_provider.dart';
import '../../providers/tarjetas_provider.dart';
import '../../providers/provincias_provider.dart';
import '../../providers/paises_provider.dart';
import '../../providers/sexos_provider.dart';
import '../../providers/categorias_residente_provider.dart';
import '../widgets/concepto_search_dialog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/user_role_provider.dart';
import '../../providers/conceptos_socio_provider.dart';
import '../../providers/observaciones_socio_provider.dart';
import '../../providers/conceptos_provider.dart';
import '../../models/concepto_model.dart';
import '../../models/concepto_socio_model.dart';
import '../../models/observacion_socio_model.dart';
import '../../../cuota_social/presentation/dialogs/cargar_cuotas_dialog.dart';

class SocioFormPage extends ConsumerStatefulWidget {
  final int? socioId;

  const SocioFormPage({super.key, this.socioId});

  @override
  ConsumerState<SocioFormPage> createState() => _SocioFormPageState();
}

class _SocioFormPageState extends ConsumerState<SocioFormPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Datos Personales
  final _apellidoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _numeroDocumentoController = TextEditingController();
  final _cuilController = TextEditingController();
  String _tipoDocumento = 'DNI';
  int? _sexo = 0;
  DateTime? _fechaNacimiento;

  // Datos Profesionales
  String? _grupo = 'A'; // Grupo por defecto: 'A' = Asociado
  DateTime? _grupoDesde;
  final _matriculaNacionalController = TextEditingController();
  final _matriculaProvincialController = TextEditingController();
  bool _residente = false;
  DateTime? _fechaInicioResidencia;
  DateTime? _fechaFinResidencia;
  String? _categoriaResidente;
  DateTime? _fechaIngreso = DateTime.now(); // Fecha actual por defecto

  // Domicilio y Contacto
  final _domicilioController = TextEditingController();
  final _localidadController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  int? _provinciaId;
  int? _paisId;
  final _telefonoController = TextEditingController();
  final _telefonoSecundarioController = TextEditingController();
  final _celularController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailAlternativoController = TextEditingController();

  // Débito Automático
  bool _adheridoDebito = false;
  int? _tarjetaId;
  final _numeroTarjetaController = TextEditingController();
  DateTime? _vencimientoTarjeta;
  DateTime? _debitarDesde;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // 6 tabs
    if (widget.socioId != null) {
      _loadSocioData();
    }
  }

  Future<void> _loadSocioData() async {
    try {
      final socio = await ref
          .read(sociosNotifierProvider.notifier)
          .getSocioById(widget.socioId!);

      print('DEBUG: Socio loaded: ${socio != null}');
      if (socio != null) {
        print(
            'DEBUG: Socio data - Apellido: ${socio.apellido}, Nombre: ${socio.nombre}');
      }

      if (socio != null && mounted) {
        setState(() {
          // Datos Personales
          _apellidoController.text = socio.apellido;
          _nombreController.text = socio.nombre;
          _tipoDocumento = socio.tipoDocumento ?? 'DNI';
          _numeroDocumentoController.text = socio.numeroDocumento ?? '';
          _cuilController.text = socio.cuil ?? '';
          _sexo = socio.sexo;
          _fechaNacimiento = socio.fechaNacimiento;

          // Datos Profesionales
          _grupo = socio.grupo;
          _grupoDesde = socio.grupoDesde;
          _matriculaNacionalController.text = socio.matriculaNacional ?? '';
          _matriculaProvincialController.text = socio.matriculaProvincial ?? '';
          _residente = socio.residente;
          _fechaInicioResidencia = socio.fechaInicioResidencia;
          _fechaFinResidencia = socio.fechaFinResidencia;
          _categoriaResidente = socio.categoriaResidente;
          _fechaIngreso = socio.fechaIngreso;

          // Domicilio y Contacto
          _domicilioController.text = socio.domicilio ?? '';
          _localidadController.text = socio.localidad ?? '';
          _codigoPostalController.text = socio.codigoPostal ?? '';
          _provinciaId = socio.provinciaId;
          _paisId = socio.paisId;
          _telefonoController.text = socio.telefono ?? '';
          _telefonoSecundarioController.text = socio.telefonoSecundario ?? '';
          _celularController.text = socio.celular ?? '';
          _emailController.text = socio.email ?? '';
          _emailAlternativoController.text = socio.emailAlternativo ?? '';

          // Débito Automático
          _adheridoDebito = socio.adheridoDebito;
          _tarjetaId = socio.tarjetaId;
          _numeroTarjetaController.text = socio.numeroTarjeta ?? '';
          _vencimientoTarjeta = socio.vencimientoTarjeta;
          _debitarDesde = socio.debitarDesde;
        });
      }
    } catch (e) {
      print('DEBUG ERROR loading socio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar socio: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apellidoController.dispose();
    _nombreController.dispose();
    _numeroDocumentoController.dispose();
    _cuilController.dispose();
    _matriculaNacionalController.dispose();
    _matriculaProvincialController.dispose();
    _domicilioController.dispose();
    _localidadController.dispose();
    _codigoPostalController.dispose();
    _telefonoController.dispose();
    _telefonoSecundarioController.dispose();
    _celularController.dispose();
    _emailController.dispose();
    _emailAlternativoController.dispose();
    _numeroTarjetaController.dispose();
    super.dispose();
  }

  Future<void> _saveSocio({bool closeAfterSave = false}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final socio = Socio(
        id: widget.socioId,
        apellido: _apellidoController.text,
        nombre: _nombreController.text,
        tipoDocumento: _tipoDocumento,
        numeroDocumento: _numeroDocumentoController.text.isEmpty
            ? null
            : _numeroDocumentoController.text,
        cuil: _cuilController.text.isEmpty ? null : _cuilController.text,
        sexo: _sexo,
        fechaNacimiento: _fechaNacimiento,
        grupo: _grupo,
        grupoDesde: _grupoDesde,
        residente: _residente,
        fechaInicioResidencia: _fechaInicioResidencia,
        fechaFinResidencia: _fechaFinResidencia,
        categoriaResidente: _categoriaResidente,
        matriculaNacional: _matriculaNacionalController.text.isEmpty
            ? null
            : _matriculaNacionalController.text,
        matriculaProvincial: _matriculaProvincialController.text.isEmpty
            ? null
            : _matriculaProvincialController.text,
        fechaIngreso: _fechaIngreso,
        domicilio: _domicilioController.text.isEmpty
            ? null
            : _domicilioController.text,
        localidad: _localidadController.text.isEmpty
            ? null
            : _localidadController.text,
        codigoPostal: _codigoPostalController.text.isEmpty
            ? null
            : _codigoPostalController.text,
        provinciaId: _provinciaId,
        paisId: _paisId,
        telefono:
            _telefonoController.text.isEmpty ? null : _telefonoController.text,
        telefonoSecundario: _telefonoSecundarioController.text.isEmpty
            ? null
            : _telefonoSecundarioController.text,
        celular:
            _celularController.text.isEmpty ? null : _celularController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        emailAlternativo: _emailAlternativoController.text.isEmpty
            ? null
            : _emailAlternativoController.text,
        adheridoDebito: _adheridoDebito,
        tarjetaId: _tarjetaId,
        numeroTarjeta: _numeroTarjetaController.text.isEmpty
            ? null
            : _numeroTarjetaController.text,
        vencimientoTarjeta: _vencimientoTarjeta,
        debitarDesde: _debitarDesde,
      );

      int? nuevoSocioId;
      bool isNewSocio = widget.socioId == null;

      if (widget.socioId != null) {
        await ref
            .read(sociosNotifierProvider.notifier)
            .updateSocio(widget.socioId!, socio);
      } else {
        nuevoSocioId = await ref.read(sociosNotifierProvider.notifier).createSocio(socio);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.socioId != null
                ? 'Socio actualizado correctamente'
                : 'Socio creado correctamente'),
          ),
        );

        // Si es un nuevo socio, mostrar diálogo de cargar cuotas
        if (isNewSocio && nuevoSocioId != null) {
          final resultado = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => CargarCuotasDialog(
              socioId: nuevoSocioId!,
              esResidente: _residente,
              nombreSocio: '${_apellidoController.text}, ${_nombreController.text}',
              categoriaResidente: _categoriaResidente,
            ),
          );

          if (resultado == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cuotas sociales creadas correctamente'),
                backgroundColor: Colors.green,
              ),
            );

            // Preguntar si desea cargar la cobranza
            final cargarCobranza = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cargar Cobranza'),
                content: const Text('¿Desea cargar la cobranza para las cuotas sociales creadas?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Sí'),
                  ),
                ],
              ),
            );

            // Si confirma, navegar a la pantalla de cobranzas
            if (cargarCobranza == true && mounted) {
              context.go('/cobranzas/$nuevoSocioId');
              return; // Salir sin volver a /socios
            }
          }
        }

        if (closeAfterSave) {
          context.go('/socios');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gruposAsync = ref.watch(gruposAgrupadosProvider(false));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.socioId != null ? 'Editar Socio' : 'Nuevo Socio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Fixed header with key socio information
                  _buildSocioHeader(gruposAsync),
                  // TabBar moved from AppBar
                  Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabs: const [
                        Tab(icon: Icon(Icons.person), text: 'Datos Personales'),
                        Tab(
                            icon: Icon(Icons.school),
                            text: 'Datos Profesionales'),
                        Tab(
                            icon: Icon(Icons.home),
                            text: 'Domicilio y Contacto'),
                        Tab(
                            icon: Icon(Icons.credit_card),
                            text: 'Débito Automático'),
                        Tab(icon: Icon(Icons.receipt_long), text: 'Conceptos'),
                        Tab(icon: Icon(Icons.note), text: 'Observaciones'),
                      ],
                    ),
                  ),
                  // TabBarView content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDatosPersonalesTab(),
                        _buildDatosProfesionalesTab(gruposAsync),
                        _buildDomicilioContactoTab(),
                        _buildDebitoAutomaticoTab(),
                        _buildConceptosTab(),
                        _buildObservacionesTab(),
                      ],
                    ),
                  ),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildSocioHeader(AsyncValue<List> gruposAsync) {
    // Get display values
    final numeroSocio = widget.socioId?.toString() ?? 'NUEVO';
    final apellido =
        _apellidoController.text.isEmpty ? '-' : _apellidoController.text;
    final nombre =
        _nombreController.text.isEmpty ? '-' : _nombreController.text;
    final fechaIngresoDisplay = _fechaIngreso != null
        ? DateFormat('dd/MM/yyyy').format(_fechaIngreso!)
        : '-';

    // Buscar la descripción del grupo
    String grupoDisplay = '-';
    gruposAsync.whenData((grupos) {
      if (_grupo != null) {
        try {
          final grupoEncontrado = grupos.firstWhere(
            (g) => g.codigo == _grupo,
          );
          grupoDisplay = grupoEncontrado.descripcion;
        } catch (e) {
          // Si no se encuentra el grupo, mostrar el código
          grupoDisplay = _grupo!;
        }
      }
    });

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Numero de Socio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.badge,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'N° Socio',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    numeroSocio,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
            // Apellido y Nombre
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Nombre',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$apellido, $nombre',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // Grupo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Grupo',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    grupoDisplay,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            // Fecha de Ingreso
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Ingreso SAO',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fechaIngresoDisplay,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            // Residente
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home_work,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Residente',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _residente ? Colors.green[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _residente ? 'SÍ' : 'NO',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _residente
                                ? Colors.green[800]
                                : Colors.grey[700],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatosPersonalesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Datos Personales',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _apellidoController,
                decoration: const InputDecoration(
                  labelText: 'Apellido *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo requerido';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return TextEditingValue(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Campo requerido';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return TextEditingValue(
                      text: newValue.text.toUpperCase(),
                      selection: newValue.selection,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _tipoDocumento.isNotEmpty ? _tipoDocumento : null,
                decoration: const InputDecoration(
                  labelText: 'Tipo Documento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                items: TipoDocumento.opciones.map((tipo) {
                  return DropdownMenuItem<String>(
                    value: tipo.codigo,
                    child: Text('${tipo.codigo} - ${tipo.descripcion}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _tipoDocumento = value ?? 'DNI');
                },
              ),
            ),
            // TODO: Dropdown tipo documento comentado temporalmente
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _numeroDocumentoController,
                decoration: const InputDecoration(
                  labelText: 'Número de Documento',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cuilController,
                decoration: const InputDecoration(
                  labelText: 'CUIL',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                  hintText: '20-12345678-9',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final sexosAsync = ref.watch(sexosProvider);
                  return sexosAsync.when(
                    data: (sexos) {
                      // Validar que el valor actual existe en la lista
                      final validValue =
                          sexos.any((s) => s.id == _sexo) ? _sexo : 0;
                      if (validValue != _sexo) {
                        // Si el valor no es válido, actualizar al default
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() => _sexo = validValue);
                        });
                      }

                      return DropdownButtonFormField<int>(
                        initialValue: validValue,
                        decoration: const InputDecoration(
                          labelText: 'Sexo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: sexos.map((sexo) {
                          return DropdownMenuItem<int>(
                            value: sexo.id,
                            child: Text(sexo.descripcion),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _sexo = value);
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Sexo',
                        border: const OutlineInputBorder(),
                        errorText: 'Error: ${error.toString()}',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      enabled: false,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _fechaNacimiento ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() => _fechaNacimiento = date);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha de Nacimiento',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake),
            ),
            child: Text(
              _fechaNacimiento != null
                  ? DateFormat('dd/MM/yyyy').format(_fechaNacimiento!)
                  : 'Seleccionar fecha',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatosProfesionalesTab(AsyncValue<List> gruposAsync) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Datos Profesionales',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        gruposAsync.when(
          data: (grupos) {
            print('DEBUG: Grupos loaded successfully: ${grupos.length} items');
            // Validar que el valor actual existe en la lista
            final validValue =
                _grupo != null && grupos.any((g) => g.codigo == _grupo)
                    ? _grupo
                    : null;
            if (validValue != _grupo && _grupo != null) {
              // Si el valor no es válido, actualizar a null
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => _grupo = validValue);
              });
            }

            return DropdownButtonFormField<String>(
              initialValue: validValue,
              decoration: const InputDecoration(
                labelText: 'Grupo/Categoría',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
              items: grupos.map((grupo) {
                return DropdownMenuItem<String>(
                  value: grupo.codigo,
                  child: Text('${grupo.codigo} - ${grupo.descripcion}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _grupo = value);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Seleccione un grupo';
                }
                return null;
              },
            );
          },
          loading: () {
            print('DEBUG: Grupos still loading...');
            return const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            );
          },
          error: (error, _) {
            print('DEBUG ERROR loading grupos: $error');
            return Text('Error cargando grupos: $error');
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _grupoDesde ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() => _grupoDesde = date);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'En el Grupo Desde',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              _grupoDesde != null
                  ? DateFormat('dd/MM/yyyy').format(_grupoDesde!)
                  : 'Seleccionar fecha',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _matriculaNacionalController,
                decoration: const InputDecoration(
                  labelText: 'Matrícula Nacional',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_membership),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _matriculaProvincialController,
                decoration: const InputDecoration(
                  labelText: 'Matrícula Provincial',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.card_membership),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Residente'),
          subtitle: Text(_residente
              ? 'El socio es residente'
              : 'El socio no es residente'),
          value: _residente,
          onChanged: (value) {
            setState(() => _residente = value);
          },
        ),
        if (_residente) ...[
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _fechaInicioResidencia ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _fechaInicioResidencia = date;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha Inicio Residencia',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _fechaInicioResidencia != null
                    ? DateFormat('dd/MM/yyyy').format(_fechaInicioResidencia!)
                    : 'Seleccionar fecha',
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Dropdown de categoría de residente
          ref.watch(categoriasResidenteProvider).when(
            data: (categorias) => DropdownButtonFormField<String?>(
              value: _categoriaResidente,
              decoration: const InputDecoration(
                labelText: 'Categoría Residente *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              items: categorias
                  .map((cat) => DropdownMenuItem<String?>(
                        value: cat.codigo,
                        child: Text('${cat.codigo} - ${cat.descripcion}'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _categoriaResidente = value);
              },
              validator: (value) {
                if (_residente && (value == null || value.isEmpty)) {
                  return 'Seleccione categoría';
                }
                return null;
              },
            ),
            loading: () => const TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Cargando categorías...',
                border: OutlineInputBorder(),
              ),
            ),
            error: (_, __) => const TextField(
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Error cargando categorías',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Fecha fin residencia
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _fechaFinResidencia ??
                    (_fechaInicioResidencia != null
                        ? DateTime(_fechaInicioResidencia!.year + 3, _fechaInicioResidencia!.month, _fechaInicioResidencia!.day)
                        : DateTime.now().add(const Duration(days: 365 * 3))),
                firstDate: _fechaInicioResidencia ?? DateTime(1900),
                lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
              );
              if (date != null) {
                setState(() => _fechaFinResidencia = date);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha Fin Residencia',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event_busy),
                helperText: 'Fecha estimada de finalización',
              ),
              child: Text(
                _fechaFinResidencia != null
                    ? DateFormat('dd/MM/yyyy').format(_fechaFinResidencia!)
                    : 'Seleccionar fecha (opcional)',
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _fechaIngreso ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() => _fechaIngreso = date);
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha Ingreso a SAO',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
            ),
            child: Text(
              _fechaIngreso != null
                  ? DateFormat('dd/MM/yyyy').format(_fechaIngreso!)
                  : 'Seleccionar fecha',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDomicilioContactoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Domicilio y Contacto',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _domicilioController,
          decoration: const InputDecoration(
            labelText: 'Domicilio',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.home),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _localidadController,
                decoration: const InputDecoration(
                  labelText: 'Localidad',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _codigoPostalController,
                decoration: const InputDecoration(
                  labelText: 'C.P.',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final provinciasAsync = ref.watch(provinciasProvider);
                  return provinciasAsync.when(
                    data: (provincias) {
                      // Ordenar alfabéticamente
                      final provinciasOrdenadas = provincias.toList()
                        ..sort((a, b) => a.nombre.compareTo(b.nombre));

                      final validValue = _provinciaId == null ||
                              provinciasOrdenadas
                                  .any((p) => p.id == _provinciaId)
                          ? _provinciaId
                          : null;

                      return DropdownButtonFormField<int>(
                        initialValue: validValue,
                        decoration: const InputDecoration(
                          labelText: 'Provincia',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        items: provinciasOrdenadas.map((provincia) {
                          return DropdownMenuItem<int>(
                            value: provincia.id,
                            child: Text(provincia.nombre),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _provinciaId = value);
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Provincia',
                        border: const OutlineInputBorder(),
                        errorText: 'Error cargando provincias',
                        prefixIcon: const Icon(Icons.location_city),
                      ),
                      enabled: false,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final paisesAsync = ref.watch(paisesProvider);
                  return paisesAsync.when(
                    data: (paises) {
                      // Ordenar alfabéticamente
                      final paisesOrdenados = paises.toList()
                        ..sort((a, b) => a.nombre.compareTo(b.nombre));

                      final validValue = _paisId == null ||
                              paisesOrdenados.any((p) => p.id == _paisId)
                          ? _paisId
                          : null;

                      return DropdownButtonFormField<int>(
                        initialValue: validValue,
                        decoration: const InputDecoration(
                          labelText: 'País',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.public),
                        ),
                        items: paisesOrdenados.map((pais) {
                          return DropdownMenuItem<int>(
                            value: pais.id,
                            child: Text(pais.nombre),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _paisId = value);
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => TextFormField(
                      decoration: InputDecoration(
                        labelText: 'País',
                        border: const OutlineInputBorder(),
                        errorText: 'Error cargando países',
                        prefixIcon: const Icon(Icons.public),
                      ),
                      enabled: false,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        const Text(
          'Contacto',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _telefonoSecundarioController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono Secundario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _celularController,
          decoration: const InputDecoration(
            labelText: 'Celular',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.smartphone),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value != null && value.isNotEmpty && !value.contains('@')) {
              return 'Email inválido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailAlternativoController,
          decoration: const InputDecoration(
            labelText: 'Email Alternativo',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value != null && value.isNotEmpty && !value.contains('@')) {
              return 'Email inválido';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDebitoAutomaticoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Débito Automático',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Adherido a Débito Automático'),
          subtitle: Text(_adheridoDebito
              ? 'El socio está adherido al débito automático'
              : 'El socio no está adherido'),
          value: _adheridoDebito,
          onChanged: (value) {
            setState(() => _adheridoDebito = value);
          },
        ),
        if (_adheridoDebito) ...[
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, child) {
              final tarjetasAsync = ref.watch(tarjetasProvider);

              return tarjetasAsync.when(
                data: (tarjetas) {
                  return DropdownButtonFormField<int>(
                    initialValue: _tarjetaId,
                    decoration: const InputDecoration(
                      labelText: 'Tarjeta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card),
                    ),
                    items: tarjetas.map((tarjeta) {
                      return DropdownMenuItem<int>(
                        value: tarjeta.id,
                        child: Text(tarjeta.descripcion),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _tarjetaId = value);
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Seleccione una tarjeta';
                      }
                      return null;
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Error cargando tarjetas: $error'),
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _numeroTarjetaController,
            decoration: const InputDecoration(
              labelText: 'Número de Tarjeta',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.credit_card),
              hintText: '16 dígitos',
            ),
            keyboardType: TextInputType.number,
            maxLength: 16,
            validator: (value) {
              if (value != null && value.isNotEmpty && value.length != 16) {
                return 'Debe tener 16 dígitos';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _vencimientoTarjeta ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (date != null) {
                setState(() => _vencimientoTarjeta = date);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Vencimiento Tarjeta',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.date_range),
              ),
              child: Text(
                _vencimientoTarjeta != null
                    ? DateFormat('MM/yy').format(_vencimientoTarjeta!)
                    : 'Seleccionar fecha',
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _debitarDesde ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _debitarDesde = date);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Debitar Desde',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _debitarDesde != null
                    ? DateFormat('dd/MM/yyyy').format(_debitarDesde!)
                    : 'Seleccionar fecha',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConceptosTab() {
    if (widget.socioId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Debe guardar el socio antes de agregar conceptos',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final conceptosAsync =
        ref.watch(conceptosSocioActivosProvider(widget.socioId!));

    return conceptosAsync.when(
      data: (conceptos) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Conceptos Habituales',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () => _showAgregarConceptoDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar Concepto'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (conceptos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No hay conceptos asignados',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ...conceptos.map((concepto) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(concepto.concepto),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (concepto.fechaAlta != null)
                          Text(
                              'Alta: ${DateFormat('dd/MM/yyyy').format(concepto.fechaAlta!)}'),
                        if (concepto.importe != null)
                          Text(
                              'Importe: \$${concepto.importe!.toStringAsFixed(2)}'),
                      ],
                    ),
                    trailing: ref.read(userRoleProvider).esAdministrador
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.orange),
                                tooltip: 'Dar de baja',
                                onPressed: () => _darDeBajaConcepto(concepto),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Eliminar',
                                onPressed: () => _eliminarConcepto(concepto),
                              ),
                            ],
                          )
                        : null,
                  ),
                )),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildObservacionesTab() {
    if (widget.socioId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Debe guardar el socio antes de agregar observaciones',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final observacionesAsync =
        ref.watch(observacionesSocioProvider(widget.socioId!));

    return observacionesAsync.when(
      data: (observaciones) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Observaciones',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () => _showAgregarObservacionDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Nueva Observación'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (observaciones.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No hay observaciones registradas',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ...observaciones.map((obs) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM').format(obs.fecha),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    title: Text(obs.observacion),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy HH:mm').format(obs.fecha)}${obs.usuario != null ? ' - ${obs.usuario}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: ref.read(userRoleProvider).esAdministrador
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar',
                            onPressed: () => _eliminarObservacion(obs),
                          )
                        : null,
                  ),
                )),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Future<void> _showAgregarConceptoDialog() async {
    Concepto? selectedConcepto;
    final importeController = TextEditingController();
    DateTime? fechaAlta;
    DateTime? fechaVigencia;

    // Cargar conceptos disponibles
    final conceptosAsync = ref.read(conceptosProvider);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar Concepto'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo de búsqueda de concepto
                Consumer(
                  builder: (context, ref, child) {
                    final conceptosState = ref.watch(conceptosProvider);

                    return conceptosState.when(
                      data: (conceptos) => InkWell(
                        onTap: () async {
                          final concepto = await showDialog<Concepto>(
                            context: context,
                            builder: (context) =>
                                ConceptoSearchDialog(conceptos: conceptos),
                          );
                          if (concepto != null) {
                            setState(() {
                              selectedConcepto = concepto;
                              // Pre-rellenar importe si el concepto tiene uno definido
                              if (concepto.importe != null) {
                                importeController.text =
                                    concepto.importe!.toStringAsFixed(2);
                              }
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Concepto *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.receipt_long),
                            suffixIcon: Icon(Icons.search),
                          ),
                          child: Text(
                            selectedConcepto != null
                                ? '${selectedConcepto!.concepto} - ${selectedConcepto!.descripcion}'
                                : 'Seleccionar concepto',
                            style: TextStyle(
                              color: selectedConcepto != null
                                  ? Colors.black
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      loading: () => const InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Concepto *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.receipt_long),
                        ),
                        child: LinearProgressIndicator(),
                      ),
                      error: (error, _) => InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Concepto *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.receipt_long),
                          errorText: 'Error cargando conceptos',
                        ),
                        child: Text('Error: $error'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: importeController,
                  decoration: const InputDecoration(
                    labelText: 'Importe',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: fechaAlta ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => fechaAlta = date);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha Alta',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      fechaAlta != null
                          ? DateFormat('dd/MM/yyyy').format(fechaAlta!)
                          : 'Seleccionar fecha',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedConcepto == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Seleccione un concepto')),
                  );
                  return;
                }

                final concepto = ConceptoSocio(
                  socioId: widget.socioId!,
                  concepto: selectedConcepto!.concepto,
                  fechaAlta: fechaAlta ?? DateTime.now(),
                  fechaVigencia: fechaVigencia,
                  importe: importeController.text.isEmpty
                      ? null
                      : double.tryParse(importeController.text),
                );

                try {
                  await ref
                      .read(conceptosSocioNotifierProvider.notifier)
                      .agregarConcepto(concepto);

                  ref.invalidate(
                      conceptosSocioActivosProvider(widget.socioId!));

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Concepto agregado')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAgregarObservacionDialog() async {
    final observacionController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Observación'),
        content: SizedBox(
          width: 400,
          child: TextFormField(
            controller: observacionController,
            decoration: const InputDecoration(
              labelText: 'Observación *',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (observacionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese una observación')),
                );
                return;
              }

              final observacion = ObservacionSocio(
                socioId: widget.socioId!,
                fecha: DateTime.now(),
                observacion: observacionController.text.trim(),
                usuario: ref.read(currentUserProvider)?.email,
              );

              try {
                await ref
                    .read(observacionesSocioNotifierProvider.notifier)
                    .agregarObservacion(observacion);

                ref.invalidate(observacionesSocioProvider(widget.socioId!));

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Observación agregada')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _darDeBajaConcepto(ConceptoSocio concepto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar baja'),
        content: Text('¿Dar de baja el concepto ${concepto.concepto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dar de Baja'),
          ),
        ],
      ),
    );

    if (confirm == true && concepto.id != null) {
      try {
        await ref
            .read(conceptosSocioNotifierProvider.notifier)
            .darDeBajaConcepto(concepto.id!);
        ref.invalidate(conceptosSocioActivosProvider(widget.socioId!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Concepto dado de baja')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _eliminarConcepto(ConceptoSocio concepto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content:
            Text('¿Eliminar permanentemente el concepto ${concepto.concepto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && concepto.id != null) {
      try {
        await ref
            .read(conceptosSocioNotifierProvider.notifier)
            .eliminarConcepto(concepto.id!);
        ref.invalidate(conceptosSocioActivosProvider(widget.socioId!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Concepto eliminado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _eliminarObservacion(ObservacionSocio obs) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Eliminar esta observación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && obs.id != null) {
      try {
        await ref
            .read(observacionesSocioNotifierProvider.notifier)
            .eliminarObservacion(obs.id!);
        ref.invalidate(observacionesSocioProvider(widget.socioId!));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Observación eliminada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => context.go('/socios'),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed:
                _isLoading ? null : () => _saveSocio(closeAfterSave: false),
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed:
                _isLoading ? null : () => _saveSocio(closeAfterSave: true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar y Cerrar'),
          ),
        ],
      ),
    );
  }
}
