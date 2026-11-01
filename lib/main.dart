import 'package:flutter/material.dart';

import 'datos/estado.dart';
import 'datos/push.dart';
import 'pantallas/avisos.dart';
import 'pantallas/enlazar.dart';
import 'pantallas/inicio.dart';
import 'pantallas/partes/detalle_parte.dart';
import 'widgets/comunes.dart';

final navegador = GlobalKey<NavigatorState>();
final mensajero = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Estado.instancia.arrancar();
  await Push.instancia.arrancar();
  runApp(const FSMovil());
}

class FSMovil extends StatefulWidget {
  const FSMovil({super.key});

  @override
  State<FSMovil> createState() => _FSMovilState();
}

class _FSMovilState extends State<FSMovil> {
  @override
  void initState() {
    super.initState();
    Estado.instancia.alDesenlazar = () {
      navegador.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PantallaEnlazar(motivo: 'Este móvil se ha desenlazado. Vuelve a escanear el código QR.')),
        (_) => false,
      );
    };

    final push = Push.instancia;
    push.alAbrir = _abrirDesdeAviso;
    push.alRecibir = (titulo, mensaje, datos) {
      // con la app abierta Android no muestra la notificación: la enseñamos nosotros
      Estado.instancia.cargarInicio();
      mensajero.currentState?.showSnackBar(SnackBar(
        content: Text(mensaje.isEmpty ? titulo : '$titulo\n$mensaje', style: const TextStyle(fontSize: 19)),
        backgroundColor: Colores.naranja,
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'VER', textColor: Colors.white, onPressed: () => _abrirDesdeAviso(datos)),
      ));
    };
    push.registrar();
  }

  /// Abre la pantalla que corresponde al aviso (el parte, o la lista de avisos).
  void _abrirDesdeAviso(Map<String, dynamic> datos) {
    final nav = navegador.currentState;
    if (nav == null || Estado.instancia.sesion == null) return;
    final id = int.tryParse('${datos['id'] ?? ''}');
    if (datos['modulo'] == 'partes' && id != null) {
      nav.push(MaterialPageRoute(builder: (_) => PantallaDetalleParte(id: id)));
    } else {
      nav.push(MaterialPageRoute(builder: (_) => const PantallaAvisos()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colores.primario),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'FSMovil',
      navigatorKey: navegador,
      scaffoldMessengerKey: mensajero,
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: Colores.fondo,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colores.primario,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.white),
          toolbarHeight: 64,
        ),
        textTheme: base.textTheme.apply(fontSizeFactor: 1.15),
        listTileTheme: const ListTileThemeData(
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
          subtitleTextStyle: TextStyle(fontSize: 17, color: Colors.black54),
          minVerticalPadding: 12,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
      home: Estado.instancia.sesion == null ? const PantallaEnlazar() : const PantallaInicio(),
    );
  }
}
