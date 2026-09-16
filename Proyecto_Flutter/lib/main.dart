import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'api.dart';
import 'config.dart';
import 'models.dart';
import 'screens/documento_form_screen.dart';
import 'screens/documentos_screen.dart';
import 'screens/reportes_screen.dart';

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
  // Clave global del Navigator: la usamos para navegar/mostrar diálogos
  // porque el `context` de este State (MyApp) está POR ENCIMA del
  // MaterialApp que construye, así que no tiene Navigator ni
  // MaterialLocalizations. Usar navigatorKey.currentState/currentContext
  // sí nos da un contexto válido dentro del árbol del MaterialApp.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late var _productos = <Producto>[];
  _Vista _vista = _Vista.lista;
  String _mensaje = '';

  // Buscador de la pantalla de inventario.
  final _busqueda = TextEditingController();
  String _terminoBusqueda = '';
  Timer? _debounceBusqueda;
  bool _buscando = false;

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

  @override
  void dispose() {
    _debounceBusqueda?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  /// Descarga la lista de productos del servidor (con búsqueda opcional).
  Future<void> _cargar() async {
    try {
      final lista = await _api.listar(buscar: _terminoBusqueda);
      if (mounted) {
        setState(() {
          _productos = lista;
          _buscando = false;
          if (_terminoBusqueda.trim().isEmpty) {
            _mensaje = '${lista.length} producto(s)';
          } else {
            _mensaje = '${lista.length} resultado(s) para "${_terminoBusqueda.trim()}"';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _buscando = false;
          _mensaje = 'No se pudo conectar con la API.\n'
              'Asegúrate de que el backend esté corriendo en $apiBaseUrl\n'
              '($e)';
        });
      }
    }
  }

  /// Dispara la recarga con un retardo (debounce) mientras se escribe.
  void _onBuscarCambio(String texto) {
    _debounceBusqueda?.cancel();
    setState(() => _buscando = true);
    final termino = texto.trim();
    _debounceBusqueda = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _terminoBusqueda = termino;
        });
        _cargar();
      }
    });
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
      navigatorKey: _navigatorKey,
      title: 'Inventario',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _busqueda,
          onChanged: _onBuscarCambio,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar producto…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busqueda.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _busqueda.clear();
                      _onBuscarCambio('');
                    },
                  ),
            border: InputBorder.none,
            isDense: true,
          ),
        ),
        centerTitle: false,
        actions: <Widget>[
          if (_buscando)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _cargar();
            },
          ),
          IconButton(
            tooltip: 'Documentos (compras/ventas/despachos)',
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              _navigatorKey.currentState!
                  .push(
                    MaterialPageRoute(builder: (_) => const DocumentosScreen()),
                  )
                  .then((_) => _cargar());
            },
          ),
          IconButton(
            tooltip: 'Reportes',
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              _navigatorKey.currentState!
                  .push(
                    MaterialPageRoute(builder: (_) => const ReportesScreen()),
                  )
                  .then((_) => _cargar());
            },
          ),
        ],
      ),
      floatingActionButton: _vista == _Vista.lista
          ? FloatingActionButton(
              tooltip: 'Acciones',
              onPressed: _mostrarMenuAcciones,
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
                tooltip: 'Vender',
                icon: const Icon(Icons.point_of_sale),
                onPressed: () => _abrirDocumento(TiposDocumento.venta, p),
              ),
              IconButton(
                tooltip: 'Comprar',
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => _abrirDocumento(TiposDocumento.compra, p),
              ),
              PopupMenuButton<String>(
                tooltip: 'Más',
                onSelected: (v) {
                  if (v == 'editar') {
                    _editar(p);
                  } else if (v == 'eliminar') {
                    _eliminar(p.id);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          onTap: () => _editar(p),
        ),
      );
    }
    return tiles;
  }

  /// Abre el formulario de documento con tipo y (opcional) producto.
  void _abrirDocumento(String tipo, Producto? producto) {
    _navigatorKey.currentState!
        .push(
          MaterialPageRoute(
            builder: (_) => DocumentoFormScreen(tipo: tipo, producto: producto),
          ),
        )
        .then((_) => _cargar());
  }

  /// Muestra el menú de acciones del botón flotante.
  void _mostrarMenuAcciones() {
    showModalBottomSheet(
      context: _navigatorKey.currentContext!,
      builder: (_) => _menuAcciones(),
    );
  }

  Widget _menuAcciones() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _accion(Icons.inventory_2, 'Nuevo producto', () => _nuevo()),
        _accion(Icons.shopping_cart, 'Registrar compra',
            () => _abrirDocumento(TiposDocumento.compra, null)),
        _accion(Icons.point_of_sale, 'Registrar venta',
            () => _abrirDocumento(TiposDocumento.venta, null)),
        _accion(Icons.local_shipping, 'Registrar despacho',
            () => _abrirDocumento(TiposDocumento.despacho, null)),
        const Divider(height: 1),
        _accion(Icons.upload_file, 'Importar inventario (Excel)',
            () => _importarInventario()),
        _accion(Icons.help_outline, 'Plantilla (columnas)',
            () => _mostrarColumnasPlantilla()),
      ],
    );
  }

  /// Importa inventario desde un archivo Excel (preview + confirmar mapeo + commit).
  Future<void> _importarInventario() async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: false,
      );
      if (resultado == null || resultado.files.isEmpty) return; // canceló
      final ruta = resultado.files.single.path;
      if (ruta == null) return;

      _mensaje = 'Analizando el archivo…';
      final preview = await _api.importarPreview(ruta);

      // Si el backend devolvió un mapeo fallido, avisa y da opción a fallback.
      if (preview.mapeo.values.any((v) => v == null) && !preview.mapeo.containsValue('nombre')) {
        _mostrarErrorPreview(preview);
        return;
      }

      final mapeoConfirmado = await _mostrarDialogoMapeo(preview);
      if (mapeoConfirmado == null) return; // canceló el mapeo

      _mensaje = 'Importando productos…';
      final resp = await _api.importarCommit(ruta, mapeoConfirmado);
      await _cargar();

      if (!mounted) return;
      final textoErrores = resp.errores.isEmpty
          ? 'Sin errores.'
          : resp.errores
              .map((e) => 'Fila ${e.fila}: ${e.error}')
              .join('\n');
      showDialog<void>(
        context: _navigatorKey.currentContext!,
        builder: (_) => AlertDialog(
          title: const Text('Resultado de la importación'),
          content: SingleChildScrollView(
            child: Text(
              '${resp.importados} de ${resp.totalFilas} producto(s) importados.\n\n'
              'Errores:\n$textoErrores',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => _navigatorKey.currentState!.pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() =>
            _mensaje = 'No se pudo importar el inventario: $e');
      }
    }
  }

  void _mostrarErrorPreview(PreviewImportacion preview) {
    final detalle = preview.mapeo['_error'] ?? 'No se pudo interpretar el archivo.';
    showDialog<void>(
      context: _navigatorKey.currentContext!,
      builder: (ctx) => AlertDialog(
        title: const Text('Error al analizar'),
        content: Text(detalle),
        actions: <Widget>[
          TextButton(
            onPressed: () => _navigatorKey.currentState!.pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo con el mapeo propuesto (editable) y devuelve el mapeo.
  Future<Map<String, String?>?> _mostrarDialogoMapeo(
      PreviewImportacion preview) async {
    final camposDestino = <String, String?>{
      for (final c in preview.mapeo.keys) c: preview.mapeo[c],
    };
    // Opciones canónicas disponibles.
    const opciones = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'nombre', child: Text('Nombre')),
      DropdownMenuItem(value: 'precio', child: Text('Precio')),
      DropdownMenuItem(value: 'stock', child: Text('Stock')),
      DropdownMenuItem(value: 'categoria', child: Text('Categoría')),
      DropdownMenuItem(value: 'descripcion', child: Text('Descripción')),
      DropdownMenuItem(value: 'codigo', child: Text('Código')),
    ];

    return showDialog<Map<String, String?>>(
      context: _navigatorKey.currentContext!,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          String cambiaCampo(String? campo) =>
              const {
                'nombre': 'Nombre',
                'precio': 'Precio',
                'stock': 'Stock',
                'categoria': 'Categoría',
                'descripcion': 'Descripción',
                'codigo': 'Código',
              }[campo] ??
              '—';

          return AlertDialog(
            title: const Text('Confirma el mapeo de columnas'),
            content: SizedBox(
              width: 420,
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                      'Usa los menús para decirle al sistema qué significa cada '
                      'columna de tu archivo:'),
                  const SizedBox(height: 8),
                  if (preview.mapeo.keys.isNotEmpty)
                    for (final col in camposDestino.keys)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(col, style: const TextStyle(fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: camposDestino[col] ?? 'ignorar',
                                isDense: true,
                                items: [
                                  const DropdownMenuItem(
                                      value: 'ignorar', child: Text('Ignorar')),
                                  ...opciones,
                                ],
                                onChanged: (v) => setDlg(() {
                                  camposDestino[col] =
                                      (v == null || v == 'ignorar') ? null : v;
                                }),
                              ),
                            ),
                          ],
                        ),
                      )
                  else
                    const Text('No se detectaron columnas.'),
                  const SizedBox(height: 8),
                  if (preview.muestras.isNotEmpty) ...[
                    const Divider(),
                    Text(
                      'Vista previa (según el mapeo):',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    for (final fila in preview.muestras) ...[
                      Text(
                        preview.encabezados.asMap().entries
                            .where((e) => camposDestino[e.value] != null)
                            .map((e) => '${cambiaCampo(camposDestino[e.value])}: ${fila.length > e.key ? fila[e.key] : ''}')
                            .join('  ·  '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => _navigatorKey.currentState!.pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => _navigatorKey.currentState!.pop(camposDestino),
                child: const Text('Importar'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Muestra el diálogo con las columnas esperadas en la plantilla.
  void _mostrarColumnasPlantilla() {
    showDialog<void>(
      context: _navigatorKey.currentContext!,
      builder: (_) => AlertDialog(
        title: const Text('Plantilla de inventario (.xlsx)'),
        content: const Text(
          'La primera fila del archivo debe contener estas columnas:\n\n'
          '  • Nombre (obligatorio)\n'
          '  • Precio (≥ 0)\n'
          '  • Stock (≥ 0, entero)\n'
          '  • Categoria (opcional)\n'
          '  • Descripcion (opcional)\n\n'
          'Si un producto ya existe con el mismo nombre, se actualizan sus datos.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => _navigatorKey.currentState!.pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _accion(IconData icono, String etiqueta, VoidCallback onPressed) {
    return ListTile(
      leading: Icon(icono),
      title: Text(etiqueta),
      onTap: () {
        _navigatorKey.currentState!.pop();
        onPressed();
      },
    );
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