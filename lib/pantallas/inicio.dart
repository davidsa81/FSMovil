import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../datos/cola.dart';
import '../datos/estado.dart';
import '../widgets/comunes.dart';
import 'avisos.dart';
import 'enlazar.dart';
import 'partes/lista_partes.dart';
import 'pendientes.dart';
import 'web.dart';

/// Pantalla principal: un botón grande por cada módulo que el empleado tiene activado.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> with WidgetsBindingObserver {
  final _estado = Estado.instancia;
  final _cola = Cola.instancia;
  bool _cargando = false;
  bool _avisoObligatorioMostrado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _estado.addListener(_refrescar);
    _cola.addListener(_refrescar);
    _cargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _estado.removeListener(_refrescar);
    _cola.removeListener(_refrescar);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cargar();
  }

  void _refrescar() {
    if (mounted) setState(() {});
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      await _estado.cargarInicio();
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
    _comprobarActualizacion();
  }

  Map<String, dynamic>? get _actualizacion {
    final a = _estado.inicio?['actualizacion'];
    if (a is! Map) return null;
    final code = (a['version_code'] as num?)?.toInt() ?? 0;
    return code > _estado.buildApp ? Map<String, dynamic>.from(a) : null;
  }

  void _comprobarActualizacion() {
    final a = _actualizacion;
    if (a == null || a['obligatoria'] != true || _avisoObligatorioMostrado || !mounted) return;
    _avisoObligatorioMostrado = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Actualiza la app', style: TextStyle(fontSize: 24)),
          content: Text(
            'Hay una versión nueva (${a['version_nombre']}) que es necesaria para seguir usando FSMovil.\n\n${a['notas'] ?? ''}',
            style: const TextStyle(fontSize: 20),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => _descargar(a),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 56)),
              child: const Text('Descargar', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _descargar(Map<String, dynamic> a) async {
    final url = Uri.tryParse((a['url'] ?? '').toString());
    if (url == null || !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) mostrarMensaje(context, 'No se ha podido abrir la descarga.', error: true);
    }
  }

  Future<void> _abrirModulo(Map<String, dynamic> m) async {
    final codigo = (m['codigo'] ?? '').toString();
    final titulo = (m['titulo'] ?? '').toString();
    final color = colorDesdeHex(m['color']?.toString());
    Widget? pantalla;
    if (m['tipo'] == 'web') {
      pantalla = PantallaWeb(modulo: codigo, titulo: titulo, color: color);
    } else if (codigo == 'partes') {
      pantalla = PantallaListaPartes(titulo: titulo, color: color);
    }
    if (pantalla == null) {
      mostrarMensaje(context, 'Este apartado necesita una versión más nueva de la app.', aviso: true);
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla!));
    _cargar();
  }

  Future<void> _menu(String opcion) async {
    if (opcion == 'salir') {
      final pendientes = _cola.pendientes.length;
      final ok = await confirmar(
        context,
        'Desenlazar este móvil',
        pendientes > 0
            ? 'Tienes $pendientes cambios sin enviar que se perderán. ¿Seguro?'
            : 'Tendrás que volver a escanear un código QR para usar la app. ¿Seguro?',
      );
      if (!ok) return;
      await _cola.vaciar();
      await _estado.salir();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PantallaEnlazar()), (_) => false);
    } else if (opcion == 'acerca') {
      showAboutDialog(
        context: context,
        applicationName: 'FSMovil',
        applicationVersion: '${_estado.versionApp} (${_estado.buildApp})',
        children: [Text('Conectado a ${_estado.sesion?.baseUrl ?? ''}')],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = _estado.sesion;
    final inicio = _estado.inicio;
    final modulos = (inicio?['modulos'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final avisos = (inicio?['avisos_sin_leer'] as num?)?.toInt() ?? 0;
    final nombre = (inicio?['agente']?['nombre'] ?? sesion?.nombre ?? '').toString();
    final actualizacion = _actualizacion;

    return Scaffold(
      appBar: AppBar(
        title: Text(sesion?.empresa.isNotEmpty == true ? sesion!.empresa : 'FSMovil'),
        actions: [
          PopupMenuButton<String>(
            iconSize: 32,
            onSelected: _menu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'acerca', child: Text('Acerca de', style: TextStyle(fontSize: 20))),
              PopupMenuItem(value: 'salir', child: Text('Desenlazar este móvil', style: TextStyle(fontSize: 20))),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hola, ${nombre.split(' ').first}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_estado.sinConexion)
              _Banda(
                icono: Icons.cloud_off,
                color: Colores.naranja,
                texto: 'Sin cobertura. Puedes seguir trabajando: se enviará todo cuando vuelva.',
              ),
            if (_cola.pendientes.isNotEmpty || _cola.errores.isNotEmpty)
              _Banda(
                icono: _cola.errores.isNotEmpty ? Icons.error_outline : Icons.cloud_upload,
                color: _cola.errores.isNotEmpty ? Colores.rojo : Colores.primario,
                texto: [
                  if (_cola.pendientes.isNotEmpty) '${_cola.pendientes.length} cambios pendientes de enviar',
                  if (_cola.errores.isNotEmpty) '${_cola.errores.length} cambios no se pudieron guardar',
                ].join(' · '),
                accion: 'Ver',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaPendientes())),
              ),
            if (actualizacion != null)
              _Banda(
                icono: Icons.system_update,
                color: Colores.verde,
                texto: 'Nueva versión ${actualizacion['version_nombre'] ?? ''} disponible',
                accion: 'Descargar',
                onTap: () => _descargar(actualizacion),
              ),
            const SizedBox(height: 8),
            if (inicio == null && _cargando) const Padding(padding: EdgeInsets.all(40), child: Cargando()),
            if (inicio != null && modulos.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no tienes ningún apartado activado. Avisa en la oficina.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 20)),
              ),
            for (final m in modulos)
              BotonGrande(
                texto: (m['titulo'] ?? '').toString(),
                subtitulo: (m['resumen'] is Map ? m['resumen']['texto'] : null)?.toString(),
                icono: iconoDesdeNombre(m['icono']?.toString()),
                color: colorDesdeHex(m['color']?.toString()),
                alto: 96,
                onPressed: () => _abrirModulo(m),
              ),
            const SizedBox(height: 8),
            BotonGrande(
              texto: 'Avisos',
              subtitulo: avisos > 0 ? '$avisos sin leer' : 'Sin avisos nuevos',
              icono: avisos > 0 ? Icons.notifications_active : Icons.notifications_none,
              color: avisos > 0 ? Colores.naranja : Colors.blueGrey,
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaAvisos()));
                _cargar();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Banda extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String texto;
  final String? accion;
  final VoidCallback? onTap;

  const _Banda({required this.icono, required this.color, required this.texto, this.accion, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.12),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icono, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.w600))),
            if (accion != null) Text(accion!, style: TextStyle(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }
}
