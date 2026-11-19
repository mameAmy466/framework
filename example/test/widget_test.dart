import 'package:flutter_test/flutter_test.dart';
import 'package:tve_kit/tve_kit.dart';

import 'package:example/main.dart';

void main() {
  test('config de l\'app', () {
    expect(config.group, 'leraltv');
    expect(design.logoAsset, 'assets/images/logo.png');
    expect(TveSection.values, contains(TveSection.live));
  });
}
