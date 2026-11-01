import 'package:flutter/material.dart';

/// Colores de la app.
class Colores {
  static const primario = Color(0xFF1565C0);
  static const fondo = Color(0xFFF4F6F8);
  static const verde = Color(0xFF2E7D32);
  static const rojo = Color(0xFFC62828);
  static const naranja = Color(0xFFE65100);
}

Color colorDesdeHex(String? hex, [Color defecto = Colores.primario]) {
  if (hex == null) return defecto;
  final limpio = hex.replaceAll('#', '');
  if (limpio.length != 6) return defecto;
  final valor = int.tryParse(limpio, radix: 16);
  return valor == null ? defecto : Color(0xFF000000 | valor);
}

/// Texto blanco o negro según el fondo.
Color textoSobre(Color fondo) => fondo.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;

/// Iconos que pueden pedir los módulos (por su nombre de Material Icons).
IconData iconoDesdeNombre(String? nombre) {
  const iconos = <String, IconData>{
    'build': Icons.build,
    'handyman': Icons.handyman,
    'construction': Icons.construction,
    'engineering': Icons.engineering,
    'plumbing': Icons.plumbing,
    'electrical_services': Icons.electrical_services,
    'ac_unit': Icons.ac_unit,
    'assignment': Icons.assignment,
    'inventory_2': Icons.inventory_2,
    'inventory': Icons.inventory,
    'precision_manufacturing': Icons.precision_manufacturing,
    'settings': Icons.settings,
    'calendar_month': Icons.calendar_month,
    'event': Icons.event,
    'receipt_long': Icons.receipt_long,
    'local_shipping': Icons.local_shipping,
    'person': Icons.person,
    'people': Icons.people,
    'cleaning_services': Icons.cleaning_services,
    'description': Icons.description,
    'checklist': Icons.checklist,
    'qr_code': Icons.qr_code,
    'apps': Icons.apps,
  };
  return iconos[nombre] ?? Icons.apps;
}

/// Botón grande a todo el ancho, con icono.
class BotonGrande extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback? onPressed;
  final Color color;
  final String? subtitulo;
  final double alto;

  const BotonGrande({
    super.key,
    required this.texto,
    required this.icono,
    required this.onPressed,
    this.color = Colores.primario,
    this.subtitulo,
    this.alto = 76,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textoSobre(color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: fg,
            disabledBackgroundColor: Colors.grey.shade300,
            minimumSize: Size.fromHeight(alto),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
          child: Row(
            children: [
              Icon(icono, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(texto, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    if (subtitulo != null && subtitulo!.isNotEmpty)
                      Text(subtitulo!, style: TextStyle(fontSize: 16, color: fg.withValues(alpha: 0.9))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso grande en la parte inferior.
void mostrarMensaje(BuildContext context, String texto, {bool error = false, bool aviso = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(texto, style: const TextStyle(fontSize: 19)),
    backgroundColor: error ? Colores.rojo : (aviso ? Colores.naranja : Colores.verde),
    duration: Duration(seconds: error ? 6 : 4),
    behavior: SnackBarBehavior.floating,
  ));
}

Future<bool> confirmar(BuildContext context, String titulo, String texto, {String si = 'Sí', String no = 'No'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo, style: const TextStyle(fontSize: 24)),
      content: Text(texto, style: const TextStyle(fontSize: 20)),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(no, style: const TextStyle(fontSize: 20)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(c, true),
          style: ElevatedButton.styleFrom(minimumSize: const Size(120, 56)),
          child: Text(si, style: const TextStyle(fontSize: 20)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Pide un texto en un diálogo grande.
Future<String?> pedirTexto(BuildContext context, String titulo,
    {String inicial = '', String pista = '', int lineas = 3, String boton = 'Guardar'}) async {
  final controlador = TextEditingController(text: inicial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo, style: const TextStyle(fontSize: 24)),
      content: TextField(
        controller: controlador,
        autofocus: true,
        minLines: 1,
        maxLines: lineas,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 20),
        decoration: InputDecoration(hintText: pista, border: const OutlineInputBorder()),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancelar', style: TextStyle(fontSize: 20)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(c, controlador.text.trim()),
          style: ElevatedButton.styleFrom(minimumSize: const Size(120, 56)),
          child: Text(boton, style: const TextStyle(fontSize: 20)),
        ),
      ],
    ),
  );
  return r;
}

/// "hoy 10:00", "mañana 09:30", "05/11 16:00"
String formatoFecha(String? iso, {bool conHora = true}) {
  if (iso == null || iso.isEmpty) return '';
  final f = DateTime.tryParse(iso)?.toLocal();
  if (f == null) return '';
  String dos(int n) => n.toString().padLeft(2, '0');
  final hoy = DateTime.now();
  final dia = DateTime(f.year, f.month, f.day);
  final diferencia = dia.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  final hora = conHora && (f.hour != 0 || f.minute != 0) ? ' ${dos(f.hour)}:${dos(f.minute)}' : '';
  if (diferencia == 0) return 'Hoy$hora';
  if (diferencia == 1) return 'Mañana$hora';
  if (diferencia == -1) return 'Ayer$hora';
  return '${dos(f.day)}/${dos(f.month)}${f.year != hoy.year ? '/${f.year}' : ''}$hora';
}

String formatoHoras(num? horas) {
  if (horas == null) return '';
  final total = (horas * 60).round();
  final h = total ~/ 60;
  final m = total % 60;
  return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}min' : '${m}min';
}

/// Etiqueta de color (estado del parte).
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;

  const Etiqueta(this.texto, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: textoSobre(color), fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }
}

/// Banda con lo que está pendiente de enviar.
class Cargando extends StatelessWidget {
  final String texto;

  const Cargando([this.texto = 'Cargando...', Key? key]) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(strokeWidth: 5),
        const SizedBox(height: 16),
        Text(texto, style: const TextStyle(fontSize: 20)),
      ]),
    );
  }
}

/// Ejecuta una acción mostrando un diálogo de espera.
Future<T> conEspera<T>(BuildContext context, Future<T> Function() tarea, {String texto = 'Enviando...'}) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 20))),
        ]),
      ),
    ),
  );
  try {
    return await tarea();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
