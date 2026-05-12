import 'package:flutter/cupertino.dart';

import '../../core/layout/saca_window_size_class.dart';
import '../../domain/models/saca_models.dart';
import 'saca_controls.dart';

class BodyDiagram extends StatefulWidget {
  const BodyDiagram({
    super.key,
    required this.view,
    required this.selectedIds,
    required this.onToggle,
    required this.labelForArea,
    required this.semanticsPrefix,
  });

  final BodyView view;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;
  final String Function(BodyArea area) labelForArea;
  final String semanticsPrefix;

  @override
  State<BodyDiagram> createState() => _BodyDiagramState();
}

class _BodyDiagramState extends State<BodyDiagram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  String? _pressedId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final areas = SacaFlowState.bodyAreas
        .where((area) => area.view == widget.view)
        .toList(growable: false);

    final visibleIds = areas.map((area) => area.id).toSet();

    return KeyedSubtree(
      key: ValueKey<String>('bodyDiagram-${widget.view.name}'),
      child: AspectRatio(
        aspectRatio: 0.92,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFEFBFA),
                Color(0xFFF4FBFD),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD9E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const designSize = Size(820, 890);
                final scale = _scaleFor(constraints.biggest, designSize);
                final tokens = _BodyDiagramTokens.resolve(
                  constraints.biggest,
                  scale,
                );

                return ClipRect(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: designSize.width,
                      height: designSize.height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Image.asset(
                                  widget.view == BodyView.front
                                      ? 'assets/Images/Body-front.png'
                                      : 'assets/Images/Body-back.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                key: const ValueKey('bodyIndicatorPulse'),
                                animation: _pulseController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    size: designSize,
                                    painter: _BodyHighlightPainter(
                                      selectedIds: widget.selectedIds,
                                      visibleIds: visibleIds,
                                      pressedId: _pressedId,
                                      tokens: tokens,
                                      pulse: _pulseController.value,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                size: designSize,
                                painter: _BodyConnectorPainter(
                                  areas: areas,
                                  view: widget.view,
                                  tokens: tokens,
                                  selectedIds: widget.selectedIds,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: _BodyTapLayer(
                              areas: areas,
                              size: designSize,
                              selectedIds: widget.selectedIds,
                              semanticsPrefix: widget.semanticsPrefix,
                              labelForArea: widget.labelForArea,
                              tokens: tokens,
                              onToggle: _handleAreaToggle,
                            ),
                          ),
                          for (final area in areas)
                            _PositionedAreaChip(
                              area: area,
                              label: widget.labelForArea(area),
                              semanticsPrefix: widget.semanticsPrefix,
                              selected: widget.selectedIds.contains(area.id),
                              size: designSize,
                              tokens: tokens,
                              onPressed: () => widget.onToggle(area.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _scaleFor(Size available, Size designSize) {
    if (available.width <= 0 || available.height <= 0) return 1;
    return (available.width / designSize.width)
        .clamp(0.1, available.height / designSize.height)
        .toDouble();
  }

  void _handleAreaToggle(String id) {
    setState(() => _pressedId = id);
    widget.onToggle(id);
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (!mounted || _pressedId != id) return;
      setState(() => _pressedId = null);
    });
  }
}

enum _BodyDiagramDensity { compact, comfortable, roomy }

class _BodyDiagramTokens {
  const _BodyDiagramTokens({
    required this.density,
    required this.labelScale,
    required this.connectorStroke,
    required this.selectedConnectorStroke,
    required this.hitRadius,
    required this.outerMarkerRadius,
    required this.middleMarkerRadius,
    required this.innerMarkerRadius,
    required this.markerPulseRadius,
  });

  final _BodyDiagramDensity density;
  final double labelScale;
  final double connectorStroke;
  final double selectedConnectorStroke;
  final double hitRadius;
  final double outerMarkerRadius;
  final double middleMarkerRadius;
  final double innerMarkerRadius;
  final double markerPulseRadius;

  static _BodyDiagramTokens resolve(Size available, double canvasScale) {
    final shortestSide = available.shortestSide;
    final windowClass = SacaWindowSizeClasses.fromWidth(available.width);
    final roomy = windowClass.isExpandedOrLarger && available.height >= 680;
    final compact = shortestSide <= 520 || available.height <= 560;
    final density = roomy
        ? _BodyDiagramDensity.roomy
        : compact
            ? _BodyDiagramDensity.compact
            : _BodyDiagramDensity.comfortable;
    final maxLabelScale = switch (density) {
      _BodyDiagramDensity.compact => 2.35,
      _BodyDiagramDensity.comfortable => 1.55,
      _BodyDiagramDensity.roomy => 1.35,
    };
    final minLabelScale = switch (density) {
      _BodyDiagramDensity.compact => 1.18,
      _BodyDiagramDensity.comfortable => 1.12,
      _BodyDiagramDensity.roomy => 1.08,
    };
    final labelScale =
        (1 / canvasScale).clamp(minLabelScale, maxLabelScale).toDouble();
    return switch (density) {
      _BodyDiagramDensity.compact => _BodyDiagramTokens(
          density: density,
          labelScale: labelScale,
          connectorStroke: 1.35,
          selectedConnectorStroke: 2.5,
          hitRadius: 72,
          outerMarkerRadius: 26,
          middleMarkerRadius: 15,
          innerMarkerRadius: 7,
          markerPulseRadius: 8,
        ),
      _BodyDiagramDensity.comfortable => _BodyDiagramTokens(
          density: density,
          labelScale: labelScale,
          connectorStroke: 1.65,
          selectedConnectorStroke: 2.35,
          hitRadius: 62,
          outerMarkerRadius: 27,
          middleMarkerRadius: 15.5,
          innerMarkerRadius: 7.5,
          markerPulseRadius: 8.5,
        ),
      _BodyDiagramDensity.roomy => _BodyDiagramTokens(
          density: density,
          labelScale: labelScale,
          connectorStroke: 1.9,
          selectedConnectorStroke: 2.6,
          hitRadius: 58,
          outerMarkerRadius: 29,
          middleMarkerRadius: 16.5,
          innerMarkerRadius: 8,
          markerPulseRadius: 9,
        ),
    };
  }
}

class _PositionedAreaChip extends StatelessWidget {
  const _PositionedAreaChip({
    required this.area,
    required this.label,
    required this.semanticsPrefix,
    required this.selected,
    required this.size,
    required this.tokens,
    required this.onPressed,
  });

  final BodyArea area;
  final String label;
  final String semanticsPrefix;
  final bool selected;
  final Size size;
  final _BodyDiagramTokens tokens;
  final VoidCallback onPressed;

  static const double chipWidth = 150;
  static const double chipHeight = 60;
  @override
  Widget build(BuildContext context) {
    final y = _BodyDiagramLayout.verticalPositionFor(area.id);
    final sidePadding = size.width * _BodyDiagramLayout.sidePaddingRatio;

    final left = _BodyDiagramLayout.isRightColumn(area.id)
        ? size.width - sidePadding - chipWidth
        : sidePadding;

    final readableScale = tokens.labelScale;

    return Positioned(
      left: left,
      top: y * size.height,
      child: ExcludeSemantics(
        child: SizedBox(
          width: chipWidth,
          height: chipHeight,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            scale: readableScale * (selected ? 1.06 : 1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              opacity: 1,
              child: SacaChipButton(
                label: label,
                selected: selected,
                onPressed: onPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BodyTapLayer extends StatelessWidget {
  const _BodyTapLayer({
    required this.areas,
    required this.size,
    required this.selectedIds,
    required this.semanticsPrefix,
    required this.labelForArea,
    required this.tokens,
    required this.onToggle,
  });

  final List<BodyArea> areas;
  final Size size;
  final Set<String> selectedIds;
  final String semanticsPrefix;
  final String Function(BodyArea area) labelForArea;
  final _BodyDiagramTokens tokens;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey('bodyTapLayer'),
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                final id = _nearestAreaId(details.localPosition);
                if (id == null) return;
                onToggle(id);
              },
            ),
          ),
        ),
        for (final area in areas)
          if (_BodyTargetPoints.positionFor(area.id, size) case final target?)
            Positioned(
              left: target.dx - _activeRadius,
              top: target.dy - _activeRadius,
              width: _activeRadius * 2,
              height: _activeRadius * 2,
              child: Semantics(
                container: true,
                button: true,
                selected: selectedIds.contains(area.id),
                label:
                    '$semanticsPrefix ${labelForArea(area).replaceAll('\n', ' ')}',
                onTap: () => onToggle(area.id),
                child: const SizedBox.expand(),
              ),
            ),
      ],
    );
  }

  double get _activeRadius => tokens.hitRadius;

  String? _nearestAreaId(Offset tapPosition) {
    String? nearestId;
    var nearestDistance = double.infinity;

    for (final area in areas) {
      final target = _BodyTargetPoints.positionFor(area.id, size);
      if (target == null) continue;
      final distance = (tapPosition - target).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = area.id;
      }
    }

    return nearestDistance <= _activeRadius ? nearestId : null;
  }
}

class _BodyHighlightPainter extends CustomPainter {
  const _BodyHighlightPainter({
    required this.selectedIds,
    required this.visibleIds,
    required this.pressedId,
    required this.tokens,
    required this.pulse,
  });

  final Set<String> selectedIds;
  final Set<String> visibleIds;
  final String? pressedId;
  final _BodyDiagramTokens tokens;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedIds.isEmpty && pressedId == null) return;

    for (final id in {...selectedIds, if (pressedId != null) pressedId!}) {
      // Only draw highlight points for body parts visible
      // in the current Front or Back view.
      if (!visibleIds.contains(id)) continue;

      final center = _BodyTargetPoints.positionFor(id, size);
      if (center == null) continue;

      final isPressed = id == pressedId;
      final outerPaint = Paint()
        ..color = Color.lerp(
          isPressed ? const Color(0x2287C6D4) : const Color(0x22E85B5B),
          isPressed ? const Color(0x6687C6D4) : const Color(0x66E85B5B),
          pulse,
        )!
        ..style = PaintingStyle.fill;

      final middlePaint = Paint()
        ..color = isPressed ? const Color(0x8887C6D4) : const Color(0x88E85B5B)
        ..style = PaintingStyle.fill;

      final innerPaint = Paint()
        ..color = isPressed ? const Color(0xFF2C8EA2) : const Color(0xFFE85B5B)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        center,
        tokens.outerMarkerRadius + (pulse * tokens.markerPulseRadius),
        outerPaint,
      );
      canvas.drawCircle(
        center,
        isPressed ? tokens.middleMarkerRadius + 3 : tokens.middleMarkerRadius,
        middlePaint,
      );
      canvas.drawCircle(
        center,
        isPressed ? tokens.innerMarkerRadius + 1 : tokens.innerMarkerRadius,
        innerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyHighlightPainter oldDelegate) {
    return oldDelegate.selectedIds != selectedIds ||
        oldDelegate.visibleIds != visibleIds ||
        oldDelegate.pressedId != pressedId ||
        oldDelegate.tokens != tokens ||
        oldDelegate.pulse != pulse;
  }
}

class _BodyConnectorPainter extends CustomPainter {
  const _BodyConnectorPainter({
    required this.areas,
    required this.view,
    required this.tokens,
    required this.selectedIds,
  });

  final List<BodyArea> areas;
  final BodyView view;
  final _BodyDiagramTokens tokens;
  final Set<String> selectedIds;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xAA5F7F91)
      ..strokeWidth = tokens.connectorStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final selectedPaint = Paint()
      ..color = const Color(0xFFE85B5B)
      ..strokeWidth = tokens.selectedConnectorStroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final area in areas) {
      final selected = selectedIds.contains(area.id);
      final start = _labelAnchorFor(area.id, size);
      final end = _BodyTargetPoints.positionFor(area.id, size);

      if (start == null || end == null) continue;

      canvas.drawLine(start, end, selected ? selectedPaint : paint);
    }
  }

  Offset? _labelAnchorFor(String id, Size size) {
    final y = _BodyDiagramLayout.verticalPositionFor(id);
    final sidePadding = size.width * _BodyDiagramLayout.sidePaddingRatio;
    final isRight = _BodyDiagramLayout.isRightColumn(id);

    final chipLeft = isRight
        ? size.width - sidePadding - _PositionedAreaChip.chipWidth
        : sidePadding;

    final chipTop = y * size.height;

    // Left column lines start from right edge of chip.
    // Right column lines start from left edge of chip.
    final x = isRight ? chipLeft : chipLeft + _PositionedAreaChip.chipWidth;

    final centerY = chipTop + _PositionedAreaChip.chipHeight / 2;

    return Offset(x, centerY);
  }

  @override
  bool shouldRepaint(covariant _BodyConnectorPainter oldDelegate) {
    return oldDelegate.areas != areas ||
        oldDelegate.view != view ||
        oldDelegate.tokens != tokens ||
        oldDelegate.selectedIds != selectedIds;
  }
}

