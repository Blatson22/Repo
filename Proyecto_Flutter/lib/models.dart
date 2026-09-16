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

  // Comparamos por `id` en vez de identidad de objeto. Esto es necesario
  // porque, por ejemplo, `DropdownButtonFormField<Producto>` compara su
  // `initialValue` contra los `items` cargados por separado; sin estos
  // overrides, dos `Producto` con el mismo id pero de distinta instancia
  // (uno de la lista principal y otro recién descargado de la API) se
  // consideran "diferentes" y el dropdown falla al no encontrar coincidencia.
  @override
  bool operator ==(Object other) => other is Producto && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Tipos de documento admitidos.
class TiposDocumento {
  static const compra = 'compra';
  static const venta = 'venta';
  static const despacho = 'despacho';
  static const ajuste = 'ajuste';
  static const lista = [compra, venta, despacho, ajuste];

  static String etiqueta(String tipo) => switch (tipo) {
        compra => 'Compra',
        venta => 'Venta',
        despacho => 'Despacho',
        ajuste => 'Ajuste',
        _ => tipo,
      };

  static int signo(String tipo) =>
      tipo == compra ? 1 : -1; // entrada / salida
}

/// Línea de detalle de un documento.
class DocumentoLinea {
  final int? id;
  final int productoId;
  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;
  final int signo;

  const DocumentoLinea({
    this.id,
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    this.signo = 1,
  });

  factory DocumentoLinea.fromJson(Map<String, dynamic> j) => DocumentoLinea(
        id: j['id'] as int?,
        productoId: (j['producto_id'] as num).toInt(),
        nombre: (j['nombre'] as String? ?? ''),
        cantidad: (j['cantidad'] as num? ?? 0).toInt(),
        precioUnitario: (j['precio_unitario'] as num? ?? 0).toDouble(),
        subtotal: (j['subtotal'] as num? ?? 0).toDouble(),
        signo: (j['signo'] as num? ?? 1).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'producto_id': productoId,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
      };

  double get valorFinal => subtotal;
}

/// Cabecera de un documento (compra / venta / despacho / ajuste).
class Documento {
  final int id;
  final String tipo;
  final String folio;
  final DateTime fecha;
  final String notas;
  final double total;
  final List<DocumentoLinea> lineas;

  const Documento({
    required this.id,
    required this.tipo,
    required this.folio,
    required this.fecha,
    required this.notas,
    required this.total,
    required this.lineas,
  });

