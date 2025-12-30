import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Widget de prueba para depurar la carga de conceptos
/// Agregar esto temporalmente a alguna pantalla para ver qué está pasando
class ConceptosDebugWidget extends ConsumerWidget {
  const ConceptosDebugWidget({super.key});

  Future<void> _testDirectQuery() async {
    try {
      print('\n🧪 === TEST DIRECTO DE CONCEPTOS ===');
      
      final supabase = Supabase.instance.client;
      
      print('1️⃣ Testing .select() sin parámetros...');
      final response1 = await supabase.from('conceptos').select();
      print('   Resultado: ${response1.length} registros');
      print('   Tipo: ${response1.runtimeType}');
      if (response1.isNotEmpty) {
        print('   Primer registro: ${response1.first}');
      }
      
      print('\n2️⃣ Testing .select() con columnas específicas...');
      final response2 = await supabase
          .from('conceptos')
          .select('id, concepto, descripcion, importe');
      print('   Resultado: ${response2.length} registros');
      if (response2.isNotEmpty) {
        print('   Primer registro: ${response2.first}');
      }
      
      print('\n3️⃣ Testing con .count()...');
      final count = await supabase
          .from('conceptos')
          .select()
          .count(CountOption.exact);
      print('   Total: $count registros');
      
      print('\n✅ Test completado\n');
    } catch (e, stack) {
      print('\n❌ Error en test: $e');
      print('Stack: $stack\n');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔍 Debug: Conceptos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testDirectQuery,
              child: const Text('Ejecutar Test Directo'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Revisa la consola de Flutter para ver los resultados',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
