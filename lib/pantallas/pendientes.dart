import 'package:flutter/material.dart';

import '../datos/cola.dart';
import '../widgets/comunes.dart';

/// Cambios hechos sin cobertura que faltan por enviar, y los que el servidor rechazó.
class PantallaPendientes extends StatefulWidget {
  const PantallaPendientes({super.key});

  @override
  State<PantallaPendientes> createState() => _PantallaPendientesState();
}

class _PantallaPendientesState extends State<PantallaPendientes> {
  final _cola = Cola.instancia;

  @override
  void initState() {
    super.initState();
    _cola.addListener(_refrescar);
  }

  @override
  void dispose() {
    _cola.removeListener(_refrescar);
    super.dispose();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  Future<void> _enviar() async {
    await _cola.sincronizar();
    if (!mounted) return;
    if (_cola.pendientes.isEmpty) {
      mostrarMensaje(context, 'Todo enviado');
    } else {
      mostrarMensaje(context, 'Sigue sin haber conexión con el servidor', aviso: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _cola.pendientes;
    final errores = _cola.errores;
    return Scaffold(
      appBar: AppBar(title: const Text('Cambios pendientes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pendientes.isNotEmpty) ...[
            BotonGrande(
              texto: _cola.sincronizando ? 'Enviando...' : 'Enviar ahora',
              icono: Icons.cloud_upload,
              onPressed: _cola.sincronizando ? null : _enviar,
            ),
            const SizedBox(height: 8),
            const Text('Pendientes de enviar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            for (final a in pendientes)
              Card(
                child: ListTile(
                  leading: Icon(a.foto != null ? Icons.photo_camera : Icons.schedule, size: 32),
                  title: Text(a.descripcion),
                  subtitle: Text(formatoFecha(a.fecha)),
                ),
              ),
          ],
          if (pendientes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay nada pendiente de enviar.', style: TextStyle(fontSize: 20)),
            ),
          if (errores.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('No se pudieron guardar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colores.rojo)),
            const Text('Revísalos y vuelve a hacerlos si hace falta.', style: TextStyle(fontSize: 17)),
            for (final e in errores)
              Card(
                color: Colores.rojo.withValues(alpha: 0.06),
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colores.rojo, size: 32),
                  title: Text(e.descripcion),
                  subtitle: Text('${e.mensaje}\n${formatoFecha(e.fecha)}'),
                  isThreeLine: true,
                ),
              ),
            TextButton(
              onPressed: () => _cola.borrarErrores(),
              child: const Text('Borrar esta lista', style: TextStyle(fontSize: 19)),
            ),
          ],
        ],
      ),
    );
  }
}
