import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../datos/partes.dart';
import '../../widgets/comunes.dart';
import '../escaner.dart';

/// Elegir un material: buscar por referencia/descripción, escanear el código de barras
/// o escribirlo a mano (texto libre). Devuelve {referencia?, descripcion, cantidad}.
class PantallaMaterial extends StatefulWidget {
  const PantallaMaterial({super.key});

  @override
  State<PantallaMaterial> createState() => _PantallaMaterialState();
}

class _PantallaMaterialState extends State<PantallaMaterial> {
  final _texto = TextEditingController();
  Timer? _espera;
  List<Map<String, dynamic>> _resultados = [];
  Map<String, dynamic>? _elegido;
  double _cantidad = 1;
  bool _buscando = false;
  bool _sinConexion = false;

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    super.dispose();
  }

  void _alEscribir(String valor) {
    _espera?.cancel();
    setState(() => _elegido = null);
    _espera = Timer(const Duration(milliseconds: 450), () => _buscar(valor));
  }

  Future<void> _buscar(String valor) async {
    if (valor.trim().length < 2) {
      setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final r = await RepoPartes.buscarArticulos(valor.trim());
      if (!mounted) return;
      setState(() {
        _resultados = r;
        _sinConexion = false;
      });
    } on SinConexion {
      if (mounted) setState(() => _sinConexion = true);
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaEscaner(titulo: 'Código de barras', soloQr: false)),
    );
    if (codigo == null) return;
    _texto.text = codigo;
    await _buscar(codigo);
    if (_resultados.length == 1) setState(() => _elegido = _resultados.first);
    if (_resultados.isEmpty && mounted && !_sinConexion) {
      mostrarMensaje(context, 'No hay ningún artículo con ese código. Puedes añadirlo como texto libre.', aviso: true);
    }
  }

  void _guardar() {
    final texto = _texto.text.trim();
    if (_elegido == null && texto.isEmpty) {
      mostrarMensaje(context, 'Escribe o escanea el material', error: true);
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      if (_elegido != null) 'referencia': _elegido!['referencia'],
      'descripcion': _elegido != null ? _elegido!['descripcion'] : texto,
      'cantidad': _cantidad,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Añadir material')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _texto,
            onChanged: _alEscribir,
            style: const TextStyle(fontSize: 21),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Material o referencia',
              prefixIcon: const Icon(Icons.search, size: 30),
              suffixIcon: _buscando ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 3)) : null,
            ),
          ),
          const SizedBox(height: 8),
          BotonGrande(texto: 'Escanear código de barras', icono: Icons.qr_code_scanner, color: Colors.blueGrey, alto: 64, onPressed: _escanear),
          if (_sinConexion)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Sin cobertura: no se puede buscar en el catálogo. Se guardará como texto libre.',
                  style: TextStyle(fontSize: 17, color: Colores.naranja)),
            ),
          if (_elegido != null)
            Card(
              color: Colores.verde.withValues(alpha: 0.12),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colores.verde, size: 34),
                title: Text(_elegido!['descripcion'].toString()),
                subtitle: Text(_elegido!['referencia'].toString()),
                trailing: IconButton(icon: const Icon(Icons.close, size: 30), onPressed: () => setState(() => _elegido = null)),
              ),
            )
          else
            for (final a in _resultados)
              Card(
                child: ListTile(
                  title: Text(a['descripcion'].toString()),
                  subtitle: Text(a['referencia'].toString()),
                  onTap: () => setState(() => _elegido = a),
                ),
              ),
          if (_elegido == null && _texto.text.trim().isNotEmpty && !_buscando)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Si no está en la lista, se añadirá «${_texto.text.trim()}» como texto libre.',
                  style: const TextStyle(fontSize: 17, color: Colors.black54)),
            ),
          const SizedBox(height: 16),
          const Text('Cantidad', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            _BotonCantidad(icono: Icons.remove, onPressed: _cantidad > 1 ? () => setState(() => _cantidad -= 1) : null),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final v = await pedirTexto(context, 'Cantidad', inicial: _formato(_cantidad), lineas: 1, boton: 'Aceptar');
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n != null && n > 0) setState(() => _cantidad = n);
                },
                child: Text(_formato(_cantidad), textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              ),
            ),
            _BotonCantidad(icono: Icons.add, onPressed: () => setState(() => _cantidad += 1)),
          ]),
          const SizedBox(height: 24),
          BotonGrande(texto: 'Añadir', icono: Icons.check, color: Colores.verde, alto: 84, onPressed: _guardar),
        ],
      ),
    );
  }

  String _formato(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}

class _BotonCantidad extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onPressed;

  const _BotonCantidad({required this.icono, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
        child: Icon(icono, size: 40),
      ),
    );
  }
}
