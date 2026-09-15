import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import 'documento_form_screen.dart';

/// Listado de documentos (compras, ventas, despachos, ajustes).
class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final ApiService _api = ApiService();
  bool _cargando = true;
  String _error = '';
  List<Documento> _docs = [];
  String? _tipoFiltro;

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
      final lista = await _api.listarDocumentos(tipo: _tipoFiltro);
      if (!mounted) return;
      setState(() {
        _docs = lista.items;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo cargar: $e';
      });
    }
  }

  Future<void> _crear() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const DocumentoFormScreen()),
    );
    if (resultado == true) _cargar();
  }

  Future<void> _eliminar(Documento d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text(
            '¿Eliminar el documento ${d.folio.isNotEmpty ? d.folio : '#${d.id}'} de '
            '${TiposDocumento.etiqueta(d.tipo)}? El stock se revertirá.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.eliminarDocumento(d.id);
      _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documentos'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filtrar por tipo',
            onSelected: (v) {
              setState(() => _tipoFiltro = v.isEmpty ? null : v);
              _cargar();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('Todos')),
              ...TiposDocumento.lista.map(
                  (t) => PopupMenuItem(value: t, child: Text(TiposDocumento.etiqueta(t)))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : _docs.isEmpty
                  ? const Center(child: Text('Aún no hay documentos. Pulsa "Registrar".'))
                  : ListView.builder(
                      itemCount: _docs.length,
                      itemBuilder: (context, i) => _tarjetaDocumento(_docs[i]),
                    ),
    );
  }

  Widget _tarjetaDocumento(Documento d) {
    final esEntrada = TiposDocumento.signo(d.tipo) > 0;
    final color = switch (d.tipo) {
      TiposDocumento.compra => Colors.green,
      TiposDocumento.venta => Colors.orange,
      TiposDocumento.despacho => Colors.blue,
      _ => Colors.grey,
    };
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(
            esEntrada ? Icons.add_circle : Icons.remove_circle,
            color: color,
          ),
        ),
        title: Text(
            '${TiposDocumento.etiqueta(d.tipo)} · ${d.folio.isNotEmpty ? d.folio : '#${d.id}'}'),
        subtitle: Text(
            '${d.fecha.toLocal().toString().substring(0, 16)} · ${d.lineas.length} línea(s) · '
            '\$${d.total.toStringAsFixed(2)}'),
        onTap: () => _detalle(d),
        trailing: IconButton(
          tooltip: 'Eliminar',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _eliminar(d),
        ),
      ),
    );
  }

  void _detalle(Documento d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _detalleSheet(d),
    );
  }

  Widget _detalleSheet(Documento d) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${TiposDocumento.etiqueta(d.tipo)} ${d.folio.isNotEmpty ? d.folio : ''}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Fecha: ${d.fecha.toLocal().toString().substring(0, 16)}'),
            if (d.notas.isNotEmpty) Text('Notas: ${d.notas}'),
            const Divider(),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: d.lineas
                    .map((l) => ListTile(
                          dense: true,
                          title: Text(l.nombre),
                          subtitle: Text('${l.cantidad} × '
                              '\$${l.precioUnitario.toStringAsFixed(2)}'),
                          trailing: Text('\$${l.subtotal.toStringAsFixed(2)}'),
                        ))
                    .toList(),
              ),
            ),
            const Divider(),
            Text('Total: \$${d.total.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}