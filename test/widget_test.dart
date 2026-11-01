import 'package:flutter_test/flutter_test.dart';
import 'package:fsmovil/api/api.dart';

void main() {
  test('lee el QR de enlace', () {
    final qr = Api.leerQr('https://empresa.com/fs/appmovil/enlazar?c=0123456789abcdef0123456789abcdef');
    expect(qr, isNotNull);
    expect(qr!.base, 'https://empresa.com/fs');
    expect(qr.codigo, '0123456789abcdef0123456789abcdef');
  });

  test('rechaza QR ajenos', () {
    expect(Api.leerQr('https://otra-cosa.com/?c=123'), isNull);
    expect(Api.leerQr('hola'), isNull);
  });

  test('fecha con zona horaria', () {
    final f = fechaConZona(DateTime(2026, 11, 1, 9, 5, 7));
    expect(f.startsWith('2026-11-01T09:05:07'), isTrue);
    expect(RegExp(r'[+-]\d\d:\d\d$').hasMatch(f), isTrue);
  });
}
