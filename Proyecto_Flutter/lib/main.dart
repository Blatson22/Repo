import 'package:flutter/material.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';

void main() {
  runApp(const MyApp());
}

/// Vista actual de la aplicación.
enum _Vista {
  lista,
  formulario,
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ApiService _api = ApiService();
  late var _productos = <Producto>[];
  _Vista _vista = _Vista.lista;
  String _mensaje = '';

  // Controladores de texto del formulario.
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _precio = TextEditingController();
  final _stock = TextEditingController();
  final _categoria = TextEditingController();
  int? _editandoId; // null => crear nuevo

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Descarga la lista de productos del servidor.
  Future<void> _cargar() async {
    try {
      final lista = await _api.listar(buscar: null);
      if (mounted) {
        setState(() {
          _productos = lista;
          _mensaje = '${lista.length} producto(s)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensaje = 'No se pudo conectar con la API.\n'
              'Asegúrate de que el backend esté corriendo en $apiBaseUrl\n'
              '($e)';
        });
      }
    }
  }

  /// Prepara el formulario para crear un producto nuevo.
  void _nuevo() {
    setState(() {
      _editandoId = null;
      _nombre.value = TextEditingValue(text: '');
      _descripcion.value = TextEditingValue(text: '');
      _precio.value = TextEditingValue(text: '');
      _stock.value = TextEditingValue(text: '');
      _categoria.value = TextEditingValue(text: '');
      _mensaje = '';
      _vista = _Vista.formulario;
    });
  }

  /// Carga un producto en el formulario para editarlo.
  void _editar(Producto p) {
    setState(() {
      _editandoId = p.id;
      _nombre.value = TextEditingValue(text: p.nombre);
      _descripcion.value = TextEditingValue(text: p.descripcion);
      _precio.value = TextEditingValue(text: p.precio.toString());
      _stock.value = TextEditingValue(text: p.stock.toString());
      _categoria.value = TextEditingValue(text: p.categoria);
      _mensaje = '';
      _vista = _Vista.formulario;
    });
  }

  void _cancelar() {
    setState(() {
      _vista = _Vista.lista;
      _mensaje = '';
    });
  }

  /// Guarda (crea o actualiza) el producto según `_editandoId`.
  Future<void> _guardar() async {
    final nombre = _nombre.value.text.trim();
    if (nombre.isEmpty) {
      setState(() => _mensaje = 'El nombre es obligatorio.');
      return;
    }
    final datos = <String, dynamic>{
      'nombre': nombre,
      'descripcion': _descripcion.value.text,
      'precio': double.tryParse(_precio.value.text) ?? 0,
      'stock': int.tryParse(_stock.value.text) ?? 0,
      'categoria': _categoria.value.text.trim(),
    };
    try {
      if (_editandoId == null) {
        await _api.crear(datos);
      } else {
        await _api.actualizar(_editandoId!, datos);
      }
      await _cargar();
      if (mounted) {
        setState(() {
          _vista = _Vista.lista;
          _mensaje = 'Producto guardado correctamente.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mensaje = 'Error al guardar: $e');
      }
    }
  }

  /// Elimina un producto tras confirmar.
  Future<void> _eliminar(int id) async {
    try {
      await _api.eliminar(id);
      await _cargar();
      if (mounted) {
        setState(() => _mensaje = 'Producto eliminado.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mensaje = 'Error al eliminar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventario',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _cargar();
            },
          ),
        ],
      ),
      floatingActionButton: _vista == _Vista.lista
          ? FloatingActionButton(
              tooltip: 'Nuevo producto',
              onPressed: _nuevo,
              child: const Icon(Icons.add),
            )
          : null,
      body: _vista == _Vista.lista ? _buildLista(context) : _buildFormulario(context),
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    final cuerpo = _productos.isEmpty
        ? Center(
            child: Text('Aún no hay productos.\nPulsa el botón + para añadir uno.',
                textAlign: TextAlign.center))
        : ListView(children: _buildTiles(context));
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text('Productos en el almacén',
              style: Theme.of(context).textTheme.headlineSmall),
        ),
        const Divider(height: 1),
        Expanded(child: cuerpo),
        if (_mensaje.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(_mensaje,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
      ],
    );
  }

  List<Widget> _buildTiles(BuildContext context) {
    final tiles = <Widget>[];
    for (final p in _productos) {
      tiles.add(
        ListTile(
          leading: const Icon(Icons.inventory_2),
          title: Text(p.nombre),
          subtitle: Text('${p.categoria.isNotEmpty ? p.categoria : 'General'}'
              '  •  \$${p.precio.toStringAsFixed(2)}  •  ${p.stockTexto}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editar(p),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await _eliminar(p.id);
                },
              ),
            ],
          ),
          onTap: () => _editar(p),
        ),
      );
    }
    return tiles;
  }

  Widget _buildFormulario(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: <Widget>[
        Text(
          _editandoId == null ? 'Nuevo producto' : 'Editar producto',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16.0),
        TextField(
          controller: _nombre,
          decoration: const InputDecoration(labelText: 'Nombre *'),
        ),
        const SizedBox(height: 12.0),
        TextField(
          controller: _descripcion,
          decoration: const InputDecoration(labelText: 'Descripción'),
        ),
        const SizedBox(height: 12.0),
        TextField(
          controller: _categoria,
          decoration: const InputDecoration(labelText: 'Categoría'),
        ),
        const SizedBox(height: 12.0),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _precio,
                decoration: const InputDecoration(labelText: 'Precio'),
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: TextField(
                controller: _stock,
                decoration: const InputDecoration(labelText: 'Stock'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20.0),
        if (_mensaje.isNotEmpty) ...<Widget>[
          Text(_mensaje, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8.0),
        ],
        FilledButton(
          onPressed: () async {
            await _guardar();
          },
          child: const Text('Guardar'),
        ),
        const SizedBox(height: 8.0),
        OutlinedButton(
          onPressed: _cancelar,
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}