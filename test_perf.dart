import 'package:test/test.dart';
import 'dart:math';

void main() {
  test('f and df calc', () {
    final amounts = List.generate(5000, (i) => i.isEven ? -1000.0 : 100.0);
    final years = List.generate(5000, (i) => i / 12.0);
    final base = 1.15;

    final lnBase = log(base);
    final invBase = 1.0 / base;
    final negLnBase = -log(base);

    // warm up
    for (int i=0; i<100; i++) {
      double fSum = 0;
      double dfSum = 0;
      for (int j=0; j<amounts.length; j++) {
        final p = years[j];
        final termF = amounts[j] * exp(p * negLnBase);
        fSum += termF;
        dfSum -= termF * p;
      }
      dfSum *= invBase;
    }

    final s1 = Stopwatch()..start();
    for (int i=0; i<10000; i++) {
      double fSum = 0;
      double dfSum = 0;
      for (int j=0; j<amounts.length; j++) {
        final p = years[j];
        final termF = amounts[j] * exp(-p * lnBase);
        fSum += termF;
        dfSum += termF * (-p);
      }
      dfSum *= invBase;
    }
    s1.stop();
    print('original: ${s1.elapsedMilliseconds}ms');

    final s2 = Stopwatch()..start();
    for (int i=0; i<10000; i++) {
      double fSum = 0;
      double dfSum = 0;
      for (int j=0; j<amounts.length; j++) {
        final p = years[j];
        final termF = amounts[j] * exp(p * negLnBase);
        fSum += termF;
        dfSum -= termF * p;
      }
      dfSum *= invBase;
    }
    s2.stop();
    print('optimized: ${s2.elapsedMilliseconds}ms');
  });
}
