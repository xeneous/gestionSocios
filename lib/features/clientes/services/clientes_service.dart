import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cliente_model.dart';

class ClientesSearchParams {
  final int? codigo;
  final String? razonSocial;
  final String? cuit;
  final bool soloActivos;
  final int limit;
  final int offset;

  ClientesSearchParams({
    this.codigo,
    this.razonSocial,
    this.cuit,
    this.soloActivos = true,
    this.limit = 50,
    this.offset = 0,
  });
}

class ClientesService {
  final SupabaseClient _supabase;

  ClientesService(this._supabase);

  Future<List<Cliente>> buscarClientes(ClientesSearchParams params) async {
    var query = _supabase.from('clientes').select();

    if (params.codigo != null) {
      query = query.eq('codigo', params.codigo!);
    }

    if (params.razonSocial != null && params.razonSocial!.isNotEmpty) {
      query = query.ilike('razon_social', '%${params.razonSocial}%');
    }

    if (params.cuit != null && params.cuit!.isNotEmpty) {
      query = query.ilike('cuit', '%${params.cuit}%');
    }

    if (params.soloActivos) {
      query = query.eq('activo', 1).isFilter('fecha_baja', null);
    }

    final response = await query
        .order('razon_social', ascending: true)
        .range(params.offset, params.offset + params.limit - 1);

    return (response as List).map((json) => Cliente.fromJson(json)).toList();
  }

  Future<Cliente?> getCliente(int codigo) async {
    final response = await _supabase
        .from('clientes')
        .select()
        .eq('codigo', codigo)
        .maybeSingle();

    if (response == null) return null;
    return Cliente.fromJson(response);
  }

  Future<Cliente> crearCliente(Cliente cliente) async {
    final data = cliente.toJson();
    data['fecha'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('clientes')
        .insert(data)
        .select()
        .single();

    return Cliente.fromJson(response);
  }

  Future<Cliente> actualizarCliente(Cliente cliente) async {
    if (cliente.codigo == null) {
      throw Exception('El código del cliente es requerido para actualizar');
    }

    final response = await _supabase
        .from('clientes')
        .update(cliente.toJson())
        .eq('codigo', cliente.codigo!)
        .select()
        .single();

    return Cliente.fromJson(response);
  }

  Future<void> eliminarCliente(int codigo) async {
    await _supabase
        .from('clientes')
        .delete()
        .eq('codigo', codigo);
  }

  Future<void> darDeBajaCliente(int codigo) async {
    await _supabase
        .from('clientes')
        .update({
          'activo': 0,
          'fecha_baja': DateTime.now().toIso8601String(),
        })
        .eq('codigo', codigo);
  }

  Future<void> reactivarCliente(int codigo) async {
    await _supabase
        .from('clientes')
        .update({
          'activo': 1,
          'fecha_baja': null,
        })
        .eq('codigo', codigo);
  }

  Future<int> contarClientes({bool soloActivos = true}) async {
    var query = _supabase.from('clientes').select('codigo');

    if (soloActivos) {
      query = query.eq('activo', 1).isFilter('fecha_baja', null);
    }

    final response = await query;
    return (response as List).length;
  }
}
