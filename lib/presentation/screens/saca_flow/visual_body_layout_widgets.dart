part of '../saca_flow_screen.dart';

class _ResponsiveVisualBodySelectionLayout extends StatefulWidget {
  const _ResponsiveVisualBodySelectionLayout({
    required this.diagramBuilder,
    required this.sidePanel,
  });

  final Widget Function({required double maxWidth, required double maxHeight})
      diagramBuilder;
  final Widget sidePanel;

  @override
  State<_ResponsiveVisualBodySelectionLayout> createState() =>
      _ResponsiveVisualBodySelectionLayoutState();
}

class _ResponsiveVisualBodySelectionLayoutState
    extends State<_ResponsiveVisualBodySelectionLayout> {
  static const double _wideGap = 28;
  static const double _narrowGap = 12;
  static const double _sidePanelWidth = 320;
  static const double _diagramComfortMaxWidth = 840;
  static const double _diagramRoomyMaxWidth = 920;
  static const double _diagramAspectRatio = 0.92;
  static const double _minimumUsableDiagramHeight = 300;

  double? _remainingViewportHeight;
  double _sidePanelHeight = 0;

  @override
  Widget build(BuildContext context) {
    return _RemainingViewportHeight(
      onChanged: _setRemainingViewportHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final windowClass =
              SacaWindowSizeClasses.fromWidth(constraints.maxWidth);
          final isWide = windowClass.isExpandedOrLarger &&
              (_remainingViewportHeight ?? double.infinity) >= 620;
          return isWide
              ? _wideLayout(constraints.maxWidth)
              : _narrowLayout(constraints.maxWidth);
        },
      ),
    );
  }

  Widget _wideLayout(double availableWidth) {
    final sidePanelWidth = _adaptiveSidePanelWidth(availableWidth);
    final diagramMaxWidth = _adaptiveDiagramMaxWidth(availableWidth);
    final diagramColumnWidth = (availableWidth - _wideGap - sidePanelWidth)
        .clamp(0.0, diagramMaxWidth);
    final widthLimitedHeight = diagramColumnWidth / _diagramAspectRatio;
    final diagramHeight = _boundedDiagramHeight(
      widthLimitedHeight: widthLimitedHeight,
      availableHeight: _remainingViewportHeight,
    );

    return Row(
      key: const ValueKey('visualBodyWideLayout'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: widget.diagramBuilder(
            maxWidth: diagramColumnWidth,
            maxHeight: diagramHeight,
          ),
        ),
        const SizedBox(width: _wideGap),
        SizedBox(
          width: sidePanelWidth,
          child: _MeasureSize(
            onChanged: _setSidePanelHeight,
            child: widget.sidePanel,
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout(double availableWidth) {
    final diagramMaxWidth = _adaptiveDiagramMaxWidth(availableWidth);
    final widthLimitedHeight =
        availableWidth.clamp(0.0, diagramMaxWidth) / _diagramAspectRatio;
    final remaining = _remainingViewportHeight;
    final heightForDiagram = remaining == null || _sidePanelHeight == 0
        ? widthLimitedHeight
        : remaining - _sidePanelHeight - _narrowGap;
    final diagramHeight = _boundedDiagramHeight(
      widthLimitedHeight: widthLimitedHeight,
      availableHeight: heightForDiagram > 0 ? heightForDiagram : null,
    );

    return Column(
      key: const ValueKey('visualBodyNarrowLayout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.diagramBuilder(
          maxWidth: availableWidth.clamp(0.0, diagramMaxWidth).toDouble(),
          maxHeight: diagramHeight,
        ),
        const SizedBox(height: _narrowGap),
        _MeasureSize(
          onChanged: _setSidePanelHeight,
          child: widget.sidePanel,
        ),
      ],
    );
  }

  double _boundedDiagramHeight({
    required double widthLimitedHeight,
    required double? availableHeight,
  }) {
    final preferredHeight = widthLimitedHeight > 0
        ? widthLimitedHeight
        : _minimumUsableDiagramHeight;
    if (availableHeight == null ||
        !availableHeight.isFinite ||
        availableHeight <= 0) {
      return preferredHeight;
    }
    final upperBound = availableHeight < _minimumUsableDiagramHeight
        ? _minimumUsableDiagramHeight
        : availableHeight;
    return preferredHeight
        .clamp(_minimumUsableDiagramHeight, upperBound)
        .toDouble();
  }

  double _adaptiveDiagramMaxWidth(double availableWidth) {
    final height = _remainingViewportHeight ?? 0;
    final windowClass = SacaWindowSizeClasses.fromWidth(availableWidth);
    if (windowClass.isExtraLarge && height >= 920) {
      return _diagramRoomyMaxWidth;
    }
    if (windowClass.isLargeOrLarger && height >= 720) {
      return _diagramComfortMaxWidth;
    }
    return 760;
  }

  double _adaptiveSidePanelWidth(double availableWidth) {
    final windowClass = SacaWindowSizeClasses.fromWidth(availableWidth);
    if (windowClass.isLargeOrLarger) return 340;
    if (windowClass == SacaWindowSizeClass.expanded) return 300;
    return _sidePanelWidth;
  }

  void _setRemainingViewportHeight(double value) {
    if ((_remainingViewportHeight ?? -1) == value) return;
    setState(() => _remainingViewportHeight = value);
  }

  void _setSidePanelHeight(Size value) {
    if (_sidePanelHeight == value.height) return;
    setState(() => _sidePanelHeight = value.height);
  }
}

class _RemainingViewportHeight extends StatefulWidget {
  const _RemainingViewportHeight({
    required this.child,
    required this.onChanged,
  });

  final Widget child;
  final ValueChanged<double> onChanged;

  @override
  State<_RemainingViewportHeight> createState() =>
      _RemainingViewportHeightState();
}

class _RemainingViewportHeightState extends State<_RemainingViewportHeight> {
  static const double _roundingGuard = 96;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _RemainingViewportHeight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return widget.child;
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final mediaQuery = MediaQuery.of(context);
      final remainingHeight = mediaQuery.size.height -
          mediaQuery.viewInsets.bottom -
          top -
          _roundingGuard;
      if (remainingHeight.isFinite && remainingHeight > 0) {
        widget.onChanged(remainingHeight);
      }
    });
  }
}

class _MeasureSize extends StatefulWidget {
  const _MeasureSize({
    required this.child,
    required this.onChanged,
  });

  final Widget child;
  final ValueChanged<Size> onChanged;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _MeasureSize oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleMeasure();
    return widget.child;
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        widget.onChanged(renderObject.size);
      }
    });
  }
}
