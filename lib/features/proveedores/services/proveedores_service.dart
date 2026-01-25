import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/proveedor_model.dart';

class ProveedoresSearchParams {
  final int? codigo;
  final String? razonSocial;
  final String? cuit;
  final bool soloActivos;
  final int limit;
  final int offset;

  ProveedoresSearchParams({
    this.codigo,
    this.razonSocial,
    this.cuit,
    this.soloActivos = true,
    this.limit = 50,
    this.offset = 0,
  });
}

class ProveedoresService {
  final SupabaseClient _supabase;

  ProveedoresService(this._supabase);

  Future<List<Proveedor>> buscarProveedores(ProveedoresSearchParams params) async {
    var query = _supabase.from('proveedores').select();

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

    return (response as List).map((json) => Proveedor.fromJson(json)).toList();
  }

  Future<Proveedor?> getProveedor(int codigo) async {
    final response = await _supabase
        .from('proveedores')
        .select()
        .eq('codigo', codigo)
        .maybeSingle();

    if (response == null) return null;
    return Proveedor.fromJson(response);
  }

  Future<Proveedor> crearProveedor(Proveedor proveedor) async {
    final data = proveedor.toJson();
    data['fecha'] = DateTime.now().toIso8601String();

    final response = await _supabase
        .from('proveedores')
        .insert(data)
        .select()
        .single();

    return Proveedor.fromJson(response);
  }

  Future<Proveedor> actualizarProveedor(Proveedor proveedor) async {
    if (proveedor.codigo == null) {
      throw Exception('El código del proveedor es requerido para actualizar');
    }

    final response = await _supabase
        .from('proveedores')
        .update(proveedor.toJson())
        .eq('codigo', proveedor.codigo!)
        .select()
        .single();

    return Proveedor.fromJson(response);
  }

  Future<void> eliminarProveedor(int codigo) async {
    await _supabase
        .from('proveedores')
        .delete()
        .eq('codigo', codigo);
  }

  Future<void> darDeBajaProveedor(int codigo) async {
    await _supabase
        .from('proveedores')
        .update({
          'activo': 0,
          'fecha_baja': DateTime.now().toIso8601String(),
        })
        .eq('codigo', codigo);
  }

  Future<void> reactivarProveedor(int codigo) async {
    await _supabase
        .from('proveedores')
        .update({
          'activo': 1,
          'fecha_baja': null,
        })
        .eq('codigo', codigo);
  }

  Future<int> contarProveedores({bool soloActivos = true}) async {
    var query = _supabase.from('proveedores').select('codigo');

    if (soloActivos) {
      query = query.eq('activo', 1).isFilter('fecha_baja', null);
    }

    final response = await query;
    return (response as List).length;
  }
}
