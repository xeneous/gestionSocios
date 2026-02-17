import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/profesionales_provider.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';

class CobranzasSelectProfesionalPage extends ConsumerStatefulWidget {
  const CobranzasSelectProfesionalPage({super.key});

  @override
  ConsumerState<CobranzasSelectProfesionalPage> createState() =>
      _CobranzasSelectProfesionalPageState();
}

class _CobranzasSelectProfesionalPageState
    extends ConsumerState<CobranzasSelectProfesionalPage> {
  final _apellidoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();
  ProfesionalesSearchParams? _currentSearch;

  @override
  void dispose() {
    _apellidoController.dispose();
    _nombreController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() {
      _currentSearch = ProfesionalesSearchParams(
        apellido: _apellidoController.text.trim().isNotEmpty
            ? _apellidoController.text.trim()
            : null,
        nombre: _nombreController.text.trim().isNotEmpty
            ? _nombreController.text.trim()
            : null,
        numeroDocumento: _dniController.text.trim().isNotEmpty
            ? _dniController.text.trim()
            : null,
        soloActivos: true,
      );
    });
  }

  void _clearSearch() {
    _apellidoController.clear();
    _nombreController.clear();
    _dniController.clear();
    setState(() => _currentSearch = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobranzas Profesionales - Seleccionar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Inicio',
          ),
        ],
      ),
      drawer: AppDrawer(currentRoute: '/cobranzas-profesionales'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Seleccione un profesional para registrar cobranzas',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _apellidoController,
                            decoration: const InputDecoration(
                              labelText: 'Apellido',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _dniController,
                            decoration: const InputDecoration(
                              labelText: 'DNI',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.credit_card),
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _performSearch(),
                          ),
                        ),
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: _performSearch,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _currentSearch == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Utilice los filtros para buscar profesionales',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _buildResultados(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultados() {
    final profesionalesAsync =
        ref.watch(profesionalesSearchProvider(_currentSearch!));

    return profesionalesAsync.when(
      data: (profesionales) {
        if (profesionales.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No se encontraron profesionales'),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${profesionales.length} profesional(es) encontrado(s) - Haga clic para cobrar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: profesionales.length,
                itemBuilder: (context, index) {
                  final profesional = profesionales[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          profesional.apellido[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        profesional.nombreCompleto,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (profesional.numeroDocumento != null)
                            Text('DNI: ${profesional.numeroDocumento}'),
                          if (profesional.email != null)
                            Text('Email: ${profesional.email}'),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.green),
                      onTap: () =>
                          context.go('/cobranzas-profesionales/${profesional.id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}
