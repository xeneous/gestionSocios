import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/parametro_contable_model.dart';

class ParametrosService {
  final SupabaseClient _supabase;

  ParametrosService(this._supabase);

  /// Obtiene todos los parámetros contables
  Future<List<ParametroContable>> getParametros() async {
    final response = await _supabase
        .from('parametros_contables')
        .select()
        .order('clave');

    return (response as List)
        .map((json) => ParametroContable.fromJson(json))
        .toList();
  }

  /// Obtiene un parámetro por su clave
  Future<ParametroContable?> getParametro(String clave) async {
    final response = await _supabase
        .from('parametros_contables')
        .select()
        .eq('clave', clave)
        .maybeSingle();

    if (response == null) return null;
    return ParametroContable.fromJson(response);
  }

  /// Obtiene el valor de un parámetro por su clave
  Future<String?> getValor(String clave) async {
    final parametro = await getParametro(clave);
    return parametro?.valor;
  }

  /// Obtiene el valor numérico de un parámetro (para cuentas contables)
  Future<int?> getValorNumerico(String clave) async {
    final valor = await getValor(clave);
    if (valor == null) return null;
    return int.tryParse(valor);
  }

  /// Actualiza el valor de un parámetro
  Future<void> actualizarParametro(String clave, String? valor) async {
    await _supabase
        .from('parametros_contables')
        .update({'valor': valor})
        .eq('clave', clave);
  }

  /// Crea un nuevo parámetro
  Future<ParametroContable> crearParametro(ParametroContable parametro) async {
    final response = await _supabase
        .from('parametros_contables')
        .insert(parametro.toJson())
        .select()
        .single();

    return ParametroContable.fromJson(response);
  }

  /// Obtiene las cuentas configuradas para imputación
  Future<Map<String, int?>> getCuentasImputacion() async {
    final proveedores = await getValorNumerico(ParametroContable.cuentaProveedores);
    final clientes = await getValorNumerico(ParametroContable.cuentaClientes);
    final sponsors = await getValorNumerico(ParametroContable.cuentaSponsors);

    return {
      'proveedores': proveedores,
      'clientes': clientes,
      'sponsors': sponsors,
    };
  }
}
