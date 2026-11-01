import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Lectura y escritura de JSON en la carpeta privada de la app (caché y cola offline).
class Archivos {
  static Directory? _dir;

  static Future<Directory> carpeta([String sub = '']) async {
    _dir ??= await getApplicationDocumentsDirectory();
    final d = Directory(sub.isEmpty ? _dir!.path : '${_dir!.path}/$sub');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<dynamic> leer(String nombre) async {
    try {
      final f = File('${(await carpeta()).path}/$nombre');
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  static Future<void> escribir(String nombre, dynamic datos) async {
    final f = File('${(await carpeta()).path}/$nombre');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(datos), flush: true);
    await tmp.rename(f.path);
  }

  static Future<void> borrarTodo() async {
    final d = await carpeta();
    for (final e in d.listSync()) {
      try {
        await e.delete(recursive: true);
      } catch (_) {}
    }
  }
}
