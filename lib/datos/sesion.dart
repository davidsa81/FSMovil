import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Datos del enlace de este móvil con un FacturaScripts.
class Sesion {
  final String baseUrl;
  final String token;
  final String codagente;
  final String nombre;
  final String empresa;

  const Sesion({
    required this.baseUrl,
    required this.token,
    required this.codagente,
    required this.nombre,
    required this.empresa,
  });

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'token': token,
        'codagente': codagente,
        'nombre': nombre,
        'empresa': empresa,
      };

  static Sesion? fromJson(Map<String, dynamic>? j) {
    if (j == null || j['token'] == null || j['baseUrl'] == null) return null;
    return Sesion(
      baseUrl: j['baseUrl'].toString(),
      token: j['token'].toString(),
      codagente: (j['codagente'] ?? '').toString(),
      nombre: (j['nombre'] ?? '').toString(),
      empresa: (j['empresa'] ?? '').toString(),
    );
  }
}

class AlmacenSesion {
  static const _clave = 'sesion';
  static const _claveUuid = 'uuid_movil';
  static const _claveUltimo = 'ultimo_enlace';

  static Future<Sesion?> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_clave);
    if (texto == null) return null;
    try {
      return Sesion.fromJson(jsonDecode(texto) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> guardar(Sesion sesion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(sesion.toJson()));
    await prefs.setString(_claveUltimo, '${sesion.baseUrl}|${sesion.codagente}');
  }

  /// Servidor y empleado del último enlace (se conserva aunque se desenlace).
  static Future<String?> ultimoEnlace() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_claveUltimo);
  }

  static Future<void> borrar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
  }

  /// Identificador fijo de este móvil (se genera la primera vez).
  static Future<String> uuidMovil() async {
    final prefs = await SharedPreferences.getInstance();
    var uuid = prefs.getString(_claveUuid);
    if (uuid == null) {
      uuid = const Uuid().v4();
      await prefs.setString(_claveUuid, uuid);
    }
    return uuid;
  }
}
