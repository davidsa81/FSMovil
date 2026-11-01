import 'dart:io';

import '../api/api.dart';
import 'cola.dart';
import 'estado.dart';

/// Resultado de una carga: los datos y si vienen de la copia guardada en el móvil.
class Cargado<T> {
  final T datos;
  final bool desdeCache;

  Cargado(this.datos, this.desdeCache);
}

/// Acceso a los partes: servidor si hay cobertura, copia local si no.
class RepoPartes {
  static const modulo = 'partes';
  static Estado get _estado => Estado.instancia;

  static Future<Cargado<Map<String, dynamic>>> listar({bool cerrados = false}) async {
    final clave = cerrados ? 'partes_cerrados' : 'partes';
    final api = _estado.api;
    try {
      if (api == null) throw SinConexion('sin sesión');
      final r = await api.get('api/m/partes/partes', cerrados ? {'cerrados': '1'} : null);
      await _estado.guardarCache(clave, r);
      return Cargado(r, false);
    } on SinConexion {
      final cache = await _estado.leerCache(clave);
      if (cache == null) rethrow;
      return Cargado(cache, true);
    }
  }

  static Future<Cargado<Map<String, dynamic>>> detalle(int id) async {
    final api = _estado.api;
    try {
      if (api == null) throw SinConexion('sin sesión');
      // con cambios pendientes de este parte, la copia local es la más actual
      if (_pendientesDe(id)) {
        await Cola.instancia.sincronizar();
        if (_pendientesDe(id)) throw SinConexion('pendiente');
      }
      final r = await api.get('api/m/partes/partes/$id');
      final parte = Map<String, dynamic>.from(r['parte'] as Map);
      await _estado.guardarCache('parte_$id', parte);
      return Cargado(parte, false);
    } on SinConexion {
      final cache = await _estado.leerCache('parte_$id');
      if (cache == null) rethrow;
      return Cargado(cache, true);
    }
  }

  static bool _pendientesDe(int id) =>
      Cola.instancia.pendientes.any((a) => a.modulo == modulo && a.ruta.length > 1 && a.ruta[1] == '$id');

  /// Ejecuta una acción sobre un parte. Si no hay cobertura, se guarda en la cola y se
  /// actualiza la copia local para que el empleado vea el cambio.
  static Future<ResultadoAccion> accion(
    int id,
    List<String> ruta, {
    Map<String, dynamic> datos = const {},
    String metodo = 'POST',
    required String descripcion,
    File? foto,
  }) async {
    final resultado = await Cola.instancia.ejecutar(
      modulo: modulo,
      ruta: ['partes', '$id', ...ruta],
      datos: datos,
      metodo: metodo,
      descripcion: descripcion,
      foto: foto,
    );
    if (resultado.pendiente) await _aplicarEnLocal(id, ruta, datos, metodo, foto);
    return resultado;
  }

  static Future<void> _aplicarEnLocal(int id, List<String> ruta, Map<String, dynamic> datos, String metodo, File? foto) async {
    final parte = await _estado.leerCache('parte_$id');
    if (parte == null) return;
    final ahora = fechaConZona();
    final trabajos = List<Map<String, dynamic>>.from(((parte['trabajos'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)));
    final materiales = List<Map<String, dynamic>>.from(((parte['materiales'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)));

    switch (ruta.first) {
      case 'iniciar':
        if (parte['trabajando'] != true) {
          parte['trabajando'] = true;
          trabajos.add({
            'id': null,
            'descripcion': (datos['descripcion'] ?? parte['servicio'] ?? 'Trabajo').toString(),
            'empleado': _estado.sesion?.nombre ?? '',
            'codempleado': _estado.sesion?.codagente ?? '',
            'inicio': ahora,
            'fin': null,
            'horas': 0,
            'mio': true,
            'en_curso': true,
            'pendiente': true,
          });
        }
        break;
      case 'terminar':
        parte['trabajando'] = false;
        for (final t in trabajos) {
          if (t['mio'] == true && t['en_curso'] == true) {
            t['en_curso'] = false;
            t['fin'] = ahora;
            t['pendiente'] = true;
            final inicio = DateTime.tryParse('${t['inicio']}');
            if (inicio != null) t['horas'] = DateTime.now().difference(inicio).inMinutes / 60;
            if ((datos['descripcion'] ?? '').toString().isNotEmpty) t['descripcion'] = datos['descripcion'];
          }
        }
        break;
      case 'materiales':
        if (metodo == 'DELETE' && ruta.length > 1) {
          materiales.removeWhere((m) => '${m['id']}' == ruta[1]);
        } else {
          materiales.add({
            'id': null,
            'referencia': (datos['referencia'] ?? '').toString(),
            'descripcion': (datos['descripcion'] ?? datos['referencia'] ?? '').toString(),
            'cantidad': datos['cantidad'] ?? 1,
            'pendiente': true,
          });
        }
        break;
      case 'observaciones':
        final texto = (datos['texto'] ?? '').toString();
        parte['observaciones'] = '${parte['observaciones'] ?? ''}\n[pendiente de enviar] $texto'.trim();
        break;
      case 'firmar':
        parte['firma'] = {'firmado': true, 'nombre': datos['nombre'], 'fecha': ahora};
        parte['firmado'] = true;
        break;
      case 'fotos':
        final fotos = List<dynamic>.from((parte['fotos'] as List?) ?? []);
        fotos.add({'id': null, 'nombre': 'Foto pendiente de enviar', 'local': foto?.path, 'pendiente': true});
        parte['fotos'] = fotos;
        break;
    }
    parte['trabajos'] = trabajos;
    parte['materiales'] = materiales;
    await _estado.guardarCache('parte_$id', parte);
  }

  static Future<List<Map<String, dynamic>>> buscarArticulos(String texto) async {
    final api = _estado.api;
    if (api == null) return [];
    final r = await api.get('api/m/partes/articulos', {'q': texto});
    return ((r['articulos'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<List<int>> foto(int idParte, int idFoto) async {
    final api = _estado.api;
    if (api == null) throw SinConexion('sin sesión');
    return api.bytes('api/m/partes/partes/$idParte/fotos/$idFoto');
  }
}
