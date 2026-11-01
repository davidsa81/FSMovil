import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'estado.dart';

/// Notificaciones push (Firebase Cloud Messaging).
///
/// Si la app se compiló sin google-services.json, Firebase no arranca y la app funciona
/// igual: los avisos se ven al abrirla.
class Push {
  static final Push instancia = Push._();

  Push._();

  bool disponible = false;
  String? _ultimoTokenEnviado;

  /// Se llama al pulsar una notificación (o al abrir la app desde ella) con sus datos.
  void Function(Map<String, dynamic> datos)? alAbrir;

  /// Se llama al recibir un aviso con la app abierta (título, mensaje, datos).
  void Function(String titulo, String mensaje, Map<String, dynamic> datos)? alRecibir;

  Future<void> arrancar() async {
    try {
      await Firebase.initializeApp();
      disponible = true;
    } catch (e) {
      debugPrint('Push no disponible: $e');
      disponible = false;
      return;
    }

    final fm = FirebaseMessaging.instance;
    FirebaseMessaging.onMessage.listen((m) {
      alRecibir?.call(m.notification?.title ?? 'Aviso', m.notification?.body ?? '', Map<String, dynamic>.from(m.data));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => alAbrir?.call(Map<String, dynamic>.from(m.data)));
    fm.onTokenRefresh.listen((t) => _enviarToken(t, forzar: true));

    // la app se abrió pulsando una notificación
    try {
      final inicial = await fm.getInitialMessage();
      if (inicial != null) {
        // esperamos a que la primera pantalla esté lista
        Timer(const Duration(milliseconds: 800), () => alAbrir?.call(Map<String, dynamic>.from(inicial.data)));
      }
    } catch (_) {}
  }

  /// Pide permiso (Android 13+) y registra el token en el servidor. Se llama tras enlazar y al abrir la app.
  Future<void> registrar() async {
    if (!disponible || Estado.instancia.sesion == null) return;
    try {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _enviarToken(token);
    } catch (e) {
      debugPrint('No se pudo registrar el push: $e');
    }
  }

  Future<void> _enviarToken(String token, {bool forzar = false}) async {
    if (!forzar && token == _ultimoTokenEnviado) return;
    final api = Estado.instancia.api;
    if (api == null) return;
    try {
      await api.post('api/dispositivo', {'fcm_token': token, 'version_app': Estado.instancia.versionApp});
      _ultimoTokenEnviado = token;
    } catch (_) {
      // sin cobertura: se reintenta la próxima vez que se abra la app
    }
  }
}
