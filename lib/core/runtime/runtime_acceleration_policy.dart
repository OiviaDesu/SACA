enum RuntimeFeature { renderer, stt, ml }

enum AccelerationBackend {
  cpu,
  coreml,
  nnapi,
  directml,
  metal,
  impeller,
  skia,
  platformDefault,
  unknown,
}

class RuntimeAccelerationDecision {
  const RuntimeAccelerationDecision({
    required this.feature,
    required this.activeBackend,
    this.fallbackBackend,
    this.fallbackReason,
  });

  final RuntimeFeature feature;
  final AccelerationBackend activeBackend;
  final AccelerationBackend? fallbackBackend;
  final String? fallbackReason;

  bool get usedFallback => fallbackBackend != null && fallbackReason != null;

  String toLogFields() {
    final fields = <String>[
      'feature=${feature.name}',
      'backend=${activeBackend.name}',
    ];
    if (fallbackBackend != null) {
      fields.add('fallback=${fallbackBackend!.name}');
    }
    if (fallbackReason != null && fallbackReason!.isNotEmpty) {
      fields.add('fallbackReason="$fallbackReason"');
    }
    return fields.join(' ');
  }
}

class RuntimeAccelerationPolicy {
  RuntimeAccelerationPolicy({this.gpuPreferred = true});

  final bool gpuPreferred;
  final Set<String> _unhealthyBackends = <String>{};

  RuntimeAccelerationDecision choose({
    required RuntimeFeature feature,
    required AccelerationBackend cpuBackend,
    AccelerationBackend? gpuBackend,
    bool gpuAvailable = false,
    bool gpuProbePassed = false,
    String? unavailableReason,
  }) {
    if (!gpuPreferred) {
      return RuntimeAccelerationDecision(
        feature: feature,
        activeBackend: cpuBackend,
        fallbackReason: 'gpu disabled by policy',
      );
    }

    if (gpuBackend == null || !gpuAvailable) {
      return RuntimeAccelerationDecision(
        feature: feature,
        activeBackend: cpuBackend,
        fallbackReason: unavailableReason ?? 'gpu backend not exposed',
      );
    }

    if (_isUnhealthy(feature, gpuBackend)) {
      return RuntimeAccelerationDecision(
        feature: feature,
        activeBackend: cpuBackend,
        fallbackBackend: gpuBackend,
        fallbackReason: 'gpu backend marked unhealthy this session',
      );
    }

    if (gpuProbePassed) {
      return RuntimeAccelerationDecision(
        feature: feature,
        activeBackend: gpuBackend,
      );
    }

    markUnhealthy(feature, gpuBackend);
    return RuntimeAccelerationDecision(
      feature: feature,
      activeBackend: cpuBackend,
      fallbackBackend: gpuBackend,
      fallbackReason: 'gpu probe failed',
    );
  }

  void markUnhealthy(RuntimeFeature feature, AccelerationBackend backend) {
    _unhealthyBackends.add(_key(feature, backend));
  }

  bool isUnhealthy(RuntimeFeature feature, AccelerationBackend backend) {
    return _isUnhealthy(feature, backend);
  }

  bool _isUnhealthy(RuntimeFeature feature, AccelerationBackend backend) {
    return _unhealthyBackends.contains(_key(feature, backend));
  }

  String _key(RuntimeFeature feature, AccelerationBackend backend) {
    return '${feature.name}:${backend.name}';
  }
}
