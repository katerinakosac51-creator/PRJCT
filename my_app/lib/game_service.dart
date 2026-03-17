import 'dart:math';
import 'package:flutter/material.dart';

class HexagonObject {
  int row;
  int col;
  Color color;

  HexagonObject({
    required this.row,
    required this.col,
    required this.color,
  });

  void randomize() {
    color = GameService.colors[Random().nextInt(GameService.colors.length)];
  }
}

enum GameMoveResult { matched, noMatch, invalidMove }

class GameService {
  static const List<int> colsPerRow = [4, 5, 4, 5, 4, 5, 4, 5];
  static const int rows = 8;

  late List<List<HexagonObject>> grid;
  int counter = 0;
  int? selectedRow;
  int? selectedCol;

  static const Color redColor = Color.fromARGB(255, 255, 0, 0);
  static const Color greenColor = Color.fromARGB(255, 0, 255, 0);
  static const Color blueColor = Color.fromARGB(255, 0, 0, 255);
  static const List<Color> colors = [redColor, greenColor, blueColor];

  GameService() {
    initializeGrid();
  }

  void initializeGrid() {
    grid = List.generate(rows, (r) {
      return List.generate(colsPerRow[r], (c) {
        return HexagonObject(
          row: r,
          col: c,
          color: colors[Random().nextInt(colors.length)],
        );
      });
    });
    counter = 0;
    selectedRow = null;
    selectedCol = null;
  }

  GameMoveResult makeMove(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= grid[row].length) {
      return GameMoveResult.invalidMove;
    }

    if (selectedRow == null) {
      selectedRow = row;
      selectedCol = col;
      return GameMoveResult.invalidMove;
    }

    if (selectedRow == row && selectedCol == col) {
      selectedRow = null;
      selectedCol = null;
      return GameMoveResult.invalidMove;
    }

    final sourceRow = selectedRow!;
    final sourceCol = selectedCol!;
    final sourceColor = grid[sourceRow][sourceCol].color;
    final targetColor = grid[row][col].color;

    selectedRow = null;
    selectedCol = null;

    if (colorsMatch(sourceColor, targetColor)) {
      final component = _collectComponent(sourceRow, sourceCol, sourceColor);
      final containsTarget = component.any((p) => p.x == row && p.y == col);
      if (containsTarget && component.length >= 3) {
        for (final p in component) {
          grid[p.x][p.y].randomize();
        }
        counter++;
        return GameMoveResult.matched;
      }
      return GameMoveResult.noMatch;
    } else {
      return GameMoveResult.noMatch;
    }
  }

  List<Point<int>> applyDrag(List<Point<int>> path) {
    selectedRow = null;
    selectedCol = null;

    if (path.length < 3) {
      return [];
    }

    final first = path.first;
    final targetColor = grid[first.x][first.y].color;
    for (final p in path) {
      if (!colorsMatch(grid[p.x][p.y].color, targetColor)) {
        return [];
      }
    }

    counter++;
    return List<Point<int>>.from(path);
  }

  void randomizeCells(List<Point<int>> cells) {
    for (final p in cells) {
      grid[p.x][p.y].randomize();
    }
  }

  bool colorsMatch(Color c1, Color c2) {
    return c1.r == c2.r && c1.g == c2.g && c1.b == c2.b && c1.a == c2.a;
  }

  void reset() {
    initializeGrid();
  }

  void randomizeAll() {
    for (final row in grid) {
      for (final hex in row) {
        hex.randomize();
      }
    }
  }

  List<Point<int>> _collectComponent(int row, int col, Color color) {
    final visited = List.generate(rows, (r) => List.filled(grid[r].length, false));
    final queue = <Point<int>>[Point(row, col)];
    final component = <Point<int>>[];
    visited[row][col] = true;

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      component.add(current);
      for (final n in _neighbors(current.x, current.y)) {
        if (!visited[n.x][n.y] && colorsMatch(grid[n.x][n.y].color, color)) {
          visited[n.x][n.y] = true;
          queue.add(n);
        }
      }
    }
    return component;
  }

  List<Point<int>> _neighbors(int row, int col) {
    final maxCols = colsPerRow.reduce(max);
    final isShifted = grid[row].length < maxCols;
    final offsets = isShifted
        ? const [
            Point(-1, 0),
            Point(-1, 1),
            Point(0, -1),
            Point(0, 1),
            Point(1, 0),
            Point(1, 1),
          ]
        : const [
            Point(-1, -1),
            Point(-1, 0),
            Point(0, -1),
            Point(0, 1),
            Point(1, -1),
            Point(1, 0),
          ];

    final result = <Point<int>>[];
    for (final o in offsets) {
      final nr = row + o.x;
      final nc = col + o.y;
      if (nr >= 0 && nr < rows && nc >= 0 && nc < grid[nr].length) {
        result.add(Point(nr, nc));
      }
    }
    return result;
  }
}
