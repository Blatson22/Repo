/// Modelo de datos de un Producto (espejo de la API del backend).
class Producto {
  final int id;
  final String nombre;
  final String descripcion;
  final double precio;
  final int stock;
  final String categoria;

  const Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.stock,
    required this.categoria,
  });

  /// Construye un [Producto] a partir del JSON devuelto por la API.
  factory Producto.fromJson(Map<String, dynamic> j) => Producto(
        id: (j['id'] as num).toInt(),
        nombre: (j['nombre'] as String? ?? ''),
        descripcion: (j['descripcion'] as String? ?? ''),
        precio: (j['precio'] as num? ?? 0).toDouble(),
        stock: (j['stock'] as num? ?? 0).toInt(),
        categoria: (j['categoria'] as String? ?? ''),
      );

  /// Representación amigable de las existencias.
  String get stockTexto => stock == 0 ? 'sin stock' : 'stock: $stock';
}