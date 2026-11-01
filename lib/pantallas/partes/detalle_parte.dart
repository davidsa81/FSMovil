import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api.dart';
import '../../datos/cola.dart';
import '../../datos/estado.dart';
import '../../datos/partes.dart';
import '../../widgets/comunes.dart';
import 'firma.dart';
import 'material.dart';

/// Detalle de un parte con todas las acciones del empleado.
class PantallaDetalleParte extends StatefulWidget {
  final int id;
  final Color color;

  const PantallaDetalleParte({super.key, required this.id, this.color = Colores.naranja});

  @override
  State<PantallaDetalleParte> createState() => _PantallaDetalleParteState();
}

class _PantallaDetalleParteState extends State<PantallaDetalleParte> {
  Map<String, dynamic>? _parte;
  bool _desdeCache = false;
  bool _cargando = true;
  String? _error;

  int get _id => widget.id;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final r = await RepoPartes.detalle(_id);
      _parte = r.datos;
      _desdeCache = r.desdeCache;
      _error = null;
    } on SinConexion {
      _error = 'Sin cobertura y este parte no está guardado en el móvil.';
    } on ApiError catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Ejecuta una acción y explica al empleado qué ha pasado.
  Future<bool> _accion(List<String> ruta, String descripcion,
      {Map<String, dynamic> datos = const {}, String metodo = 'POST', File? foto, String? ok}) async {
    final r = await conEspera(
      context,
      () => RepoPartes.accion(_id, ruta, datos: datos, metodo: metodo, descripcion: descripcion, foto: foto),
      texto: foto != null ? 'Enviando foto...' : 'Guardando...',
    );
    if (!mounted) return false;
    switch (r.estado) {
      case EstadoAccion.hecha:
        mostrarMensaje(context, ok ?? 'Hecho');
        break;
      case EstadoAccion.pendiente:
        mostrarMensaje(context, 'Sin cobertura: guardado en el móvil, se enviará al recuperar la conexión.', aviso: true);
        break;
      case EstadoAccion.error:
        mostrarMensaje(context, r.mensaje.isEmpty ? 'No se ha podido guardar' : r.mensaje, error: true);
        break;
    }
    await _cargar();
    return r.estado != EstadoAccion.error;
  }

  String get _ref => 'parte #$_id';

  Future<void> _iniciar() => _accion(['iniciar'], 'Empezar trabajo ($_ref)', ok: 'Trabajo empezado');

  Future<void> _terminar() async {
    final texto = await pedirTexto(context, '¿Qué has hecho?', pista: 'Opcional: describe el trabajo', boton: 'Terminar');
    if (texto == null) return;
    await _accion(['terminar'], 'Terminar trabajo ($_ref)', datos: {'descripcion': texto}, ok: 'Trabajo terminado');
  }

  Future<void> _material() async {
    final datos = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const PantallaMaterial()));
    if (datos == null) return;
    await _accion(['materiales'], 'Material: ${datos['descripcion'] ?? datos['referencia']} ($_ref)', datos: datos, ok: 'Material añadido');
  }

  Future<void> _borrarMaterial(Map<String, dynamic> m) async {
    if (m['id'] == null) return;
    final ok = await confirmar(context, 'Quitar material', '¿Quitar «${m['descripcion']}» de este parte?', si: 'Quitar');
    if (!ok) return;
    await _accion(['materiales', '${m['id']}'], 'Quitar material ($_ref)', metodo: 'DELETE', ok: 'Material quitado');
  }

  Future<void> _foto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera, size: 36),
            title: const Text('Hacer foto'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, size: 36),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (origen == null) return;

    // el servidor puede tener un límite bajo (2 MB en muchos hostings): reducimos la foto
    final maxSubida = (Estado.instancia.inicio?['servidor']?['max_subida'] as num?)?.toInt() ?? 2097152;
    final pequena = maxSubida < 1500000;
    final XFile? imagen = await ImagePicker().pickImage(
      source: origen,
      maxWidth: pequena ? 1280 : 1600,
      maxHeight: pequena ? 1280 : 1600,
      imageQuality: pequena ? 70 : 80,
    );
    if (imagen == null) return;
    await _accion(['fotos'], 'Foto ($_ref)', foto: File(imagen.path), ok: 'Foto enviada');
  }

  Future<void> _observacion() async {
    final texto = await pedirTexto(context, 'Observación', pista: 'Escribe la observación', lineas: 5);
    if (texto == null || texto.isEmpty) return;
    await _accion(['observaciones'], 'Observación ($_ref)', datos: {'texto': texto}, ok: 'Observación guardada');
  }

  Future<void> _firmar() async {
    final datos = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const PantallaFirma()));
    if (datos == null) return;
    await _accion(['firmar'], 'Firma del cliente ($_ref)', datos: datos, ok: 'Firma guardada');
  }

  Future<void> _cambiarEstado() async {
    final cache = await Estado.instancia.leerCache('partes');
    final estados = ((cache?['estados'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => e['cerrado'] != true)
        .toList();
    if (estados.isEmpty || !mounted) {
      if (mounted) mostrarMensaje(context, 'Abre la lista de partes con cobertura para cargar los estados.', aviso: true);
      return;
    }
    final elegido = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Cambiar estado', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          for (final e in estados)
            ListTile(
              leading: CircleAvatar(backgroundColor: colorDesdeHex(e['color']?.toString())),
              title: Text(e['nombre'].toString()),
              onTap: () => Navigator.pop(c, e['codigo'].toString()),
            ),
        ]),
      ),
    );
    if (elegido == null) return;
    await _accion(['estado'], 'Cambio de estado ($_ref)', datos: {'codestado': elegido}, ok: 'Estado cambiado');
  }

  Future<void> _cerrar() async {
    final ok = await confirmar(context, 'Cerrar parte', 'Después de cerrarlo ya no se podrá modificar. ¿Cerrar el parte #$_id?', si: 'Cerrar');
    if (!ok) return;
    await _accion(['cerrar'], 'Cerrar ($_ref)', ok: 'Parte cerrado');
  }

  Future<void> _abrirUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
      mostrarMensaje(context, 'No se ha podido abrir', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _parte;
    return Scaffold(
      appBar: AppBar(
        title: Text('Parte #$_id'),
        backgroundColor: widget.color,
        foregroundColor: textoSobre(widget.color),
      ),
      body: p == null
          ? (_cargando ? const Cargando() : Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? '', style: const TextStyle(fontSize: 20))))
          : RefreshIndicator(onRefresh: _cargar, child: _contenido(p)),
    );
  }

  Widget _contenido(Map<String, dynamic> p) {
    final estado = Map<String, dynamic>.from(p['estado'] as Map? ?? {});
    final cliente = Map<String, dynamic>.from(p['cliente'] as Map? ?? {});
    final encargado = p['encargado'] is Map ? Map<String, dynamic>.from(p['encargado'] as Map) : null;
    final puede = Map<String, dynamic>.from(p['puede'] as Map? ?? {});
    final firma = Map<String, dynamic>.from(p['firma'] as Map? ?? {});
    final cerrado = p['cerrado'] == true;
    final trabajando = p['trabajando'] == true;
    final direccion = (p['direccion_navegacion'] ?? p['direccion'] ?? '').toString();
    final telefono = (cliente['telefono1'] ?? '').toString().isNotEmpty ? cliente['telefono1'].toString() : (cliente['telefono2'] ?? '').toString();
    final trabajos = ((p['trabajos'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final materiales = ((p['materiales'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final fotos = ((p['fotos'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final pendientes = Cola.instancia.pendientes.where((a) => a.modulo == 'partes' && a.ruta.length > 1 && a.ruta[1] == '$_id').length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (_desdeCache || pendientes > 0)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colores.naranja.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(
              pendientes > 0 ? 'Hay $pendientes cambios de este parte pendientes de enviar.' : 'Sin cobertura: datos guardados en el móvil.',
              style: const TextStyle(fontSize: 18, color: Colores.naranja),
            ),
          ),

        // --- cabecera ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Etiqueta((estado['nombre'] ?? '').toString(), colorDesdeHex(estado['color']?.toString(), Colors.grey)),
                const Spacer(),
                if (p['soy_encargado'] == true) const Text('Eres el encargado', style: TextStyle(fontSize: 16, color: Colors.amber, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 10),
              Text((p['servicio'] ?? '').toString(), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text((cliente['nombre'] ?? p['cliente_nombre'] ?? '').toString(), style: const TextStyle(fontSize: 21)),
              if (direccion.isNotEmpty) Text(direccion, style: const TextStyle(fontSize: 18, color: Colors.black54)),
              if ((p['fechaprevista'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    const Icon(Icons.event, size: 22),
                    const SizedBox(width: 6),
                    Text(formatoFecha(p['fechaprevista']?.toString()), style: const TextStyle(fontSize: 19)),
                  ]),
                ),
              if ((p['descripcion'] ?? '').toString().isNotEmpty) ...[
                const Divider(height: 24),
                Text(p['descripcion'].toString(), style: const TextStyle(fontSize: 19)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 6),

        // --- acciones ---
        if (direccion.isNotEmpty)
          BotonGrande(
            texto: 'Cómo llegar',
            icono: Icons.directions,
            color: const Color(0xFF00897B),
            onPressed: () => _abrirUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(direccion)}')),
          ),
        if (telefono.isNotEmpty)
          BotonGrande(
            texto: 'Llamar al cliente',
            subtitulo: telefono,
            icono: Icons.call,
            color: const Color(0xFF00897B),
            onPressed: () => _abrirUrl(Uri(scheme: 'tel', path: telefono.replaceAll(' ', ''))),
          ),
        if (cerrado)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.lock, size: 30),
              SizedBox(width: 12),
              Expanded(child: Text('Parte cerrado. Ya no se puede modificar.', style: TextStyle(fontSize: 20))),
            ]),
          )
        else ...[
          if (trabajando)
            BotonGrande(texto: 'Terminar trabajo', icono: Icons.stop_circle, color: Colores.rojo, alto: 90, onPressed: _terminar)
          else
            BotonGrande(texto: 'Empezar trabajo', icono: Icons.play_circle, color: Colores.verde, alto: 90, onPressed: _iniciar),
          BotonGrande(texto: 'Añadir material', icono: Icons.inventory_2, onPressed: _material),
          BotonGrande(texto: 'Hacer foto', icono: Icons.photo_camera, onPressed: _foto),
          BotonGrande(texto: 'Observación', icono: Icons.edit_note, onPressed: _observacion),
          if (firma['firmado'] != true)
            BotonGrande(texto: 'Firma del cliente', icono: Icons.draw, color: const Color(0xFF6A1B9A), onPressed: _firmar),
          if (puede['cerrar'] == true)
            BotonGrande(texto: 'Cerrar parte', icono: Icons.lock, color: Colors.black87, onPressed: _cerrar),
          BotonGrande(texto: 'Cambiar estado', icono: Icons.swap_horiz, color: Colors.blueGrey, alto: 64, onPressed: _cambiarEstado),
        ],

        // --- trabajos ---
        _Seccion('Trabajos', Icons.handyman, [
          if (trabajos.isEmpty) const _Vacio('Todavía no hay trabajos.'),
          for (final t in trabajos)
            ListTile(
              leading: Icon(t['en_curso'] == true ? Icons.timer : Icons.check_circle,
                  color: t['en_curso'] == true ? Colores.verde : Colors.black45, size: 32),
              title: Text((t['descripcion'] ?? '').toString()),
              subtitle: Text([
                (t['empleado'] ?? '').toString(),
                t['en_curso'] == true ? 'En curso desde ${formatoFecha(t['inicio']?.toString())}' : formatoHoras(t['horas'] as num?),
                if (t['pendiente'] == true) 'pendiente de enviar',
              ].where((s) => s.isNotEmpty).join(' · ')),
            ),
        ]),

        // --- materiales ---
        _Seccion('Materiales', Icons.inventory_2, [
          if (materiales.isEmpty) const _Vacio('Sin materiales.'),
          for (final m in materiales)
            ListTile(
              leading: CircleAvatar(
                radius: 22,
                child: Text(_cantidad(m['cantidad']), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              title: Text((m['descripcion'] ?? '').toString()),
              subtitle: Text([
                (m['referencia'] ?? '').toString(),
                if (m['pendiente'] == true) 'pendiente de enviar',
              ].where((s) => s.isNotEmpty).join(' · ')),
              trailing: !cerrado && m['id'] != null
                  ? IconButton(icon: const Icon(Icons.delete_outline, size: 30), onPressed: () => _borrarMaterial(m))
                  : null,
            ),
        ]),

        // --- fotos ---
        _Seccion('Fotos', Icons.photo_library, [
          if (fotos.isEmpty) const _Vacio('Sin fotos.'),
          if (fotos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in fotos) _Miniatura(idParte: _id, foto: f),
              ]),
            ),
        ]),

        // --- observaciones y firma ---
        if ((p['observaciones'] ?? '').toString().isNotEmpty)
          _Seccion('Observaciones', Icons.notes, [
            Padding(padding: const EdgeInsets.all(14), child: Text(p['observaciones'].toString(), style: const TextStyle(fontSize: 18))),
          ]),
        _Seccion('Firma del cliente', Icons.draw, [
          ListTile(
            leading: Icon(firma['firmado'] == true ? Icons.verified : Icons.pending, color: firma['firmado'] == true ? Colores.verde : Colors.black38, size: 32),
            title: Text(firma['firmado'] == true ? 'Firmado por ${firma['nombre'] ?? ''}' : 'Sin firmar'),
            subtitle: firma['firmado'] == true ? Text(formatoFecha(firma['fecha']?.toString())) : null,
          ),
        ]),

        // --- personas ---
        _Seccion('Equipo', Icons.people, [
          if (encargado != null)
            ListTile(
              leading: const Icon(Icons.star, color: Colors.amber, size: 32),
              title: Text(encargado['nombre'].toString()),
              subtitle: const Text('Encargado'),
              trailing: (encargado['telefono'] ?? '').toString().isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.call, size: 30, color: Color(0xFF00897B)),
                      onPressed: () => _abrirUrl(Uri(scheme: 'tel', path: encargado['telefono'].toString().replaceAll(' ', ''))),
                    )
                  : null,
            ),
          for (final e in ((p['empleados'] as List?) ?? []))
            ListTile(leading: const Icon(Icons.person, size: 32), title: Text((e as Map)['nombre'].toString())),
        ]),
        const SizedBox(height: 30),
      ],
    );
  }

  String _cantidad(dynamic c) {
    final n = (c is num) ? c : num.tryParse('$c') ?? 0;
    return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> hijos;

  const _Seccion(this.titulo, this.icono, this.hijos);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(children: [
            Icon(icono, size: 26),
            const SizedBox(width: 8),
            Text(titulo, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          ]),
        ),
        ...hijos,
      ]),
    );
  }
}

class _Vacio extends StatelessWidget {
  final String texto;

  const _Vacio(this.texto);

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(16), child: Text(texto, style: const TextStyle(fontSize: 18, color: Colors.black54)));
}

class _Miniatura extends StatefulWidget {
  final int idParte;
  final Map<String, dynamic> foto;

  const _Miniatura({required this.idParte, required this.foto});

  @override
  State<_Miniatura> createState() => _MiniaturaState();
}

class _MiniaturaState extends State<_Miniatura> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final local = widget.foto['local'];
    try {
      if (local is String && File(local).existsSync()) {
        _bytes = await File(local).readAsBytes();
      } else if (widget.foto['id'] != null) {
        _bytes = Uint8List.fromList(await RepoPartes.foto(widget.idParte, (widget.foto['id'] as num).toInt()));
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _ampliar() {
    if (_bytes == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Foto')),
          backgroundColor: Colors.black,
          body: InteractiveViewer(child: Center(child: Image.memory(_bytes!))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _ampliar,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 100,
          height: 100,
          color: Colors.black12,
          child: _bytes == null
              ? Icon(widget.foto['pendiente'] == true ? Icons.cloud_upload : Icons.image, size: 36, color: Colors.black38)
              : Image.memory(_bytes!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
