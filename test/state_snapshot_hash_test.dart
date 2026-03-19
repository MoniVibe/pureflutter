import 'package:bullethole_shared/bullethole_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('StateSnapshotHash is stable across key order', () {
    const hasher = BughuntStateHasher();
    final a = hasher.hashSnapshot(<String, Object?>{
      'turn': 'w',
      'fen': 'abc',
      'nested': <String, Object?>{'x': 1, 'y': true},
    });
    final b = hasher.hashSnapshot(<String, Object?>{
      'nested': <String, Object?>{'y': true, 'x': 1},
      'fen': 'abc',
      'turn': 'w',
    });

    expect(a.value, b.value);
    expect(a.algorithm, 'sha256');
  });
}
