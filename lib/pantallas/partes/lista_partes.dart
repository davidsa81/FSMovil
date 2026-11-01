import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../datos/cola.dart';
import '../../datos/partes.dart';
import '../../widgets/comunes.dart';
import 'detalle_parte.dart';

/// Mis partes: abiertos (por defecto) o cerrados recientemente.
class PantallaListaPartes extends StatefulWidget {
  final String titulo;
  final Color color;

  const PantallaListaPartes({super.key, required this.titulo, required this.color});

  @override
  State<PantallaListaPartes> createState() => _PantallaListaPartesState();
}

class _PantallaListaPartesState extends State<PantallaListaPartes> {
  List<Map<String, dynamic>> _partes = [];
  bool _cerrados = false;
  bool _cargando = true;
  bool _desdeCache = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Cola.instancia.alEnviar = _cargar;
    _cargar();
  }

  @override
  void dispose() {
    Cola.instancia.alEnviar = null;
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final r = await RepoPartes.listar(cerrados: _cerrados);
      var lista = ((r.datos['partes'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (_cerrados) lista = lista.where((p) => p['cerrado'] == true).toList();
      _partes = lista;
      _desdeCache = r.desdeCache;
      _error = null;
    } on SinConexion {
      _error = 'Sin cobertura y sin datos guardados. Abre esta pantalla cuando tengas conexión.';
    } on ApiError catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrir(Map<String, dynamic> p) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaDetalleParte(id: (p['id'] as num).toInt(), color: widget.color)));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo), backgroundColor: widget.color, foregroundColor: textoSobre(widget.color)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('Abiertos'), icon: Icon(Icons.assignment)),
                ButtonSegment(value: true, label: Text('Cerrados'), icon: Icon(Icons.lock)),
              ],
              selected: {_cerrados},
              onSelectionChanged: (s) {
                setState(() => _cerrados = s.first);
                _cargar();
              },
            ),
          ),
          if (_desdeCache)
            Container(
              width: double.infinity,
              color: Colores.naranja.withValues(alpha: 0.15),
              padding: const EdgeInsets.all(10),
              child: const Text('Sin cobertura: mostrando la última copia guardada', style: TextStyle(fontSize: 17, color: Colores.naranja)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargar,
              child: _cargando && _partes.isEmpty
                  ? ListView(children: const [SizedBox(height: 120), Cargando()])
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(fontSize: 19))),
                        if (_error == null && _partes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_cerrados ? 'No hay partes cerrados recientes.' : 'No tienes partes abiertos.',
                                textAlign: TextAlign.center, style: const TextStyle(fontSize: 21)),
                          ),
                        for (final p in _partes) _TarjetaParte(parte: p, onTap: () => _abrir(p)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaParte extends StatelessWidget {
  final Map<String, dynamic> parte;
  final VoidCallback onTap;

  const _TarjetaParte({required this.parte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final estado = Map<String, dynamic>.from(parte['estado'] as Map? ?? {});
    final colorEstado = colorDesdeHex(estado['color']?.toString(), Colors.grey);
    final fecha = formatoFecha(parte['fechaprevista']?.toString());
    final esHoy = fecha.startsWith('Hoy');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: parte['trabajando'] == true ? Colores.verde : colorEstado, width: parte['trabajando'] == true ? 3 : 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('#${parte['id']}', style: const TextStyle(fontSize: 18, color: Colors.black54)),
                const SizedBox(width: 8),
                Etiqueta((estado['nombre'] ?? '').toString(), colorEstado),
                const Spacer(),
                if (parte['soy_encargado'] == true) const Tooltip(message: 'Eres el encargado', child: Icon(Icons.star, color: Colors.amber, size: 28)),
              ]),
              const SizedBox(height: 8),
              Text((parte['servicio'] ?? '').toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text((parte['cliente_nombre'] ?? '').toString(), style: const TextStyle(fontSize: 19)),
              if ((parte['direccion'] ?? '').toString().isNotEmpty)
                Text((parte['direccion']).toString(), style: const TextStyle(fontSize: 17, color: Colors.black54)),
              const SizedBox(height: 6),
              Row(children: [
                if (fecha.isNotEmpty) ...[
                  Icon(Icons.event, size: 22, color: esHoy ? Colores.naranja : Colors.black54),
                  const SizedBox(width: 4),
                  Text(fecha, style: TextStyle(fontSize: 18, fontWeight: esHoy ? FontWeight.bold : FontWeight.normal, color: esHoy ? Colores.naranja : Colors.black87)),
                ],
                const Spacer(),
                if (parte['trabajando'] == true)
                  const Row(children: [
                    Icon(Icons.timer, color: Colores.verde, size: 24),
                    SizedBox(width: 4),
                    Text('Trabajando', style: TextStyle(fontSize: 18, color: Colores.verde, fontWeight: FontWeight.bold)),
                  ]),
                if (parte['firmado'] == true && parte['cerrado'] != true)
                  const Row(children: [
                    Icon(Icons.draw, color: Colores.verde, size: 24),
                    SizedBox(width: 4),
                    Text('Firmado', style: TextStyle(fontSize: 18, color: Colores.verde)),
                  ]),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
