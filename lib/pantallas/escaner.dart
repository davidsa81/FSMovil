import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Escáner de QR o código de barras. Devuelve el texto leído.
class PantallaEscaner extends StatefulWidget {
  final String titulo;
  final bool soloQr;

  const PantallaEscaner({super.key, this.titulo = 'Escanear código', this.soloQr = true});

  @override
  State<PantallaEscaner> createState() => _PantallaEscanerState();
}

class _PantallaEscanerState extends State<PantallaEscaner> {
  late final MobileScannerController _controlador;
  bool _leido = false;

  @override
  void initState() {
    super.initState();
    _controlador = MobileScannerController(
      formats: widget.soloQr
          ? const [BarcodeFormat.qrCode]
          : const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.upcA, BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_leido) return;
    for (final codigo in captura.barcodes) {
      final valor = codigo.rawValue;
      if (valor != null && valor.isNotEmpty) {
        _leido = true;
        Navigator.pop(context, valor);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          IconButton(
            iconSize: 32,
            icon: const Icon(Icons.flashlight_on),
            tooltip: 'Linterna',
            onPressed: () => _controlador.toggleTorch(),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controlador, onDetect: _alDetectar),
          Center(
            child: Container(
              width: 260,
              height: widget.soloQr ? 260 : 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Text(
              widget.soloQr ? 'Apunta al código QR' : 'Apunta al código de barras',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
