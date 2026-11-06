import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nocturne/platform/pip/pip_controller.dart';

class MockPipPlatformBridge implements PipPlatformBridge {
  bool supported = true;
  bool enterPipResult = true;
  final StreamController<bool> _screenCtrl = StreamController<bool>.broadcast();

  int enterPipCallCount = 0;
  int? lastAspectNumerator;
  int? lastAspectDenominator;

  @override
  Future<bool> isPipSupported() async => supported;

  @override
  Future<bool> enterPipMode({
    int aspectRatioNumerator = 16,
    int aspectRatioDenominator = 9,
  }) async {
    enterPipCallCount++;
    lastAspectNumerator = aspectRatioNumerator;
    lastAspectDenominator = aspectRatioDenominator;
    return enterPipResult;
  }

  @override
  Stream<bool> get screenStateStream => _screenCtrl.stream;

  void emitScreenState(bool isScreenOn) {
    _screenCtrl.add(isScreenOn);
  }

  Future<void> dispose() async {
    await _screenCtrl.close();
  }
}

void main() {
  group('PipController Tests', () {
    late MockPipPlatformBridge mockBridge;
    late PipController controller;

    setUp(() {
      mockBridge = MockPipPlatformBridge();
      controller = PipController(platformBridge: mockBridge);
    });

    tearDown(() async {
      await controller.dispose();
      await mockBridge.dispose();
    });

    test('isPipSupported liefert korrekten Plattform-Status', () async {
      expect(await controller.isPipSupported(), isTrue);

      mockBridge.supported = false;
      expect(await controller.isPipSupported(), isFalse);
    });

    test(
        'enterPip ruft Plattform-Bridge mit 16:9 Format auf und aktualisiert Zustand',
        () async {
      expect(controller.isInPipMode, isFalse);

      final success = await controller.enterPip();

      expect(success, isTrue);
      expect(mockBridge.enterPipCallCount, 1);
      expect(mockBridge.lastAspectNumerator, 16);
      expect(mockBridge.lastAspectDenominator, 9);
      expect(controller.isInPipMode, isTrue);
    });

    test('onPipModeExited setzt PiP-Zustand zurueck', () async {
      await controller.enterPip();
      expect(controller.isInPipMode, isTrue);

      controller.onPipModeExited();
      expect(controller.isInPipMode, isFalse);
    });

    test('screenStateStream leitet Display-Ereignisse korrekt weiter',
        () async {
      final expectation = expectLater(
        controller.screenStateStream,
        emitsInOrder([true, false, true]),
      );

      mockBridge.emitScreenState(true);
      mockBridge.emitScreenState(false);
      mockBridge.emitScreenState(true);

      await expectation;
    });
  });
}
