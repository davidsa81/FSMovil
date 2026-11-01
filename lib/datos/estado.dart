import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api.dart';
import 'archivos.dart';
import 'cola.dart';
import 'sesion.dart';

/// Estado global de la app: enlace con el servidor, datos de inicio y caché.
class Estado extends ChangeNotifier {
  static final Estado instancia = Estado._();

  Estado._();

  Sesion? sesion;
  Map<String, dynamic>? inicio;
  bool sinConexion = false;
  String versionApp = '';
  int buildApp = 0;

  /// Se llama cuando el servidor desenlaza el móvil (para volver a la pantalla del QR).
  VoidCallback? alDesenlazar;

  Timer? _temporizador;

  Api? get api => sesion == null ? null : Api(sesion!.baseUrl, sesion!.token);

  Future<void> arrancar() async {
    try {
      final info = await PackageInfo.fromPlatform();
      versionApp = info.version;
      buildApp = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {}

    sesion = await AlmacenSesion.cargar();
    final cola = Cola.instancia;
    cola.obtenerApi = () => api;
    cola.alDesenlazar = () => desenlazado();
    await cola.cargar();
    inicio = await Archivos.leer('cache_inicio.json') as Map<String, dynamic>?;

    // reintento periódico de la cola mientras la app está abierta
    _temporizador?.cancel();
    _temporizador = Timer.periodic(const Duration(minutes: 1), (_) {
      if (sesion != null && cola.pendientes.isNotEmpty) cola.sincronizar();
    });
  }

  /// Canjea el código del QR por un token.
  Future<void> enlazar(String base, String codigo) async {
    final info = await _infoDispositivo();
    final r = await Api(base).post('api/enlazar', {'codigo': codigo, 'dispositivo': info});
    final agente = Map<String, dynamic>.from(r['agente'] as Map);
    final servidor = Map<String, dynamic>.from(r['servidor'] as Map? ?? {});
    final ultimo = await AlmacenSesion.ultimoEnlace();
    sesion = Sesion(
      baseUrl: base,
      token: r['token'].toString(),
      codagente: agente['codagente'].toString(),
      nombre: agente['nombre'].toString(),
      empresa: (servidor['empresa'] ?? '').toString(),
    );

    // otro servidor u otro empleado: lo guardado en el móvil ya no sirve
    if (ultimo != null && ultimo != '$base|${sesion!.codagente}') {
      await Cola.instancia.vaciar();
      await Archivos.borrarTodo();
    }
    await AlmacenSesion.guardar(sesion!);
    inicio = null;
    notifyListeners();
    await cargarInicio();
  }

  Future<void> cargarInicio() async {
    final a = api;
    if (a == null) return;
    try {
      inicio = await a.get('api/inicio');
      sinConexion = false;
      await Archivos.escribir('cache_inicio.json', inicio);
    } on SinConexion {
      sinConexion = true;
    } on ApiError catch (e) {
      if (e.desenlazado) {
        await desenlazado();
        return;
      }
      rethrow;
    } finally {
      notifyListeners();
    }
    // aprovechamos para enviar lo pendiente
    if (Cola.instancia.pendientes.isNotEmpty) unawaited(Cola.instancia.sincronizar());
  }

  /// El empleado pide desenlazar este móvil.
  Future<void> salir() async {
    try {
      await api?.post('api/salir', {});
    } catch (_) {}
    await _olvidar();
  }

  /// El servidor ha rechazado el token (desactivado o caducado).
  Future<void> desenlazado() async {
    await _olvidar();
    alDesenlazar?.call();
  }

  Future<void> _olvidar() async {
    sesion = null;
    inicio = null;
    await AlmacenSesion.borrar();
    notifyListeners();
  }

  Future<Map<String, dynamic>> _infoDispositivo() async {
    final datos = <String, dynamic>{
      'uuid': await AlmacenSesion.uuidMovil(),
      'version_app': versionApp,
      'plataforma': Platform.operatingSystem,
      'modelo': '',
    };
    try {
      if (Platform.isAndroid) {
        final a = await DeviceInfoPlugin().androidInfo;
        datos['modelo'] = '${a.manufacturer} ${a.model}'.trim();
        datos['plataforma'] = 'Android ${a.version.release}';
      }
    } catch (_) {}
    return datos;
  }

  // --- caché de datos de los módulos (para ver los partes sin cobertura) ---

  Future<Map<String, dynamic>?> leerCache(String clave) async {
    final d = await Archivos.leer('cache_$clave.json');
    return d is Map ? Map<String, dynamic>.from(d) : null;
  }

  Future<void> guardarCache(String clave, Map<String, dynamic> datos) => Archivos.escribir('cache_$clave.json', datos);
}
