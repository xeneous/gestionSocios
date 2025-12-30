import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/concepto_model.dart';

final conceptosProvider = FutureProvider<List<Concepto>>((ref) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('conceptos')
      .select('concepto, descripcion, entidad, modalidad, importe, grupo, activo')
      .order('concepto', ascending: true);

  return (response as List)
      .map((json) => Concepto.fromJson(json))
      .toList();
});
