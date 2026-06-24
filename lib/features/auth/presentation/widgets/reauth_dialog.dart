import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/unsaved_changes_provider.dart';
import '../providers/auth_provider.dart';

/// Diálogo modal que se muestra cuando se pierde la sesión (token vencido)
/// mientras hay un formulario con cambios sin guardar. Permite reingresar
/// sin navegar, preservando el estado del formulario que quedó atrás.
class ReauthDialog extends ConsumerStatefulWidget {
  final String? email;

  const ReauthDialog({super.key, this.email});

  @override
  ConsumerState<ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends ConsumerState<ReauthDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(text: widget.email);
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reingresar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No se pudo reingresar: $e';
        });
      }
    }
  }

  void _salirSinGuardar() {
    ref.read(unsavedChangesProvider.notifier).set(false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Sesión expirada'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Su sesión expiró. Vuelva a ingresar para continuar sin '
                'perder lo que estaba cargando.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                autofocus: true,
                onFieldSubmitted: (_) => _isLoading ? null : _reingresar(),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Requerido' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _salirSinGuardar,
            child: const Text('Salir sin guardar'),
          ),
          FilledButton(
            onPressed: _isLoading ? null : _reingresar,
            child: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ingresar'),
          ),
        ],
      ),
    );
  }
}