class _BodyTargetPoints {
  static Offset? positionFor(String id, Size size) {
    final point = switch (id) {
      // Front view target points
      'head' => const Offset(0.50, 0.06),
      'eyes' => const Offset(0.54, 0.10),
      'throat' => const Offset(0.50, 0.17),
      'chest' => const Offset(0.48, 0.29),
      'heart' => const Offset(0.54, 0.29),
      'stomach' => const Offset(0.50, 0.43),
      'hand' => const Offset(0.66, 0.52),
      'leg' => const Offset(0.45, 0.60),
      'knees' => const Offset(0.54, 0.68),
      'toes' => const Offset(0.52, 0.94),

      // Back view target points
      'neck' => const Offset(0.50, 0.16),
      'ears' => const Offset(0.55, 0.10),
      'back' => const Offset(0.50, 0.28),
      'shoulder' => const Offset(0.61, 0.20),
      'elbow' => const Offset(0.37, 0.35),
      'lower_back' => const Offset(0.50, 0.42),
      'arm' => const Offset(0.63, 0.31),
      'finger' => const Offset(0.65, 0.53),
      'lower_leg' => const Offset(0.47, 0.78),
      'ankle' => const Offset(0.53, 0.91),
      _ => null,
    };

    if (point == null) return null;

    return Offset(point.dx * size.width, point.dy * size.height);
  }
}

class _BodyDiagramLayout {
  static const double sidePaddingRatio = 0.08;

  static bool isRightColumn(String id) {
    return switch (id) {
      // Front view - right column
      'eyes' || 'heart' || 'hand' || 'knees' || 'toes' => true,

      // Back view - right column
      'ears' || 'shoulder' || 'arm' || 'finger' || 'ankle' => true,
      _ => false,
    };
  }

  static double verticalPositionFor(String id) {
    return switch (id) {
      // Front view - left column
      'head' => 0.06,
      'throat' => 0.21,
      'chest' => 0.36,
      'stomach' => 0.51,
      'leg' => 0.73,

      // Front view - right column
      'eyes' => 0.06,
      'heart' => 0.21,
      'hand' => 0.51,
      'knees' => 0.73,
      'toes' => 0.86,

      // Back view - left column
      'neck' => 0.06,
      'back' => 0.21,
      'lower_back' => 0.51,
      'lower_leg' => 0.73,
      'elbow' => 0.36,

      // Back view - right column
      'ears' => 0.06,
      'shoulder' => 0.21,
      'arm' => 0.36,
      'finger' => 0.51,
      'ankle' => 0.86,
      _ => 0.06,
    };
  }
}
