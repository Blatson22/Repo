import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../models.dart';

/// Pantalla de reportes: resumen general, movimientos, existencias y top.
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final ApiService _api = ApiService();
  bool _cargando = true;
  String _error = '';
  ReporteResumen? _resumen;
  List<MovimientoReporte> _movimientos = [];
  List<ExistenciaReporte> _existencias = [];
  List<ProductoTop> _topVentas = [];
  List<ProductoTop> _topDespachos = [];
  String? _exportando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = '';
    });
    try {
      final resumen = await _api.obtenerResumen();
      final mov = await _api.obtenerMovimientos();
      final exist = await _api.obtenerExistencias();
      final topV = await _api.obtenerTop(TiposDocumento.venta);
      final topD = await _api.obtenerTop(TiposDocumento.despacho);
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _movimientos = mov;
        _existencias = exist;
        _topVentas = topV;
        _topDespachos = topD;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar los reportes: $e';
      });
    }
  }

  Future<void> _exportar(String formato) async {
    if (_exportando != null) return;
    setState(() => _exportando = formato);
    final ext = switch (formato) {
      'xlsx' => 'xlsx',
      'pdf' => 'pdf',
      _ => 'csv',
    };
    try {
      final bytes = await _api.exportarReporte(
          reporte: 'resumen', formato: formato);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/reporte.$ext');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: _mime(ext))],
        subject: 'Reporte de inventario',
        text: 'Reporte general del inventario.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
    } finally {
      if (mounted) setState(() => _exportando = null);
    }
  }

  String _mime(String ext) => switch (ext) {
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'pdf' => 'application/pdf',
        _ => 'text/csv',
      };

  String _moneda(double v) =>
      '\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error, textAlign: TextAlign.center),
                  ),
                )
              : _resumen == null
                  ? const Center(child: Text('Sin datos'))
                  : _contenido(context),
    );
  }

  Widget _contenido(BuildContext context) {
    final r = _resumen!;
    return Column(
      children: [
        _botonesExportar(),
        const Divider(height: 1),
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Resumen'),
                    Tab(text: 'Movimientos'),
                    Tab(text: 'Existencias'),
                    Tab(text: 'Top'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _resumenTab(r),
                      _movimientosTab(),
                      _existenciasTab(),
                      _topTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _botonesExportar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Exportar resumen:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              _botonExportar('CSV', 'csv'),
              const SizedBox(width: 8),
              _botonExportar('Excel', 'xlsx'),
              const SizedBox(width: 8),
              _botonExportar('PDF', 'pdf'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botonExportar(String etiqueta, String formato) {
    final ocupado = _exportando != null;
    return Expanded(
      child: FilledButton.tonalIcon(
        onPressed: ocupado ? null : () => _exportar(formato),
        icon: _exportando == formato
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.download),
        label: Text(etiqueta),
      ),
    );
  }

  Widget _tarjeta(String titulo, String valor, {IconData icono = Icons.trending_up}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(titulo,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _resumenTab(ReporteResumen r) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Valorización', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _tarjeta('Compras', _moneda(r.totalCompras), icono: Icons.shopping_cart),
              _tarjeta('Ventas', _moneda(r.totalVentas), icono: Icons.point_of_sale),
              _tarjeta('Despachos', _moneda(r.totalDespachos), icono: Icons.local_shipping),
              _tarjeta('Valor del almacén', _moneda(r.valorAlmacen), icono: Icons.warehouse),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Conteos', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: [
              _tarjeta('Productos', '${r.productosCount}', icono: Icons.inventory_2),
              _tarjeta('Documentos de compra', '${r.comprasCount}'),
              _tarjeta('Documentos de venta', '${r.ventasCount}'),
              _tarjeta('Documentos de despacho', '${r.despachosCount}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _movimientosTab() {
    if (_movimientos.isEmpty) {
      return const Center(child: Text('Aún no hay movimientos.'));
    }
    return ListView.builder(
      itemCount: _movimientos.length,
      itemBuilder: (context, i) {
        final m = _movimientos[i];
        final esEntrada = m.signo > 0;
        return ListTile(
          dense: true,
          leading: Icon(
            esEntrada ? Icons.add_circle : Icons.remove_circle,
            color: esEntrada ? Colors.green : Colors.red,
          ),
          title: Text('${m.nombre} (${m.cantidad})'),
          subtitle: Text(
              '${TiposDocumento.etiqueta(m.tipo)} · ${m.fecha.toLocal().toString().substring(0, 16)}'),
          trailing: Text(
            '${esEntrada ? '+' : '-'}${_moneda(m.subtotal.toDouble())}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: esEntrada ? Colors.green : Colors.red,
            ),
          ),
        );
      },
    );
  }

  Widget _existenciasTab() {
    if (_existencias.isEmpty) {
      return const Center(child: Text('No hay productos registrados.'));
    }
    return ListView.builder(
      itemCount: _existencias.length,
      itemBuilder: (context, i) {
        final e = _existencias[i];
        return ListTile(
          leading: const Icon(Icons.inventory_2),
          title: Text(e.nombre),
          subtitle: Text(e.categoria.isNotEmpty ? e.categoria : 'General'),
          trailing: Text(
            '${e.stock} · ${_moneda(e.valor)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _topTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Top ventas', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_topVentas.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Sin ventas registradas.'))
        else
          ..._topVentas.map((p) => ListTile(
                dense: true,
                title: Text(p.nombre),
                trailing: Text('${p.totalCantidad} · ${_moneda(p.totalImporte)}'),
              )),
        const Divider(height: 24),
        const Text('Top despachos', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_topDespachos.isEmpty)
          const Padding(padding: EdgeInsets.all(8), child: Text('Sin despachos registrados.'))
        else
          ..._topDespachos.map((p) => ListTile(
                dense: true,
                title: Text(p.nombre),
                trailing: Text('${p.totalCantidad} · ${_moneda(p.totalImporte)}'),
              )),
      ],
    );
  }
}