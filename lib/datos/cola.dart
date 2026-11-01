import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/api.dart';
import 'archivos.dart';

/// Una acción hecha por el empleado que hay que enviar al servidor.
class Accion {
  final String id;
  final String modulo;
  final String metodo;
  final List<String> ruta;
  final Map<String, dynamic> datos;
  final String fecha;
  final String descripcion;

  /// Ruta local de una foto (si la acción es subir una foto).
  final String? foto;

  Accion({
    required this.id,
    required this.modulo,
    required this.metodo,
    required this.ruta,
    required this.datos,
    required this.fecha,
    required this.descripcion,
    this.foto,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'modulo': modulo,
        'metodo': metodo,
        'ruta': ruta,
        'datos': datos,
        'fecha': fecha,
        'descripcion': descripcion,
        'foto': foto,
      };

  static Accion fromJson(Map<String, dynamic> j) => Accion(
        id: j['id'].toString(),
        modulo: j['modulo'].toString(),
        metodo: (j['metodo'] ?? 'POST').toString(),
        ruta: List<String>.from((j['ruta'] as List).map((e) => e.toString())),
        datos: Map<String, dynamic>.from(j['datos'] as Map? ?? {}),
        fecha: j['fecha'].toString(),
        descripcion: (j['descripcion'] ?? '').toString(),
        foto: j['foto'] as String?,
      );
}

enum EstadoAccion { hecha, error, pendiente }

class ResultadoAccion {
  final EstadoAccion estado;
  final Map<String, dynamic> respuesta;
  final String mensaje;

  const ResultadoAccion(this.estado, [this.respuesta = const {}, this.mensaje = '']);

  bool get hecha => estado == EstadoAccion.hecha;
  bool get pendiente => estado == EstadoAccion.pendiente;
}

/// Error definitivo de una acción enviada desde la cola (se muestra al empleado).
class ErrorCola {
  final String descripcion;
  final String mensaje;
  final String fecha;

  ErrorCola(this.descripcion, this.mensaje, this.fecha);

  Map<String, dynamic> toJson() => {'descripcion': descripcion, 'mensaje': mensaje, 'fecha': fecha};

  static ErrorCola fromJson(Map<String, dynamic> j) =>
      ErrorCola((j['descripcion'] ?? '').toString(), (j['mensaje'] ?? '').toString(), (j['fecha'] ?? '').toString());
}

/// Cola de acciones. TODO lo que modifica datos pasa por aquí, haya cobertura o no:
/// así se respeta el orden y cada acción tiene un identificador único (el servidor no la
/// repite aunque llegue dos veces).
class Cola extends ChangeNotifier {
  static final Cola instancia = Cola._();
  static const _archivo = 'cola.json';
  static const _archivoErrores = 'cola_errores.json';
  static const _maxLote = 50;

  Cola._();

  final List<Accion> _pendientes = [];
  final List<ErrorCola> _errores = [];
  final Map<String, ResultadoAccion> _resultados = {};
  Future<void>? _sincronizando;

  /// Se llama cuando el servidor dice que el móvil ya no está enlazado.
  VoidCallback? alDesenlazar;

  /// Se llama cada vez que se envían acciones (para refrescar pantallas).
  VoidCallback? alEnviar;

  Api? Function()? obtenerApi;

  List<Accion> get pendientes => List.unmodifiable(_pendientes);
  List<ErrorCola> get errores => List.unmodifiable(_errores);
  bool get sincronizando => _sincronizando != null;

  Future<void> cargar() async {
    final lista = await Archivos.leer(_archivo);
    _pendientes.clear();
    if (lista is List) {
      for (final j in lista) {
        try {
          _pendientes.add(Accion.fromJson(Map<String, dynamic>.from(j as Map)));
        } catch (_) {}
      }
    }
    final errores = await Archivos.leer(_archivoErrores);
    _errores.clear();
    if (errores is List) {
      for (final j in errores) {
        _errores.add(ErrorCola.fromJson(Map<String, dynamic>.from(j as Map)));
      }
    }
    notifyListeners();
  }

  Future<void> vaciar() async {
    _pendientes.clear();
    _errores.clear();
    await _guardar();
    notifyListeners();
  }

  Future<void> borrarErrores() async {
    _errores.clear();
    await Archivos.escribir(_archivoErrores, []);
    notifyListeners();
  }

