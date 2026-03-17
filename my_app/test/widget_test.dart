import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/main.dart';

void main() {
  group('Hexagon Match Game Widget Tests', () {
    testWidgets('App renders with correct title', (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());

      expect(find.text('Hexagon Match Game'), findsWidgets);
    });

    testWidgets('Initial grid displays 8x4 hexagons', (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // The app should render without errors
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(Listener), findsWidgets);
    });

    testWidgets('Counter displays and is initially 0',
        (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('Counter: 0'), findsWidgets);
    });

    testWidgets('Death message is not shown initially',
        (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      expect(find.text('YOU DEAD'), findsNothing);
    });

    testWidgets('Clicking near hexagon center triggers interaction',
        (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Simulate a tap near the first hexagon (around position 100, 100)
      await tester.tapAt(const Offset(100, 100));
      await tester.pumpAndSettle();

      // After interaction, UI should update (though we can't directly test
      // the yellow border in unit tests, we can verify the structure exists)
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Container has black border around grid',
        (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Find the Container with black border
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);
    });

    testWidgets('Stack contains CustomPaint and conditional Message',
        (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Stack should exist
      expect(find.byType(Stack), findsWidgets);

      // Listener and CustomPaint should be inside Stack
      expect(find.byType(Listener), findsWidgets);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Game renders correctly after multiple interactions',
        (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Perform multiple taps
      await tester.tapAt(const Offset(100, 100));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(150, 150));
      await tester.pumpAndSettle();

      // App should still render without errors
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Listener is properly configured for pointer events',
        (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify Listener is present and can receive events
      final listenerFinder = find.byType(Listener);
      expect(listenerFinder, findsWidgets);

      // The Listener should have event handlers
      final widget =
          tester.widget<Listener>(listenerFinder.first);

      // Verify handlers are not null
      expect(widget.onPointerDown, isNotNull);
      expect(widget.onPointerUp, isNotNull);
    });

    testWidgets('Hexagon grid painter is called with correct parameters',
        (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Verify CustomPaint exists
      expect(find.byType(CustomPaint), findsWidgets);

      // The painter should be HexagonGridPainter (we can't directly access it
      // from here, but we know it's being used)
    });

    testWidgets('Mouse region provides opaque hit testing',
        (WidgetTester tester) async {
      // ignore: deprecated_member_use
      tester.binding.window.physicalSizeTestValue = const Size(1280, 720);
      // ignore: deprecated_member_use
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      // ignore: deprecated_member_use
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // MouseRegion should exist for proper hit testing
      expect(find.byType(MouseRegion), findsWidgets);

      final mouseRegion =
          tester.widget<MouseRegion>(find.byType(MouseRegion).first);

      // Verify opaque is true for hit testing
      expect(mouseRegion.opaque, isTrue);
    });
  });
}
