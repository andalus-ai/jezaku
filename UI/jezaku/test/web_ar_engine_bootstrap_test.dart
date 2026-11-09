import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web shell exposes optional ar_engine Three.js model loaders', () {
    final index = File('web/index.html').readAsStringSync();
    final bootstrap =
        File('web/ar_engine_web_three_bootstrap.js').readAsStringSync();

    expect(
      index,
      contains(
        '<script type="module" src="ar_engine_web_three_bootstrap.js"></script>',
      ),
    );
    expect(bootstrap, contains("const threeVersion = '0.160.0';"));
    expect(bootstrap, contains('window.arEngineThreeBootstrap'));
    expect(bootstrap, contains('/build/three.module.js'));
    expect(bootstrap, contains('/examples/jsm/loaders/GLTFLoader.js'));
    expect(bootstrap, contains('/examples/jsm/loaders/OBJLoader.js'));
    expect(bootstrap, contains('window.THREE'));
    expect(bootstrap, contains('window.GLTFLoader'));
    expect(bootstrap, contains('window.OBJLoader'));
    expect(bootstrap, contains("status.state = 'failed';"));
  });
}