  /// Añade una acción y trata de enviarla en el momento.
  /// Devuelve hecha, error (definitivo) o pendiente (se enviará cuando haya cobertura).
  Future<ResultadoAccion> ejecutar({
    required String modulo,
    required List<String> ruta,
    Map<String, dynamic> datos = const {},
    String metodo = 'POST',
    required String descripcion,
    File? foto,
  }) async {
    String? rutaFoto;
    if (foto != null) {
      // copiamos la foto a la carpeta de la app: la original puede borrarse
      final carpeta = await Archivos.carpeta('fotos');
      final destino = File('${carpeta.path}/${const Uuid().v4()}.jpg');
      await foto.copy(destino.path);
      rutaFoto = destino.path;
    }

    final accion = Accion(
      id: const Uuid().v4(),
      modulo: modulo,
      metodo: metodo,
      ruta: ruta,
      datos: datos,
      fecha: fechaConZona(),
      descripcion: descripcion,
      foto: rutaFoto,
    );
    _pendientes.add(accion);
    await _guardar();
    notifyListeners();

    await sincronizar();
    // si había un envío en marcha que terminó antes de llegar a esta acción, lo intentamos otra vez
    if (_pendientes.any((p) => p.id == accion.id)) await sincronizar();
    return _resultados.remove(accion.id) ?? const ResultadoAccion(EstadoAccion.pendiente);
  }

  /// Envía todo lo pendiente, en orden. Si ya se está enviando, espera a que termine.
  Future<void> sincronizar() {
    return _sincronizando ??= _enviarPendientes().whenComplete(() {
      _sincronizando = null;
      notifyListeners();
    });
  }

  Future<void> _enviarPendientes() async {
    final api = obtenerApi?.call();
    if (api == null) return;
    notifyListeners();

    var enviado = false;
    try {
      while (_pendientes.isNotEmpty) {
        final primera = _pendientes.first;
        if (primera.foto != null) {
          if (!await _enviarFoto(api, primera)) break;
        } else {
          final lote = <Accion>[];
          for (final a in _pendientes) {
            if (a.foto != null || lote.length >= _maxLote) break;
            lote.add(a);
          }
          if (!await _enviarLote(api, lote)) break;
        }
        enviado = true;
      }
    } on ApiError catch (e) {
      if (e.desenlazado) alDesenlazar?.call();
    } on SinConexion {
      // se reintentará más tarde
    } finally {
      await _guardar();
      if (enviado) alEnviar?.call();
    }
  }

  /// Devuelve false si hay que parar (error temporal).
  Future<bool> _enviarFoto(Api api, Accion a) async {
    final archivo = File(a.foto!);
    if (!await archivo.exists()) {
      _terminar(a, ResultadoAccion(EstadoAccion.error, const {}, 'La foto ya no está en el móvil.'));
      return true;
    }
    try {
      final r = await api.subir('api/m/${a.modulo}/${a.ruta.join('/')}', 'foto', archivo,
          accionId: a.id, fecha: a.fecha);
      _terminar(a, ResultadoAccion(EstadoAccion.hecha, r));
      try {
        await archivo.delete();
      } catch (_) {}
      return true;
    } on ApiError catch (e) {
      if (e.desenlazado) rethrow;
      if (e.definitivo) {
        _terminar(a, ResultadoAccion(EstadoAccion.error, const {}, e.toString()));
        return true;
      }
      return false;
    }
  }

  Future<bool> _enviarLote(Api api, List<Accion> lote) async {
    final r = await api.post('api/lote', {
      'acciones': lote
          .map((a) => {
                'id': a.id,
                'modulo': a.modulo,
                'metodo': a.metodo,
                'ruta': a.ruta,
                'datos': a.datos,
                'fecha': a.fecha,
              })
          .toList(),
    });

    var seguir = true;
    final resultados = (r['resultados'] as List?) ?? [];
    final porId = <String, Map<String, dynamic>>{};
    for (final item in resultados) {
      final m = Map<String, dynamic>.from(item as Map);
      porId[m['id'].toString()] = m;
    }

    for (final a in lote) {
      final res = porId[a.id];
      if (res == null) {
        seguir = false;
        continue;
      }
      final http = (res['http'] as num?)?.toInt() ?? 500;
      final respuesta = Map<String, dynamic>.from(res['respuesta'] as Map? ?? {});
      if (http >= 200 && http < 300) {
        _terminar(a, ResultadoAccion(EstadoAccion.hecha, respuesta));
      } else if (http >= 400 && http < 500) {
        _terminar(a, ResultadoAccion(EstadoAccion.error, respuesta, (respuesta['mensaje'] ?? 'Error').toString()));
      } else {
        // error temporal del servidor: se queda en la cola y paramos para no alterar el orden
        seguir = false;
        break;
      }
    }
    return seguir;
  }

  void _terminar(Accion a, ResultadoAccion resultado) {
    _pendientes.removeWhere((p) => p.id == a.id);
    if (_resultados.length > 200) _resultados.clear();
    _resultados[a.id] = resultado;
    if (resultado.estado == EstadoAccion.error) {
      _errores.insert(0, ErrorCola(a.descripcion, resultado.mensaje, a.fecha));
      if (_errores.length > 30) _errores.removeRange(30, _errores.length);
    }
  }

  Future<void> _guardar() async {
    await Archivos.escribir(_archivo, _pendientes.map((a) => a.toJson()).toList());
    await Archivos.escribir(_archivoErrores, _errores.map((e) => e.toJson()).toList());
  }
}
