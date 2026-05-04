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
  });
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required Widget child,
}) async {
  await tester.pumpWidget(
    CupertinoApp(
      theme: SacaTheme.cupertinoTheme,
      home: CupertinoPageScaffold(
        child: Center(
          child: SizedBox(width: 420, height: 520, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}
