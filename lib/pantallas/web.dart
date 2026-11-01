import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api/api.dart';
import '../datos/estado.dart';
import '../widgets/comunes.dart';

/// Visor para los módulos de tipo "web" (páginas HTML que sirve el propio FacturaScripts).
class PantallaWeb extends StatefulWidget {
  final String modulo;
  final String titulo;
  final Color color;
  final String ruta;

  const PantallaWeb({super.key, required this.modulo, required this.titulo, required this.color, this.ruta = ''});

  @override
  State<PantallaWeb> createState() => _PantallaWebState();
}

class _PantallaWebState extends State<PantallaWeb> {
  WebViewController? _controlador;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  Future<void> _abrir() async {
    final estado = Estado.instancia;
    final api = estado.api;
    if (api == null) return;
    try {
      final r = await api.post('api/ticket', {});
      final url = Uri.parse('${estado.sesion!.baseUrl}/appmovil/web/${widget.modulo}/${widget.ruta}')
          .replace(queryParameters: {'ticket': r['ticket'].toString()});
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _cargando = false);
          },
        ))
        ..loadRequest(url);
      setState(() => _controlador = c);
    } on SinConexion {
      setState(() => _error = 'Esta opción necesita cobertura.');
    } on ApiError catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo), backgroundColor: widget.color, foregroundColor: textoSobre(widget.color)),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(fontSize: 20)))
          : Stack(children: [
              if (_controlador != null) WebViewWidget(controller: _controlador!),
              if (_cargando) const Cargando(),
            ]),
    );
  }
}
