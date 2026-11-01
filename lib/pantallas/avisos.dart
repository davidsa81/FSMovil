import 'package:flutter/material.dart';

import '../api/api.dart';
import '../datos/estado.dart';
import '../widgets/comunes.dart';
import 'partes/detalle_parte.dart';

/// Avisos de la oficina (los mismos que llegan como notificación).
class PantallaAvisos extends StatefulWidget {
  const PantallaAvisos({super.key});

  @override
  State<PantallaAvisos> createState() => _PantallaAvisosState();
}

class _PantallaAvisosState extends State<PantallaAvisos> {
  List<Map<String, dynamic>> _avisos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final api = Estado.instancia.api;
    if (api == null) return;
    setState(() => _cargando = true);
    try {
      final r = await api.get('api/avisos');
      _avisos = ((r['avisos'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      _error = null;
      final sinLeer = _avisos.where((a) => a['leido'] != true).map((a) => a['id']).toList();
      if (sinLeer.isNotEmpty) {
        api.post('api/avisos/leidos', {'ids': sinLeer}).catchError((_) => <String, dynamic>{});
      }
    } on SinConexion {
      _error = 'Sin cobertura: no se pueden cargar los avisos ahora.';
    } on ApiError catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _abrir(Map<String, dynamic> aviso) {
    final datos = aviso['datos'];
    final id = datos is Map ? int.tryParse('${datos['id']}') : null;
    if (aviso['modulo'] == 'partes' && id != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaDetalleParte(id: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando && _avisos.isEmpty
            ? const Cargando()
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(fontSize: 19, color: Colores.naranja))),
                  if (_avisos.isEmpty && _error == null)
                    const Padding(padding: EdgeInsets.all(24), child: Text('No tienes avisos.', style: TextStyle(fontSize: 20))),
                  for (final a in _avisos)
                    Card(
                      color: a['leido'] == true ? null : const Color(0xFFFFF3E0),
                      child: ListTile(
                        leading: Icon(a['leido'] == true ? Icons.notifications_none : Icons.notifications_active,
                            size: 34, color: a['leido'] == true ? Colors.grey : Colores.naranja),
                        title: Text((a['titulo'] ?? '').toString()),
                        subtitle: Text('${a['mensaje'] ?? ''}\n${formatoFecha(a['fecha']?.toString())}'),
                        isThreeLine: true,
                        trailing: a['modulo'] == 'partes' ? const Icon(Icons.chevron_right, size: 32) : null,
                        onTap: () => _abrir(a),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
