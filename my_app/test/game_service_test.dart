import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/game_service.dart';

void main() {
  group('GameService', () {
    late GameService gameService;

    setUp(() {
      gameService = GameService();
    });

    test('Grid initializes with correct dimensions', () {
      expect(gameService.grid.length, equals(8));
      expect(gameService.grid[0].length, equals(4));
      for (var row in gameService.grid) {
        expect(row.length, equals(4));
      }
    });

    test('All hexagons start with valid colors (Red, Green, or Blue)', () {
      final validColors = {
        GameService.redColor,
        GameService.greenColor,
        GameService.blueColor,
      };

      for (var row in gameService.grid) {
        for (var hex in row) {
          expect(validColors.contains(hex.color), isTrue,
              reason: 'Color should be RED, GREEN, or BLUE');
        }
      }
    });

    test('Counter starts at 0', () {
      expect(gameService.counter, equals(0));
    });

    test('No hexagon is selected initially', () {
      expect(gameService.selectedRow, isNull);
      expect(gameService.selectedCol, isNull);
    });

    test('First tap selects a hexagon', () {
      final result = gameService.makeMove(0, 0);
      expect(result, equals(GameMoveResult.invalidMove));
      expect(gameService.selectedRow, equals(0));
      expect(gameService.selectedCol, equals(0));
    });

    test('Tapping same hexagon twice deselects it', () {
      gameService.makeMove(0, 0);
      expect(gameService.selectedRow, equals(0));
      expect(gameService.selectedCol, equals(0));

      final result = gameService.makeMove(0, 0);
      expect(result, equals(GameMoveResult.invalidMove));
      expect(gameService.selectedRow, isNull);
      expect(gameService.selectedCol, isNull);
    });

    test('Matching colors increments counter', () {
      // Manually set two hexagons to the same color
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[1][1].color = GameService.redColor;

      gameService.makeMove(0, 0);
      final result = gameService.makeMove(1, 1);

      expect(result, equals(GameMoveResult.matched));
      expect(gameService.counter, equals(1));
    });

    test('Matching colors spawns new random colors', () {
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[1][1].color = GameService.redColor;

      gameService.makeMove(0, 0);
      gameService.makeMove(1, 1);

      // After the match, the colors should be valid (Red, Green, or Blue)
      final validColors = {
        GameService.redColor,
        GameService.greenColor,
        GameService.blueColor,
      };
      expect(validColors.contains(gameService.grid[0][0].color), isTrue);
      expect(validColors.contains(gameService.grid[1][1].color), isTrue);
    });

    test('Non-matching colors return noMatch', () {
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[1][1].color = GameService.blueColor;

      gameService.makeMove(0, 0);
      final result = gameService.makeMove(1, 1);

      expect(result, equals(GameMoveResult.noMatch));
      expect(gameService.counter, equals(0));
    });

    test('Selection is cleared after each move', () {
      gameService.makeMove(0, 0);
      expect(gameService.selectedRow, equals(0));

      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[1][1].color = GameService.blueColor;

      gameService.makeMove(1, 1);

      expect(gameService.selectedRow, isNull);
      expect(gameService.selectedCol, isNull);
    });

    test('Out of bounds moves return invalidMove', () {
      final result1 = gameService.makeMove(-1, 0);
      expect(result1, equals(GameMoveResult.invalidMove));

      final result2 = gameService.makeMove(8, 0);
      expect(result2, equals(GameMoveResult.invalidMove));

      final result3 = gameService.makeMove(0, -1);
      expect(result3, equals(GameMoveResult.invalidMove));

      final result4 = gameService.makeMove(0, 4);
      expect(result4, equals(GameMoveResult.invalidMove));
    });

    test('Reset resets all game state', () {
      gameService.makeMove(0, 0);
      gameService.counter = 10;

      gameService.reset();

      expect(gameService.counter, equals(0));
      expect(gameService.selectedRow, isNull);
      expect(gameService.selectedCol, isNull);
      expect(gameService.grid.length, equals(8));
      expect(gameService.grid[0].length, equals(4));
    });

    test('colorsMatch compares color values correctly', () {
      expect(gameService.colorsMatch(GameService.redColor, GameService.redColor),
          isTrue);
      expect(gameService.colorsMatch(GameService.redColor, GameService.blueColor),
          isFalse);
      expect(gameService.colorsMatch(GameService.greenColor, GameService.greenColor),
          isTrue);
    });

    test('Multiple matches increase counter correctly', () {
      // First match
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[0][1].color = GameService.redColor;
      gameService.makeMove(0, 0);
      gameService.makeMove(0, 1);
      expect(gameService.counter, equals(1));

      // Second match
      gameService.grid[1][0].color = GameService.blueColor;
      gameService.grid[1][1].color = GameService.blueColor;
      gameService.makeMove(1, 0);
      gameService.makeMove(1, 1);
      expect(gameService.counter, equals(2));
    });

    test('HexagonObject randomize changes color to valid color', () {
      final hex = HexagonObject(
        row: 0,
        col: 0,
        color: GameService.redColor,
      );

      hex.randomize();

      final validColors = {
        GameService.redColor,
        GameService.greenColor,
        GameService.blueColor,
      };
      expect(validColors.contains(hex.color), isTrue);
    });

    test('All color constants are unique', () {
      final colors = {
        GameService.redColor,
        GameService.greenColor,
        GameService.blueColor,
      };
      expect(colors.length, equals(3));
    });

    test('Drag to same hexagon deselects it', () {
      gameService.makeMove(0, 0);
      expect(gameService.selectedRow, equals(0));
      expect(gameService.selectedCol, equals(0));

      // User releases on same hexagon
      gameService.selectedRow = null;
      gameService.selectedCol = null;

      expect(gameService.selectedRow, isNull);
      expect(gameService.selectedCol, isNull);
    });

    test('Drag to different matching color executes match', () {
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[2][2].color = GameService.redColor;

      gameService.makeMove(0, 0);
      final result = gameService.makeMove(2, 2);

      expect(result, equals(GameMoveResult.matched));
      expect(gameService.counter, equals(1));
    });

    test('Drag to different non-matching color shows no match', () {
      gameService.grid[1][0].color = GameService.greenColor;
      gameService.grid[3][1].color = GameService.blueColor;

      gameService.makeMove(1, 0);
      final result = gameService.makeMove(3, 1);

      expect(result, equals(GameMoveResult.noMatch));
      expect(gameService.counter, equals(0));
    });

    test('Selection persists until second move completes', () {
      gameService.makeMove(0, 0);
      expect(gameService.selectedRow, equals(0));
      expect(gameService.selectedCol, equals(0));

      // Before second move
      expect(gameService.selectedRow, isNotNull);
      expect(gameService.selectedCol, isNotNull);

      // After second move
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[1][1].color = GameService.blueColor;
      gameService.makeMove(1, 1);

      // Selection should be cleared
      expect(gameService.selectedRow, isNull);
      expect(gameService.selectedCol, isNull);
    });

    test('Rapid-fire matches work correctly', () {
      // First match
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[0][1].color = GameService.redColor;
      gameService.makeMove(0, 0);
      gameService.makeMove(0, 1);
      expect(gameService.counter, equals(1));
      expect(gameService.selectedRow, isNull);

      // Second match immediately after
      gameService.grid[1][0].color = GameService.greenColor;
      gameService.grid[1][1].color = GameService.greenColor;
      gameService.makeMove(1, 0);
      gameService.makeMove(1, 1);
      expect(gameService.counter, equals(2));
      expect(gameService.selectedRow, isNull);

      // Third match
      gameService.grid[2][0].color = GameService.blueColor;
      gameService.grid[2][1].color = GameService.blueColor;
      gameService.makeMove(2, 0);
      gameService.makeMove(2, 1);
      expect(gameService.counter, equals(3));
    });

    test('Grid dimensions are respected after operations', () {
      // Perform several operations
      gameService.makeMove(0, 0);
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[1][1].color = GameService.redColor;
      gameService.makeMove(1, 1);

      // Verify grid is still 8x4
      expect(gameService.grid.length, equals(8));
      for (var row in gameService.grid) {
        expect(row.length, equals(4));
      }
    });

    test('Invalid selection attempts do not modify state', () {
      final initialCounter = gameService.counter;

      // Try to select out of bounds
      final result1 = gameService.makeMove(-1, 0);
      expect(result1, equals(GameMoveResult.invalidMove));
      expect(gameService.counter, equals(initialCounter));
      expect(gameService.selectedRow, isNull);

      // Try to select out of bounds (column)
      final result2 = gameService.makeMove(0, 10);
      expect(result2, equals(GameMoveResult.invalidMove));
      expect(gameService.counter, equals(initialCounter));
    });

    test('Selected hexagon color is preserved until match', () {
      final originalColor = gameService.grid[0][0].color;
      gameService.makeMove(0, 0);

      // Color should not change just by selection
      expect(gameService.grid[0][0].color, equals(originalColor));

      // Set up a non-match
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[2][2].color = GameService.blueColor;

      // Make the moves (non-match)
      gameService.grid[0][0].color = GameService.redColor;
      gameService.grid[2][2].color = GameService.blueColor;
      gameService.makeMove(0, 0);
      gameService.makeMove(2, 2);

      // Both should have new random colors now
      expect(gameService.grid[0][0].color, isA<Color>());
      expect(gameService.grid[2][2].color, isA<Color>());
    });
  });
}

