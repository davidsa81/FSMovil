import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Error devuelto por el servidor (respuesta con código HTTP de error).
class ApiError implements Exception {
  final int http;
  final String codigo;
  final String mensaje;

  ApiError(this.http, this.codigo, this.mensaje);

  /// 401: el móvil ya no está enlazado (token caducado o desactivado).
  bool get desenlazado => http == 401;

  /// Error definitivo: repetir la acción no servirá de nada.
  bool get definitivo => http >= 400 && http < 500;

  @override
  String toString() => mensaje.isNotEmpty ? mensaje : 'Error $http ($codigo)';
}

/// No se ha podido hablar con el servidor (sin cobertura, servidor caído...).
class SinConexion implements Exception {
  final String detalle;

  SinConexion(this.detalle);

  @override
  String toString() => 'Sin conexión con el servidor';
}

/// Cliente de la API del plugin AppMovil de FacturaScripts.
class Api {
  static const Duration timeout = Duration(seconds: 20);
  static const Duration timeoutSubida = Duration(seconds: 90);

  final String baseUrl;
  final String? token;

  Api(this.baseUrl, [this.token]);

  Uri _uri(String ruta, [Map<String, String>? query]) {
    final limpia = ruta.startsWith('/') ? ruta.substring(1) : ruta;
    final uri = Uri.parse('$baseUrl/appmovil/$limpia');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> _cabeceras({String? accionId, String? fecha, bool json = true}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    if (token != null) h['X-AppMovil-Token'] = token!;
    if (accionId != null) h['X-Accion-Id'] = accionId;
    if (fecha != null) h['X-Fecha-Dispositivo'] = fecha;
    return h;
  }

  Future<Map<String, dynamic>> get(String ruta, [Map<String, String>? query]) {
    return _enviar(() => http.get(_uri(ruta, query), headers: _cabeceras(json: false)), timeout);
  }

  Future<Map<String, dynamic>> post(String ruta, Map<String, dynamic> datos,
      {String? accionId, String? fecha}) {
    return _enviar(
      () => http.post(_uri(ruta),
          headers: _cabeceras(accionId: accionId, fecha: fecha), body: jsonEncode(datos)),
      timeout,
    );
  }

  Future<Map<String, dynamic>> enviar(String metodo, String ruta, Map<String, dynamic> datos,
      {String? accionId, String? fecha}) {
    if (metodo == 'DELETE') {
      return _enviar(
        () => http.delete(_uri(ruta),
            headers: _cabeceras(accionId: accionId, fecha: fecha), body: jsonEncode(datos)),
        timeout,
      );
    }
    return post(ruta, datos, accionId: accionId, fecha: fecha);
  }

  /// Sube un archivo (multipart) con el campo indicado.
  Future<Map<String, dynamic>> subir(String ruta, String campo, File archivo,
      {String? accionId, String? fecha}) {
    return _enviar(() async {
      final peticion = http.MultipartRequest('POST', _uri(ruta));
      peticion.headers.addAll(_cabeceras(accionId: accionId, fecha: fecha, json: false));
      peticion.files.add(await http.MultipartFile.fromPath(campo, archivo.path));
      final respuesta = await peticion.send();
      return http.Response.fromStream(respuesta);
    }, timeoutSubida);
  }

  /// Descarga binaria (fotos).
  Future<List<int>> bytes(String ruta) async {
    try {
      final r = await http.get(_uri(ruta), headers: _cabeceras(json: false)).timeout(timeout);
      if (r.statusCode != 200) throw ApiError(r.statusCode, 'http', 'No se pudo descargar');
      return r.bodyBytes;
    } on ApiError {
      rethrow;
    } catch (e) {
      throw SinConexion(e.toString());
    }
  }

  Future<Map<String, dynamic>> _enviar(Future<http.Response> Function() peticion, Duration limite) async {
    http.Response r;
    try {
      r = await peticion().timeout(limite);
    } on TimeoutException catch (e) {
      throw SinConexion(e.toString());
    } on SocketException catch (e) {
      throw SinConexion(e.toString());
    } on HandshakeException catch (e) {
      throw SinConexion(e.toString());
    } on http.ClientException catch (e) {
      throw SinConexion(e.toString());
    }

    Map<String, dynamic> cuerpo = {};
    try {
      final decodificado = jsonDecode(utf8.decode(r.bodyBytes));
      if (decodificado is Map<String, dynamic>) cuerpo = decodificado;
    } catch (_) {
      // respuesta que no es JSON (página de error del hosting, etc.)
      if (r.statusCode >= 500 || r.statusCode == 0) {
        throw ApiError(r.statusCode, 'servidor', 'El servidor no responde correctamente (${r.statusCode}).');
      }
      if (r.statusCode >= 400) {
        throw ApiError(r.statusCode, 'servidor', 'Respuesta inesperada del servidor (${r.statusCode}).');
      }
      throw ApiError(500, 'servidor', 'Respuesta inesperada del servidor.');
    }

    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.headers['x-duplicado'] == '1') cuerpo['_duplicado'] = true;
      return cuerpo;
    }
    throw ApiError(r.statusCode, (cuerpo['error'] ?? 'error').toString(), (cuerpo['mensaje'] ?? '').toString());
  }

  /// Extrae la dirección del servidor y el código del contenido de un QR.
  /// El QR es `https://servidor/ruta-fs/appmovil/enlazar?c=CODIGO`.
  static ({String base, String codigo})? leerQr(String contenido) {
    final uri = Uri.tryParse(contenido.trim());
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) return null;
    final codigo = uri.queryParameters['c'] ?? '';
    final pos = uri.path.indexOf('/appmovil/enlazar');
    if (pos < 0 || !RegExp(r'^[a-f0-9]{32}$').hasMatch(codigo)) return null;
    final base = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.substring(0, pos),
    ).toString();
    return (base: base.endsWith('/') ? base.substring(0, base.length - 1) : base, codigo: codigo);
  }
}

/// Fecha y hora local con la zona horaria (2026-11-01T09:00:00+01:00), para que el servidor
/// sepa la hora real en que se hizo la acción.
String fechaConZona([DateTime? fecha]) {
  final f = fecha ?? DateTime.now();
  String dos(int n) => n.toString().padLeft(2, '0');
  final off = f.timeZoneOffset;
  final signo = off.isNegative ? '-' : '+';
  final horas = dos(off.inHours.abs());
  final minutos = dos(off.inMinutes.abs() % 60);
  return '${f.year}-${dos(f.month)}-${dos(f.day)}T${dos(f.hour)}:${dos(f.minute)}:${dos(f.second)}$signo$horas:$minutos';
}
