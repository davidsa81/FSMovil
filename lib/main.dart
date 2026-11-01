import 'package:flutter/material.dart';

import 'datos/estado.dart';
import 'pantallas/enlazar.dart';
import 'pantallas/inicio.dart';
import 'widgets/comunes.dart';

final navegador = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Estado.instancia.arrancar();
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
