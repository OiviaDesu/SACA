import 'package:flutter/cupertino.dart';

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 400;
            return DecoratedBox(
              decoration: _cardDecoration,
              child: compact
                  ? _buildCompactDiagram(
                      areas: areas,
                      visibleIds: visibleIds,
                    )
                  : _buildFullDiagram(
                      areas: areas,
                      visibleIds: visibleIds,
                    ),
            );
          },
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
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
      );

  Widget _buildFullDiagram({
    required List<BodyArea> areas,
    required Set<String> visibleIds,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: _ScaledBodyCanvas(
        areas: areas,
        visibleIds: visibleIds,
        selectedIds: widget.selectedIds,
        view: widget.view,
        pulseController: _pulseController,
        labelForArea: widget.labelForArea,
        semanticsPrefix: widget.semanticsPrefix,
        onToggle: widget.onToggle,
        showConnectors: true,
        showCanvasLabels: true,
      ),
    );
  }

  Widget _buildCompactDiagram({
    required List<BodyArea> areas,
    required Set<String> visibleIds,
  }) {
    final selectedVisibleAreas = areas
        .where((area) => widget.selectedIds.contains(area.id))
        .toList(growable: false);
    final selectedLabel = selectedVisibleAreas.isEmpty
        ? null
        : selectedVisibleAreas.map(widget.labelForArea).join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _ScaledBodyCanvas(
                    areas: areas,
                    visibleIds: visibleIds,
                    selectedIds: widget.selectedIds,
                    view: widget.view,
                    pulseController: _pulseController,
                    labelForArea: widget.labelForArea,
                    semanticsPrefix: widget.semanticsPrefix,
                    onToggle: widget.onToggle,
                    showConnectors: false,
                    showCanvasLabels: false,
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  top: 8,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: selectedLabel == null
                        ? const SizedBox.shrink()
                        : _SelectedBodyPill(
                            key: ValueKey<String>(selectedLabel),
                            label: selectedLabel,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _BodyLabelRail(
            areas: areas,
            selectedIds: widget.selectedIds,
            labelForArea: widget.labelForArea,
            semanticsPrefix: widget.semanticsPrefix,
            onToggle: widget.onToggle,
          ),
        ],
      ),
    );
  }
}

class _ScaledBodyCanvas extends StatelessWidget {
  const _ScaledBodyCanvas({
    required this.areas,
    required this.visibleIds,
    required this.selectedIds,
    required this.view,
    required this.pulseController,
    required this.labelForArea,
    required this.semanticsPrefix,
    required this.onToggle,
    required this.showConnectors,
    required this.showCanvasLabels,
  });

  final List<BodyArea> areas;
  final Set<String> visibleIds;
  final Set<String> selectedIds;
  final BodyView view;
  final AnimationController pulseController;
  final String Function(BodyArea area) labelForArea;
  final String semanticsPrefix;
  final ValueChanged<String> onToggle;
  final bool showConnectors;
  final bool showCanvasLabels;

  @override
  Widget build(BuildContext context) {
    const designSize = Size(820, 890);
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Image.asset(
                      view == BodyView.front
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
                    animation: pulseController,
                    builder: (context, _) {
                      return CustomPaint(
                        size: designSize,
                        painter: _BodyHighlightPainter(
                          selectedIds: selectedIds,
                          visibleIds: visibleIds,
                          pulse: pulseController.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (showConnectors)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: designSize,
                      painter: _BodyConnectorPainter(
                        areas: areas,
                        view: view,
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: _BodyTapLayer(
                  areas: areas,
                  size: designSize,
                  onToggle: onToggle,
                ),
              ),
              if (showCanvasLabels)
                for (final area in areas)
                  _PositionedAreaChip(
                    area: area,
                    label: labelForArea(area),
                    semanticsPrefix: semanticsPrefix,
                    selected: selectedIds.contains(area.id),
                    size: designSize,
                    onPressed: () => onToggle(area.id),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedBodyPill extends StatelessWidget {
  const _SelectedBodyPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: DecoratedBox(
        key: const ValueKey('bodySelectedFloatingPill'),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEF2).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE46E83)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            'Selected: $label',
            key: const ValueKey('bodySelectedFloatingText'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F1F1F),
            ),
          ),
        ),
      ),
    );
  }
}

