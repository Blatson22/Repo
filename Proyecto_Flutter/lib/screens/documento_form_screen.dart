import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';

/// Formulario para registrar un documento con varias líneas.
class DocumentoFormScreen extends StatefulWidget {
  const DocumentoFormScreen({super.key});

  @override
  State<DocumentoFormScreen> createState() => _DocumentoFormScreenState();
}

class _LineaDraft {
  Producto? producto;
  int cantidad = 1;
  double precio = 0;
}

class _DocumentoFormScreenState extends State<DocumentoFormScreen> {
  final ApiService _api = ApiService();
  final _folio = TextEditingController();
  final _notas = TextEditingController();
  String _tipo = TiposDocumento.compra;
  bool _guardando = false;
  bool _cargando = true;
  String _error = '';
  List<Producto> _productos = [];
  final List<_LineaDraft> _lineas = [_LineaDraft()];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  @override
  void dispose() {
    _folio.dispose();
    _notas.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    try {
      final lista = await _api.listar();
      if (!mounted) return;
      setState(() {
        _productos = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los productos: $e';
      });
    }
  }

  void _agregarLinea() {
    setState(() => _lineas.add(_LineaDraft()));
  }

  void _quitarLinea(int index) {
    setState(() => _lineas.removeAt(index));
  }

  double get _totalCalculado => _lineas.fold(
      0.0, (acc, l) => acc + l.cantidad * l.precio);

  Future<void> _guardar() async {
    final validadas = <_LineaDraft>[];
    for (final l in _lineas) {
      if (l.producto == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Selecciona el producto de cada línea.')));
        return;
      }
      if (l.cantidad <= 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('La cantidad debe ser mayor a 0.')));
        return;
      }
      validadas.add(l);
    }

    setState(() => _guardando = true);
    try {
      final lineasJson = validadas
          .map((l) => {
                'producto_id': l.producto!.id,
                'cantidad': l.cantidad,
                'precio_unitario': l.precio,
              })
          .toList();
      final resultado = await _api.crearDocumento(
        tipo: _tipo,
        folio: _folio.text.trim(),
        notas: _notas.text.trim(),
        lineas: lineasJson,
      );
      if (!mounted) return;
      if (resultado.avisos.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Avisos de stock'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: resultado.avisos
                  .map((a) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(a),
                      ))
                  .toList(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar documento')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : _formulario(),
    );
  }

  Widget _formulario() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo de documento'),
          items: TiposDocumento.lista
              .map((t) =>
                  DropdownMenuItem(value: t, child: Text(TiposDocumento.etiqueta(t))))
              .toList(),
          onChanged: (v) => setState(() => _tipo = v!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _folio,
          decoration: const InputDecoration(labelText: 'Folio (opcional)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notas,
          decoration: const InputDecoration(labelText: 'Notas (opcional)'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Text('Líneas', style: TextStyle(fontWeight: FontWeight.bold))),
            IconButton(
              tooltip: 'Añadir línea',
              icon: const Icon(Icons.add),
              onPressed: _agregarLinea,
            ),
          ],
        ),
        ..._lineas.asMap().entries.map((e) => _tarjetaLinea(e.key)),
        const SizedBox(height: 8),
        Text('Total: \$${_totalCalculado.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar documento'),
        ),
      ],
    );
  }

  Widget _tarjetaLinea(int index) {
    final linea = _lineas[index];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Producto>(
                    initialValue: linea.producto,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Producto'),
                    items: _productos
                        .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text('${p.nombre} (en stock: ${p.stock})',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (p) => setState(() => linea.producto = p),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar línea',
                  icon: const Icon(Icons.close),
                  onPressed: _lineas.length > 1 ? () => _quitarLinea(index) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '${linea.cantidad}',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cantidad'),
                    onChanged: (v) => setState(
                        () => linea.cantidad = int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: linea.precio == 0 ? '' : '${linea.precio}',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio unit.'),
                    onChanged: (v) => setState(
                        () => linea.precio = double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}