  factory Documento.fromJson(Map<String, dynamic> j) => Documento(
        id: (j['id'] as num).toInt(),
        tipo: j['tipo'] as String,
        folio: j['folio'] as String? ?? '',
        fecha: DateTime.tryParse(j['fecha'] as String? ?? '') ?? DateTime.now(),
        notas: j['notas'] as String? ?? '',
        total: (j['total'] as num? ?? 0).toDouble(),
        lineas: (j['lineas'] as List? ?? [])
            .map((e) => DocumentoLinea.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Respuesta de listado de documentos.
class ListaDocumentos {
  final int total;
  final List<Documento> items;

  const ListaDocumentos({required this.total, required this.items});

  factory ListaDocumentos.fromJson(Map<String, dynamic> j) => ListaDocumentos(
        total: (j['total'] as num? ?? 0).toInt(),
        items: (j['items'] as List? ?? [])
            .map((e) => Documento.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Respuesta de creación de documento (incluye avisos de stock).
class DocumentoCreado {
  final Documento documento;
  final List<String> avisos;

  const DocumentoCreado({required this.documento, required this.avisos});

  factory DocumentoCreado.fromJson(Map<String, dynamic> j) => DocumentoCreado(
        documento: Documento.fromJson(j),
        avisos: (j['avisos'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Resultado del reporte de resumen.
class ReporteResumen {
  final double totalCompras;
  final double totalVentas;
  final double totalDespachos;
  final double valorAlmacen;
  final int productosCount;
  final int comprasCount;
  final int ventasCount;
  final int despachosCount;

  const ReporteResumen({
    required this.totalCompras,
    required this.totalVentas,
    required this.totalDespachos,
    required this.valorAlmacen,
    required this.productosCount,
    required this.comprasCount,
    required this.ventasCount,
    required this.despachosCount,
  });

  factory ReporteResumen.fromJson(Map<String, dynamic> j) => ReporteResumen(
        totalCompras: (j['total_compras'] as num? ?? 0).toDouble(),
        totalVentas: (j['total_ventas'] as num? ?? 0).toDouble(),
        totalDespachos: (j['total_despachos'] as num? ?? 0).toDouble(),
        valorAlmacen: (j['valor_almacen'] as num? ?? 0).toDouble(),
        productosCount: (j['productos_count'] as num? ?? 0).toInt(),
        comprasCount: (j['compras_count'] as num? ?? 0).toInt(),
        ventasCount: (j['ventas_count'] as num? ?? 0).toInt(),
        despachosCount: (j['despachos_count'] as num? ?? 0).toInt(),
      );
}

/// Fila de una serie temporal.
class SerieReporte {
  final String fecha;
  final double total;
  final int count;

  const SerieReporte({required this.fecha, required this.total, required this.count});

  factory SerieReporte.fromJson(Map<String, dynamic> j) => SerieReporte(
        fecha: j['fecha'] as String,
        total: (j['total'] as num? ?? 0).toDouble(),
        count: (j['count'] as num? ?? 0).toInt(),
      );
}

/// Producto en ranking.
class ProductoTop {
  final int productoId;
  final String nombre;
  final int totalCantidad;
  final double totalImporte;

  const ProductoTop({
    required this.productoId,
    required this.nombre,
    required this.totalCantidad,
    required this.totalImporte,
  });

  factory ProductoTop.fromJson(Map<String, dynamic> j) => ProductoTop(
        productoId: (j['producto_id'] as num).toInt(),
        nombre: j['nombre'] as String,
        totalCantidad: (j['total_cantidad'] as num? ?? 0).toInt(),
        totalImporte: (j['total_importe'] as num? ?? 0).toDouble(),
      );
}

/// Movimiento individual de stock.
class MovimientoReporte {
  final int documentoId;
  final String folio;
  final String tipo;
  final DateTime fecha;
  final int productoId;
  final String nombre;
  final int cantidad;
  final int signo;
  final double precioUnitario;
  final double subtotal;

  const MovimientoReporte({
    required this.documentoId,
    required this.folio,
    required this.tipo,
    required this.fecha,
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.signo,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory MovimientoReporte.fromJson(Map<String, dynamic> j) => MovimientoReporte(
        documentoId: (j['documento_id'] as num).toInt(),
        folio: j['folio'] as String? ?? '',
        tipo: j['tipo'] as String,
        fecha: DateTime.tryParse(j['fecha'] as String? ?? '') ?? DateTime.now(),
        productoId: (j['producto_id'] as num).toInt(),
        nombre: j['nombre'] as String,
        cantidad: (j['cantidad'] as num? ?? 0).toInt(),
        signo: (j['signo'] as num? ?? 1).toInt(),
        precioUnitario: (j['precio_unitario'] as num? ?? 0).toDouble(),
        subtotal: (j['subtotal'] as num? ?? 0).toDouble(),
      );

  double get importeEfectivo => subtotal;
}

/// Existencia actual de un producto.
class ExistenciaReporte {
  final int productoId;
  final String nombre;
  final String categoria;
  final int stock;
  final double precio;
  final double valor;

  const ExistenciaReporte({
    required this.productoId,
    required this.nombre,
    required this.categoria,
    required this.stock,
    required this.precio,
    required this.valor,
  });

  factory ExistenciaReporte.fromJson(Map<String, dynamic> j) => ExistenciaReporte(
        productoId: (j['producto_id'] as num).toInt(),
        nombre: j['nombre'] as String,
        categoria: j['categoria'] as String? ?? '',
        stock: (j['stock'] as num? ?? 0).toInt(),
        precio: (j['precio'] as num? ?? 0).toDouble(),
        valor: (j['valor'] as num? ?? 0).toDouble(),
      );
}

/// Error por fila durante la importación de inventario.
class ErrorImportacion {
  final int fila;
  final String error;

  const ErrorImportacion({required this.fila, required this.error});

  factory ErrorImportacion.fromJson(Map<String, dynamic> j) => ErrorImportacion(
        fila: (j['fila'] as num).toInt(),
        error: j['error'] as String? ?? '',
      );
}

/// Resultado de importar un archivo Excel de inventario.
class ResultadoImportacion {
  final int importados;
  final List<ErrorImportacion> errores;
  final int totalFilas;

  const ResultadoImportacion({
    required this.importados,
    required this.errores,
    required this.totalFilas,
  });

  factory ResultadoImportacion.fromJson(Map<String, dynamic> j) =>
      ResultadoImportacion(
        importados: (j['importados'] as num? ?? 0).toInt(),
        totalFilas: (j['total_filas'] as num? ?? 0).toInt(),
        errores: ((j['errores'] as List? ?? [])
                .map((e) => ErrorImportacion.fromJson(e as Map<String, dynamic>))
                .toList()),
      );
}

/// Vista previa de importación: encabezados, mapeo propuesto y muestras.
class PreviewImportacion {
  final List<String> encabezados;
  final Map<String, String?> mapeo;
  final List<List<dynamic>> muestras;

  const PreviewImportacion({
    required this.encabezados,
    required this.mapeo,
    required this.muestras,
  });

  factory PreviewImportacion.fromJson(Map<String, dynamic> j) {
    const campos = ['nombre', 'precio', 'stock', 'categoria', 'descripcion', 'codigo'];
    final mapaRaw = j['mapeo'] as Map<String, dynamic>? ?? {};
    final mapeo = <String, String?>{};
    mapaRaw.forEach((k, v) {
      final c = v as String?;
      mapeo[k] = (c != null && campos.contains(c)) ? c : null;
    });
    return PreviewImportacion(
      encabezados: (j['encabezados'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      mapeo: mapeo,
      muestras: (j['muestras'] as List? ?? [])
          .map((e) => (e as List).toList())
          .toList(),
    );
  }
}