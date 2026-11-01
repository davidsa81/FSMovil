import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../../widgets/comunes.dart';

/// Firma del cliente en la pantalla. Devuelve {nombre, firma: data:image/png;base64,...}.
class PantallaFirma extends StatefulWidget {
  const PantallaFirma({super.key});

  @override
  State<PantallaFirma> createState() => _PantallaFirmaState();
}

class _PantallaFirmaState extends State<PantallaFirma> {
  final _nombre = TextEditingController();
  late final SignatureController _firma;

  @override
  void initState() {
    super.initState();
    _firma = SignatureController(
      penStrokeWidth: 3.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _firma.dispose();
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty) {
      mostrarMensaje(context, 'Escribe el nombre de quien firma', error: true);
      return;
    }
    if (_firma.isEmpty) {
      mostrarMensaje(context, 'Falta la firma', error: true);
      return;
    }
    final png = await _firma.toPngBytes();
    if (png == null || !mounted) return;
    final datos = 'data:image/png;base64,${base64Encode(png)}';
    if (datos.length > 290000) {
      mostrarMensaje(context, 'La firma es demasiado grande. Bórrala y firma más sencillo.', error: true);
      return;
    }
    Navigator.pop(context, <String, dynamic>{'nombre': _nombre.text.trim(), 'firma': datos});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firma del cliente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nombre,
            style: const TextStyle(fontSize: 21),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre de quien firma', prefixIcon: Icon(Icons.person, size: 30)),
          ),
          const SizedBox(height: 16),
          const Text('Firme dentro del recuadro', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.black54, width: 2), borderRadius: BorderRadius.circular(8)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Signature(controller: _firma, height: 320, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _firma.clear(),
              icon: const Icon(Icons.refresh, size: 28),
              label: const Text('Borrar firma', style: TextStyle(fontSize: 19)),
            ),
          ),
          const SizedBox(height: 12),
          BotonGrande(texto: 'Guardar firma', icono: Icons.check, color: Colores.verde, alto: 84, onPressed: _guardar),
        ],
      ),
    );
  }
}
