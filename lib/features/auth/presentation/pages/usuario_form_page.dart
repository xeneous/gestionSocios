import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/user_role.dart';
import '../providers/usuarios_provider.dart';

/// Página de formulario para crear/editar usuarios
class UsuarioFormPage extends ConsumerStatefulWidget {
  final String? usuarioId;

  const UsuarioFormPage({
    super.key,
    this.usuarioId,
  });

  @override
  ConsumerState<UsuarioFormPage> createState() => _UsuarioFormPageState();
}

class _UsuarioFormPageState extends ConsumerState<UsuarioFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;

  // State
  UserRole _rol = UserRole.usuario;
  bool _activo = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _nombreController = TextEditingController();
    _apellidoController = TextEditingController();

    if (widget.usuarioId != null) {
      _loadUsuario();
    }
  }

  Future<void> _loadUsuario() async {
    final usuario = await ref
        .read(usuarioByIdProvider(widget.usuarioId!).future);
    if (usuario != null && mounted) {
      setState(() {
        _emailController.text = usuario.email;
        _nombreController.text = usuario.nombre ?? '';
        _apellidoController.text = usuario.apellido ?? '';
        _rol = usuario.rol;
        _activo = usuario.activo;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.usuarioId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Usuario' : 'Nuevo Usuario'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Ir al inicio',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isEditing, // No se puede cambiar email
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El email es obligatorio';
                      }
                      if (!value.contains('@')) {
                        return 'Ingrese un email válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Contraseña (solo al crear)
                  if (!isEditing) ...[
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        helperText: 'Mínimo 6 caracteres',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'La contraseña es obligatoria';
                        }
                        if (value.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Nombre
                  TextFormField(
                    controller: _nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Apellido
                  TextFormField(
                    controller: _apellidoController,
                    decoration: const InputDecoration(
                      labelText: 'Apellido',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Rol
                  DropdownButtonFormField<UserRole>(
                    initialValue: _rol,
                    decoration: const InputDecoration(
                      labelText: 'Rol *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.admin_panel_settings),
                    ),
                    items: UserRole.values.map((rol) {
                      return DropdownMenuItem(
                        value: rol,
                        child: Text(rol.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _rol = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Activo (solo al editar)
                  if (isEditing)
                    Card(
                      child: SwitchListTile(
                        title: const Text('Usuario Activo'),
                        subtitle: const Text(
                            'Los usuarios inactivos no pueden acceder al sistema'),
                        value: _activo,
                        onChanged: (value) => setState(() => _activo = value),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _saveUsuario,
                          child: Text(isEditing ? 'Actualizar' : 'Crear'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _saveUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.usuarioId != null) {
        // Actualizar
        await ref.read(usuariosNotifierProvider.notifier).updateUsuario(
              widget.usuarioId!,
              nombre: _nombreController.text.isEmpty ? null : _nombreController.text,
              apellido: _apellidoController.text.isEmpty ? null : _apellidoController.text,
              rol: _rol,
              activo: _activo,
            );
      } else {
        // Crear
        await ref.read(usuariosNotifierProvider.notifier).createUsuario(
              email: _emailController.text,
              password: _passwordController.text,
              nombre: _nombreController.text.isEmpty ? null : _nombreController.text,
              apellido: _apellidoController.text.isEmpty ? null : _apellidoController.text,
              rol: _rol,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.usuarioId != null
                ? 'Usuario actualizado correctamente'
                : 'Usuario creado correctamente'),
          ),
        );
        context.go('/usuarios');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
