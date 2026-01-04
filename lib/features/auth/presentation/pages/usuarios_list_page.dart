import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/usuario_model.dart';
import '../providers/usuarios_provider.dart';

/// Página de lista de usuarios (solo para administradores)
class UsuariosListPage extends ConsumerWidget {
  const UsuariosListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(usuariosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Ir al inicio',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/usuarios/new'),
            tooltip: 'Nuevo Usuario',
          ),
        ],
      ),
      body: usuariosAsync.when(
        data: (usuarios) {
          if (usuarios.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay usuarios registrados',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              return _buildUsuarioCard(context, ref, usuario);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsuarioCard(
      BuildContext context, WidgetRef ref, Usuario usuario) {
    Color rolColor;
    switch (usuario.rol.name) {
      case 'administrador':
        rolColor = Colors.red;
        break;
      case 'contable':
        rolColor = Colors.blue;
        break;
      default:
        rolColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: usuario.activo ? rolColor : Colors.grey,
          child: Icon(
            Icons.person,
            color: Colors.white,
          ),
        ),
        title: Text(
          usuario.nombreCompleto,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: usuario.activo ? null : TextDecoration.lineThrough,
            color: usuario.activo ? null : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(usuario.email),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    usuario.rol.displayName,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: rolColor,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                if (!usuario.activo)
                  const Chip(
                    label: Text('INACTIVO', style: TextStyle(fontSize: 10)),
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: usuario.activo,
              onChanged: (value) async {
                try {
                  await ref
                      .read(usuariosNotifierProvider.notifier)
                      .toggleActivo(usuario.id, value);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(value
                            ? 'Usuario activado'
                            : 'Usuario desactivado'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.go('/usuarios/${usuario.id}'),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