class _BodyLabelRail extends StatelessWidget {
  const _BodyLabelRail({
    required this.areas,
    required this.selectedIds,
    required this.labelForArea,
    required this.semanticsPrefix,
    required this.onToggle,
  });

  final List<BodyArea> areas;
  final Set<String> selectedIds;
  final String Function(BodyArea area) labelForArea;
  final String semanticsPrefix;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('bodyLabelRail'),
      height: 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            for (final area in areas) ...[
              _BodyRailChip(
                area: area,
                label: labelForArea(area),
                semanticsPrefix: semanticsPrefix,
                selected: selectedIds.contains(area.id),
                onPressed: () => onToggle(area.id),
              ),
              if (area != areas.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _BodyRailChip extends StatelessWidget {
  const _BodyRailChip({
    required this.area,
    required this.label,
    required this.semanticsPrefix,
    required this.selected,
    required this.onPressed,
  });

  final BodyArea area;
  final String label;
  final String semanticsPrefix;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$semanticsPrefix ${label.replaceAll('\n', ' ')}',
      child: AnimatedScale(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        scale: selected ? 1.03 : 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 86, minHeight: 42),
          child: SacaChipButton(
            key: ValueKey<String>('bodyRailChip-${area.id}'),
            label: label,
            selected: selected,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _PositionedAreaChip extends StatelessWidget {
  const _PositionedAreaChip({
    required this.area,
    required this.label,
    required this.semanticsPrefix,
    required this.selected,
    required this.size,
    required this.onPressed,
  });

  final BodyArea area;
  final String label;
  final String semanticsPrefix;
  final bool selected;
  final Size size;
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

    return Positioned(
      left: left,
      top: y * size.height,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$semanticsPrefix ${label.replaceAll('\n', ' ')}',
        child: SizedBox(
          width: chipWidth,
          height: chipHeight,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            scale: selected ? 1.03 : 1,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              opacity: selected ? 1 : 0.94,
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
    required this.onToggle,
  });

  final List<BodyArea> areas;
  final Size size;
  final ValueChanged<String> onToggle;

  static const double tapRadius = 56;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('bodyTapLayer'),
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) {
        final id = _nearestAreaId(details.localPosition);
        if (id == null) return;
        onToggle(id);
      },
    );
  }

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

    return nearestDistance <= tapRadius ? nearestId : null;
  }
}

class _BodyHighlightPainter extends CustomPainter {
  const _BodyHighlightPainter({
    required this.selectedIds,
    required this.visibleIds,
    required this.pulse,
  });

  final Set<String> selectedIds;
  final Set<String> visibleIds;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedIds.isEmpty) return;

    for (final id in selectedIds) {
      // Only draw highlight points for body parts visible
      // in the current Front or Back view.
      if (!visibleIds.contains(id)) continue;

      final center = _BodyTargetPoints.positionFor(id, size);
      if (center == null) continue;

      final outerPaint = Paint()
        ..color = Color.lerp(
          const Color(0x22E85B5B),
          const Color(0x55E85B5B),
          pulse,
        )!
        ..style = PaintingStyle.fill;

      final middlePaint = Paint()
        ..color = const Color(0x77E85B5B)
        ..style = PaintingStyle.fill;

      final innerPaint = Paint()
        ..color = const Color(0xFFE85B5B)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, 22 + (pulse * 7), outerPaint);
      canvas.drawCircle(center, 14, middlePaint);
      canvas.drawCircle(center, 6, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BodyHighlightPainter oldDelegate) {
    return oldDelegate.selectedIds != selectedIds ||
        oldDelegate.visibleIds != visibleIds ||
        oldDelegate.pulse != pulse;
  }
}

class _BodyConnectorPainter extends CustomPainter {
  const _BodyConnectorPainter({
    required this.areas,
    required this.view,
  });

  final List<BodyArea> areas;
  final BodyView view;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5F7F91)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final area in areas) {
      final start = _labelAnchorFor(area.id, size);
      final end = _BodyTargetPoints.positionFor(area.id, size);

      if (start == null || end == null) continue;

      canvas.drawLine(start, end, paint);
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
    return oldDelegate.areas != areas || oldDelegate.view != view;
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
