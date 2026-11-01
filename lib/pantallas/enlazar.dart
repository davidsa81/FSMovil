import 'package:flutter/material.dart';

import '../api/api.dart';
import '../datos/estado.dart';
import '../widgets/comunes.dart';
import 'escaner.dart';
import 'inicio.dart';

/// Primera pantalla: enlazar el móvil escaneando el QR que da la oficina.
class PantallaEnlazar extends StatefulWidget {
  final String? motivo;

  const PantallaEnlazar({super.key, this.motivo});

  @override
  State<PantallaEnlazar> createState() => _PantallaEnlazarState();
}

class _PantallaEnlazarState extends State<PantallaEnlazar> {
  bool _trabajando = false;
  String? _error;

  Future<void> _escanear() async {
    final leido = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaEscaner(titulo: 'Escanear código QR')),
    );
    if (leido == null || !mounted) return;

    final qr = Api.leerQr(leido);
    if (qr == null) {
      setState(() => _error = 'Ese código no es de FSMovil. Pide en la oficina el QR de la app.');
      return;
    }

    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      await Estado.instancia.enlazar(qr.base, qr.codigo);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PantallaInicio()), (_) => false);
    } on SinConexion {
      setState(() => _error = 'No se puede conectar con ${qr.base}. Comprueba que tienes internet.');
    } on ApiError catch (e) {
      setState(() => _error = e.toString());
    } catch (e) {
      setState(() => _error = 'No se ha podido enlazar: $e');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.phone_android, size: 96, color: Colores.primario),
              const SizedBox(height: 16),
              const Text('FSMovil', textAlign: TextAlign.center, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              if (widget.motivo != null && _error == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(widget.motivo!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colores.naranja)),
                ),
              const Text(
                'Para empezar, pide en la oficina tu código QR y escanéalo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22),
              ),
              const Spacer(),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colores.rojo.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!, style: const TextStyle(fontSize: 19, color: Colores.rojo)),
                ),
              if (_trabajando)
                const Padding(padding: EdgeInsets.all(24), child: Cargando('Enlazando...'))
              else
                BotonGrande(texto: 'Escanear código', icono: Icons.qr_code_scanner, onPressed: _escanear, alto: 90),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
