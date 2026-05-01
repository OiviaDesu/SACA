import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saca_demo/core/theme/saca_theme.dart';
import 'package:saca_demo/presentation/widgets/saca_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SACA controls interaction feedback', () {
    testWidgets('primary button hover updates decoration and lift', (
      tester,
    ) async {
      await _pumpHarness(
        tester,
        child: const SacaPrimaryButton(
          key: ValueKey('primary'),
          label: 'Continue',
          onPressed: _noop,
        ),
      );

      final before = _surfaceDecoration(tester, 'primary');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer();
      await mouse
          .moveTo(tester.getCenter(find.byKey(const ValueKey('primary'))));
      await tester.pump(const Duration(milliseconds: 170));

      final after = _surfaceDecoration(tester, 'primary');
      expect(
        after.boxShadow!.first.blurRadius,
        greaterThan(before.boxShadow!.first.blurRadius),
      );
    });

    testWidgets('primary button press feedback appears and resets', (
      tester,
    ) async {
      await _pumpHarness(
        tester,
        child: const SacaPrimaryButton(
          key: ValueKey('primary'),
          label: 'Continue',
          onPressed: _noop,
        ),
      );

      final center = tester.getCenter(find.byKey(const ValueKey('primary')));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 100));

      final pressed = _surfaceDecoration(tester, 'primary');
      expect(_surfaceTranslationY(tester, 'primary'), equals(0));
      expect(pressed.boxShadow!.first.blurRadius, equals(10));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 170));

      final released = _surfaceDecoration(tester, 'primary');
      expect(released.boxShadow!.first.blurRadius, equals(16));
    });

    testWidgets('selected option keeps selected styling while hovered', (
      tester,
    ) async {
      await _pumpHarness(
        tester,
        child: const SacaOptionButton(
          key: ValueKey('option'),
          label: 'Body map',
          onPressed: _noop,
          selected: true,
        ),
      );

      final before = _surfaceDecoration(tester, 'option');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer();
      await mouse
          .moveTo(tester.getCenter(find.byKey(const ValueKey('option'))));
      await tester.pump(const Duration(milliseconds: 170));

      final after = _surfaceDecoration(tester, 'option');
      expect(before.gradient, isA<LinearGradient>());
      expect(after.gradient, isA<LinearGradient>());
      expect(
        after.boxShadow!.first.blurRadius,
        greaterThan(before.boxShadow!.first.blurRadius),
      );
      expect(after.border!.top.color, isNot(SacaTheme.border));
    });

    testWidgets('disabled primary button ignores hover and press styling', (
      tester,
    ) async {
      await _pumpHarness(
        tester,
        child: const SacaPrimaryButton(
          key: ValueKey('disabled'),
          label: 'Continue',
          onPressed: null,
        ),
      );

      final before = _surfaceDecoration(tester, 'disabled');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer();
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('disabled'))),
      );
      await tester.pump(const Duration(milliseconds: 170));

      final center = tester.getCenter(find.byKey(const ValueKey('disabled')));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 170));

      final after = _surfaceDecoration(tester, 'disabled');
      expect(after.border!.top.color, equals(before.border!.top.color));
      expect(after.boxShadow!.first.blurRadius,
          equals(before.boxShadow!.first.blurRadius));
      expect(_surfaceOpacity(tester, 'disabled').opacity, equals(0.44));
    });

    testWidgets('chip button shows focus indicator without layout shift', (
      tester,
    ) async {
      final focusNode = FocusNode(debugLabel: 'chip');
      addTearDown(focusNode.dispose);

      await _pumpHarness(
        tester,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SacaChipButton(
              key: const ValueKey('chip'),
              label: 'Fever',
              selected: false,
              onPressed: _noop,
              focusNode: focusNode,
            ),
          ],
        ),
      );

      final sizeBefore = tester.getSize(find.byKey(const ValueKey('chip')));
      focusNode.requestFocus();
      await tester.pump(const Duration(milliseconds: 170));

      final decoration = _surfaceDecoration(tester, 'chip');
      final sizeAfter = tester.getSize(find.byKey(const ValueKey('chip')));
      expect(decoration.boxShadow!.length, greaterThan(0));
      expect(
        decoration.boxShadow!.any((shadow) => shadow.spreadRadius == 2),
        isTrue,
      );
      expect(sizeAfter, equals(sizeBefore));
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
        child: Center(child: child),
      ),
    ),
  );
  await tester.pump();
}

BoxDecoration _surfaceDecoration(WidgetTester tester, String keyValue) {
  final container = tester.widget<AnimatedContainer>(
    find.byKey(ValueKey('$keyValue-surface')),
  );
  return container.decoration! as BoxDecoration;
}

double _surfaceTranslationY(WidgetTester tester, String keyValue) {
  final transform = tester.widget<Transform>(
    find.descendant(
      of: find.byKey(ValueKey('$keyValue-surface')),
      matching: find.byType(Transform),
    ),
  );
  return transform.transform.getTranslation().y;
}

AnimatedOpacity _surfaceOpacity(WidgetTester tester, String keyValue) {
  return tester.widget<AnimatedOpacity>(
    find.descendant(
      of: find.byKey(ValueKey('$keyValue-surface')),
      matching: find.byType(AnimatedOpacity),
    ),
  );
}

void _noop() {}
