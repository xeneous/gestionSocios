import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/archivo_socio_model.dart';

const _bucketName = 'socios-archivos';

/// Servicio para gestionar archivos de socios en Supabase Storage
class ArchivosService {
  final SupabaseClient _supabase;

  ArchivosService(this._supabase);

  /// Lista todos los archivos de un socio
  Future<List<ArchivoSocioModel>> listarArchivos(int socioId) async {
    final response = await _supabase
        .from('archivos_socios')
        .select('*')
        .eq('socio_id', socioId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ArchivoSocioModel.fromJson(json))
        .toList();
  }

  /// Sube un archivo a Supabase Storage y guarda los metadatos
  Future<ArchivoSocioModel> subirArchivo({
    required int socioId,
    required String nombre,
    required Uint8List bytes,
    required String tipoContenido,
    String? descripcion,
  }) async {
    // Path único en el bucket: socios/{socioId}/{timestamp}_{nombre}
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'socios/$socioId/${timestamp}_$nombre';

    // Subir a Supabase Storage
    await _supabase.storage.from(_bucketName).uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(contentType: tipoContenido),
    );

    // Guardar metadatos en la tabla
    final metadata = ArchivoSocioModel(
      socioId: socioId,
      nombre: nombre,
      storagePath: storagePath,
      tipoContenido: tipoContenido,
      tamanio: bytes.length,
      descripcion: descripcion,
    );

    final response = await _supabase
        .from('archivos_socios')
        .insert(metadata.toJson())
        .select()
        .single();

    return ArchivoSocioModel.fromJson(response);
  }

  /// Obtiene una URL firmada para descargar un archivo (válida 1 hora)
  Future<String> obtenerUrlDescarga(String storagePath) async {
    final response = await _supabase.storage
        .from(_bucketName)
        .createSignedUrl(storagePath, 3600);
    return response;
  }

  /// Elimina un archivo de Storage y sus metadatos
  Future<void> eliminarArchivo(ArchivoSocioModel archivo) async {
    // Eliminar de Storage
    await _supabase.storage
        .from(_bucketName)
        .remove([archivo.storagePath]);

    // Eliminar metadatos
    await _supabase
        .from('archivos_socios')
        .delete()
        .eq('id', archivo.id!);
  }

  /// Actualiza la descripción de un archivo
  Future<void> actualizarDescripcion(int archivoId, String descripcion) async {
    await _supabase
        .from('archivos_socios')
        .update({'descripcion': descripcion})
        .eq('id', archivoId);
  }
}

// Provider del servicio
final archivosServiceProvider = Provider<ArchivosService>((ref) {
  return ArchivosService(Supabase.instance.client);
});

// Provider para listar archivos de un socio
final archivosSocioProvider =
    FutureProvider.family<List<ArchivoSocioModel>, int>((ref, socioId) async {
  final service = ref.watch(archivosServiceProvider);
  return service.listarArchivos(socioId);
});

// Notifier para operaciones CRUD
class ArchivosNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<ArchivoSocioModel> subirArchivo({
    required int socioId,
    required String nombre,
    required Uint8List bytes,
    required String tipoContenido,
    String? descripcion,
  }) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(archivosServiceProvider);
      final archivo = await service.subirArchivo(
        socioId: socioId,
        nombre: nombre,
        bytes: bytes,
        tipoContenido: tipoContenido,
        descripcion: descripcion,
      );
      state = const AsyncData(null);
      return archivo;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> eliminarArchivo(ArchivoSocioModel archivo) async {
    state = const AsyncLoading();
    try {
      final service = ref.read(archivosServiceProvider);
      await service.eliminarArchivo(archivo);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final archivosNotifierProvider =
    NotifierProvider<ArchivosNotifier, AsyncValue<void>>(ArchivosNotifier.new);
