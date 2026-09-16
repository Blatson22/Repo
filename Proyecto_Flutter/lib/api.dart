// Cliente de red para la API de inventario.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiService {
  final http.Client _client = http.Client();
  static const Map<String, String> _jsonHeaders = {'content-type': 'application/json'};

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');
  Uri _uriQuery(String path, Map<String, String>? params) {
    final uri = Uri.parse('$apiBaseUrl$path');
    if (params == null || params.isEmpty) return uri;
    return uri.replace(queryParameters: params);
  }

  /// GET  /api/v1/productos  (con opción de búsqueda)
  Future<List<Producto>> listar({String? buscar}) async {
    final termino = buscar?.trim();
    final query = termino != null && termino.isNotEmpty
        ? '?buscar=${Uri.encodeQueryComponent(termino)}'
        : '';
    final resp = await _client.get(_uri('/api/v1/productos$query'));
    _verificar(resp);
    final data = jsonDecode(utf8.decode(resp.bodyBytes));
    final lista = <Producto>[];
    for (final entrada in data as List) {
      lista.add(Producto.fromJson(entrada as Map<String, dynamic>));
    }
    return lista;
  }

  /// POST /api/v1/productos
  Future<Producto> crear(Map<String, dynamic> datos) async {
    final resp = await _client.post(
      _uri('/api/v1/productos'),
      headers: _jsonHeaders,
      body: jsonEncode(datos),
    );
    _verificar(resp);
    return Producto.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
  }

  /// PATCH /api/v1/productos/{id}
  Future<Producto> actualizar(int id, Map<String, dynamic> datos) async {
    final resp = await _client.patch(
      _uri('/api/v1/productos/$id'),
      headers: _jsonHeaders,
      body: jsonEncode(datos),
    );
    _verificar(resp);
    return Producto.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
  }

  /// DELETE /api/v1/productos/{id}
  Future<void> eliminar(int id) async {
    final resp = await _client.delete(_uri('/api/v1/productos/$id'));
    _verificar(resp);
  }

  // ---- Documentos (compras / ventas / despachos / ajustes) ----

  /// GET /api/v1/documentos
  Future<ListaDocumentos> listarDocumentos({String? tipo}) async {
    final params = <String, String>{};
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    final resp = await _client.get(_uriQuery('/api/v1/documentos', params));
    _verificar(resp);
    return ListaDocumentos.fromJson(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
  }

  /// POST /api/v1/documentos
  Future<DocumentoCreado> crearDocumento({
    required String tipo,
    String folio = '',
    DateTime? fecha,
    String notas = '',
    required List<Map<String, dynamic>> lineas,
  }) async {
    final body = <String, dynamic>{
      'tipo': tipo,
      'folio': folio,
      'fecha': fecha?.toIso8601String(),
      'notas': notas,
      'lineas': lineas,
    };
    final resp = await _client.post(
      _uri('/api/v1/documentos'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    _verificar(resp);
    return DocumentoCreado.fromJson(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
  }

  /// DELETE /api/v1/documentos/{id}
  Future<void> eliminarDocumento(int id) async {
    final resp = await _client.delete(_uri('/api/v1/documentos/$id'));
    _verificar(resp);
  }

  // ---- Reportes ----

  /// GET /api/v1/reportes/resumen
  Future<ReporteResumen> obtenerResumen() async {
    final resp = await _client.get(_uri('/api/v1/reportes/resumen'));
    _verificar(resp);
    return ReporteResumen.fromJson(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
  }

  /// GET /api/v1/reportes/movimientos
  Future<List<MovimientoReporte>> obtenerMovimientos(
      {int? productoId, String? tipo}) async {
    final params = <String, String>{};
    if (productoId != null) params['producto_id'] = '$productoId';
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    final resp = await _client.get(_uriQuery('/api/v1/reportes/movimientos', params));
    _verificar(resp);
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
    return data
        .map((e) => MovimientoReporte.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/v1/reportes/existencias
  Future<List<ExistenciaReporte>> obtenerExistencias() async {
    final resp = await _client.get(_uri('/api/v1/reportes/existencias'));
    _verificar(resp);
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
    return data
        .map((e) => ExistenciaReporte.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/v1/reportes/top
  Future<List<ProductoTop>> obtenerTop(String tipo, {int limit = 10}) async {
    final resp = await _client.get(
        _uriQuery('/api/v1/reportes/top', {'tipo': tipo, 'limit': '$limit'}));
    _verificar(resp);
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
    return data
        .map((e) => ProductoTop.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Exporta un reporte y devuelve los bytes del archivo.
  Future<List<int>> exportarReporte(
      {required String reporte,
      required String formato,
      String? tipo}) async {
    final params = <String, String>{'reporte': reporte, 'formato': formato};
    if (tipo != null && tipo.isNotEmpty) params['tipo'] = tipo;
    final resp = await _client.get(_uriQuery('/api/v1/exportar/reportes', params));
    _verificar(resp);
    return resp.bodyBytes;
  }

  /// Importa un inventario desde un archivo Excel (.xlsx).
  Future<ResultadoImportacion> importarInventario(String rutaArchivo) async {
    final archivo = File(rutaArchivo);
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/v1/productos/importar'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', archivo.path),
    );
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    _verificar(resp);
    return ResultadoImportacion.fromJson(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
  }

  /// Pide al backend un mapeo de columnas al esquema canónico (usa IA).
  Future<PreviewImportacion> importarPreview(String rutaArchivo) async {
    final archivo = File(rutaArchivo);
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/v1/productos/import/preview'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', archivo.path),
    );
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    _verificar(resp);
    return PreviewImportacion.fromJson(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
  }

  /// Importa el archivo usando el mapeo que el usuario confirmó/ajustó.
  Future<ResultadoImportacion> importarCommit(
      String rutaArchivo, Map<String, String?> mapeo) async {
    final archivo = File(rutaArchivo);
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/v1/productos/import/commit'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', archivo.path),
    );
    request.fields['mapeo'] = jsonEncode(mapeo);
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    _verificar(resp);
    return ResultadoImportacion.fromJson(
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
  }

  void _verificar(http.Response resp) {
    if (resp.statusCode >= 400) {
      throw StateError('Error HTTP ${resp.statusCode}: ${utf8.decode(resp.bodyBytes)}');
    }
  }

  void close() => _client.close();
}