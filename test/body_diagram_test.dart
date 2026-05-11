import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/core/theme/saca_theme.dart';
import 'package:saca_demo/domain/models/saca_models.dart';
import 'package:saca_demo/presentation/widgets/body_diagram.dart';
import 'package:saca_demo/presentation/widgets/saca_controls.dart';

void main() {
  group('BodyDiagram', () {
    testWidgets('black box: front view renders front labels and toggles chip',
        (tester) async {
      final toggled = <String>[];

      await _pumpHarness(
        tester,
        child: BodyDiagram(
          view: BodyView.front,
          selectedIds: const <String>{'chest'},
          semanticsPrefix: 'Body area',
          labelForArea: (area) => area.label,
          onToggle: toggled.add,
        ),
      );

      expect(find.byKey(const ValueKey('bodyDiagram-front')), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Back'), findsNothing);

      await tester.tap(find.text('Chest'));
      await tester.pump(const Duration(milliseconds: 180));

      expect(toggled, <String>['chest']);
    });

    testWidgets('black box: tapping body target toggles nearest chip',
        (tester) async {
      final toggled = <String>[];

      await _pumpHarness(
        tester,
        child: BodyDiagram(
          view: BodyView.front,
          selectedIds: const <String>{},
          semanticsPrefix: 'Body area',
          labelForArea: (area) => area.label,
          onToggle: toggled.add,
        ),
      );

      await _tapDesignPoint(tester, const Offset(0.48, 0.29));
      await tester.pump(const Duration(milliseconds: 180));

      expect(toggled, <String>['chest']);
    });

    testWidgets('black box: tapping empty body space does not toggle',
        (tester) async {
      final toggled = <String>[];

      await _pumpHarness(
        tester,
        child: BodyDiagram(
          view: BodyView.front,
          selectedIds: const <String>{},
          semanticsPrefix: 'Body area',
          labelForArea: (area) => area.label,
          onToggle: toggled.add,
        ),
      );

      await _tapDesignPoint(tester, const Offset(0.50, 0.80));
      await tester.pump(const Duration(milliseconds: 180));

      expect(toggled, isEmpty);
    });

    testWidgets('black box: back view renders back labels only',
        (tester) async {
      await _pumpHarness(
        tester,
        child: BodyDiagram(
          view: BodyView.back,
          selectedIds: const <String>{'back'},
          semanticsPrefix: 'Body area',
          labelForArea: (area) => area.label,
          onToggle: (_) {},
        ),
      );

      expect(find.byKey(const ValueKey('bodyDiagram-back')), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Chest'), findsNothing);
    });

    testWidgets('white box: selected chip builds reusable chip control',
        (tester) async {
      await _pumpHarness(
        tester,
        child: BodyDiagram(
          view: BodyView.front,
          selectedIds: const <String>{'chest'},
          semanticsPrefix: 'Body area',
          labelForArea: (area) => area.label,
          onToggle: (_) {},
        ),
      );

      final selectedChip = find.ancestor(
        of: find.text('Chest'),
        matching: find.byType(SacaChipButton),
      );

      expect(selectedChip, findsOneWidget);
      expect(find.byType(AnimatedContainer), findsWidgets);
    });
    testWidgets('white box: selected chips animate scale and opacity',
        (tester) async {
      await _pumpHarness(
        tester,
        child: BodyDiagram(
          view: BodyView.front,
          selectedIds: const <String>{'chest'},
          semanticsPrefix: 'Body area',
          labelForArea: (area) => area.label,
          onToggle: (_) {},
        ),
      );

      final selectedChip = find.ancestor(
        of: find.text('Chest'),
        matching: find.byType(SacaChipButton),
      );

      final scale = tester.widget<AnimatedScale>(
        find.ancestor(of: selectedChip, matching: find.byType(AnimatedScale)),
      );
      final opacity = tester.widget<AnimatedOpacity>(
        find.ancestor(of: selectedChip, matching: find.byType(AnimatedOpacity)),
      );

      expect(scale.scale, greaterThan(1));
      expect(opacity.opacity, 1);
      expect(scale.curve, Curves.easeOutCubic);
    });

    testWidgets('mobile mode keeps labels readable in horizontal rail',
        (tester) async {
      await _pumpHarness(
        tester,
        size: const Size(360, 520),
        child: BodyDiagram(
          view: BodyView.front,
          selectedIds: const <String>{'stomach'},
          semanticsPrefix: 'Body area',
          labelForArea: (area) => area.label,
          onToggle: (_) {},
        ),
      );

      expect(find.byKey(const ValueKey('bodyLabelRail')), findsOneWidget);
      expect(find.byKey(const ValueKey('bodySelectedFloatingPill')),
          findsOneWidget);
      expect(find.text('Stomach'), findsOneWidget);
      expect(find.text('Selected: Stomach'), findsOneWidget);

      final label = tester.widget<Text>(find.text('Stomach'));
      expect(label.style?.fontSize, greaterThanOrEqualTo(14));
    });

    testWidgets('mobile rail chip toggles body area', (tester) async {
      final toggled = <String>[];

      await _pumpHarness(
        tester,
        size: const Size(360, 520),
        child: BodyDiagram(
          view: BodyView.front,
          selectedIds: const <String>{},
          semanticsPrefix: 'Body area',
          labelForArea: (area) => area.label,
          onToggle: toggled.add,
        ),
      );

      await tester
          .ensureVisible(find.byKey(const ValueKey('bodyRailChip-chest')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bodyRailChip-chest')));
      await tester.pump(const Duration(milliseconds: 180));

      expect(toggled, <String>['chest']);
    });

    testWidgets('white box: selected indicators use pulse animation',
        (tester) async {
      await _pumpHarness(
        tester,
        child: BodyDiagram(
          view: BodyView.front,
          selectedIds: const <String>{'chest'},
          semanticsPrefix: 'Body area',
          labelForArea: (area) => area.label,
          onToggle: (_) {},
        ),
      );

      expect(find.byKey(const ValueKey('bodyIndicatorPulse')), findsOneWidget);
    });
  });
}

Future<void> _tapDesignPoint(
    WidgetTester tester, Offset normalizedPoint) async {
  const designSize = Size(820, 890);
  final tapLayer = tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('bodyTapLayer')),
  );
  final point = Offset(
    normalizedPoint.dx * designSize.width,
    normalizedPoint.dy * designSize.height,
  );
  await tester.tapAt(tapLayer.localToGlobal(point));
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required Widget child,
  Size size = const Size(420, 520),
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      theme: SacaTheme.cupertinoTheme,
      home: CupertinoPageScaffold(
        child: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}
