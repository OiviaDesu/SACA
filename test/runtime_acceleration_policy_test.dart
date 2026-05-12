import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/core/runtime/runtime_acceleration_policy.dart';

void main() {
  group('RuntimeAccelerationPolicy', () {
    test('chooses GPU backend when available and probe passes', () {
      final policy = RuntimeAccelerationPolicy();

      final decision = policy.choose(
        feature: RuntimeFeature.ml,
        cpuBackend: AccelerationBackend.cpu,
        gpuBackend: AccelerationBackend.directml,
        gpuAvailable: true,
        gpuProbePassed: true,
      );

      expect(decision.activeBackend, AccelerationBackend.directml);
      expect(decision.usedFallback, isFalse);
      expect(decision.toLogFields(), 'feature=ml backend=directml');
    });

    test('falls back to CPU and marks GPU unhealthy when probe fails', () {
      final policy = RuntimeAccelerationPolicy();

      final firstDecision = policy.choose(
        feature: RuntimeFeature.stt,
        cpuBackend: AccelerationBackend.cpu,
        gpuBackend: AccelerationBackend.nnapi,
        gpuAvailable: true,
        gpuProbePassed: false,
      );
      final secondDecision = policy.choose(
        feature: RuntimeFeature.stt,
        cpuBackend: AccelerationBackend.cpu,
        gpuBackend: AccelerationBackend.nnapi,
        gpuAvailable: true,
        gpuProbePassed: true,
      );

      expect(firstDecision.activeBackend, AccelerationBackend.cpu);
      expect(firstDecision.fallbackBackend, AccelerationBackend.nnapi);
      expect(firstDecision.fallbackReason, 'gpu probe failed');
      expect(policy.isUnhealthy(RuntimeFeature.stt, AccelerationBackend.nnapi),
          isTrue);
      expect(secondDecision.activeBackend, AccelerationBackend.cpu);
      expect(secondDecision.fallbackReason,
          'gpu backend marked unhealthy this session');
    });

    test('uses CPU when GPU backend is unavailable', () {
      final policy = RuntimeAccelerationPolicy();

      final decision = policy.choose(
        feature: RuntimeFeature.ml,
        cpuBackend: AccelerationBackend.cpu,
        unavailableReason: 'diagnosis classifier has no GPU provider',
      );

      expect(decision.activeBackend, AccelerationBackend.cpu);
      expect(decision.fallbackBackend, isNull);
      expect(decision.fallbackReason, 'diagnosis classifier has no GPU provider');
      expect(
        decision.toLogFields(),
        'feature=ml backend=cpu fallbackReason="diagnosis classifier has no GPU provider"',
      );
    });
  });
}
