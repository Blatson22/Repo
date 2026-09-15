// Cliente de red para la API de inventario.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiService {
  final http.Client _client = http.Client();
  static const Map<String, String> _jsonHeaders = {'content-type': 'application/json'};

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

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

  void _verificar(http.Response resp) {
    if (resp.statusCode >= 400) {
      throw StateError('Error HTTP ${resp.statusCode}: ${utf8.decode(resp.bodyBytes)}');
    }
  }

  void close() => _client.close();
}