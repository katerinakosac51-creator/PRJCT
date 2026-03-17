import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'game_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HexSlop',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'HexSlop'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late GameService gameService;
  String? deathMessage;
  final List<String> eventLog = [];
  final ScrollController _logScrollController = ScrollController();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _catPlayer = AudioPlayer();
  Timer? _failFxTimer;
  bool _showFailCat = false;

  static const double hexSize = 30;
  static const double sqrt3 = 1.7320508;
  static const double boardPadding = 20;
  static const double hexGap = 4;
  static const Size boardSize = Size(400, 600);

  // Drag state
  int? dragStartRow;
  int? dragStartCol;
  Offset? currentDragPosition;
  final List<Point<int>> dragPath = [];

  // Hover state
  int? hoverRow;
  int? hoverCol;
  Offset? hoverPosition;
  late final AnimationController _hoverWiggleController;
  final ValueNotifier<double> _hoverWiggleValue = ValueNotifier<double>(0);
  late final AnimationController _fxController;
  final ValueNotifier<double> _fxTimeMs = ValueNotifier<double>(0);
  final Map<Point<int>, double> _snapStartMs = {};
  final Map<Point<int>, double> _appearStartMs = {};
  static const double _snapDurationMs = 260;
  static const double _appearDurationMs = 520;
  static const double _appearDelayMs = 180;

  @override
  void initState() {
    super.initState();
    gameService = GameService();
    _hoverWiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addListener(() {
        _hoverWiggleValue.value = _hoverWiggleController.value;
      });
    _fxController = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tickFx);
    _fxController.repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/cat.gif'), context);
    });
    _addLog('Game initialized');
  }

  @override
  void dispose() {
    _failFxTimer?.cancel();
    _sfxPlayer.dispose();
    _catPlayer.dispose();
    _logScrollController.dispose();
    _hoverWiggleController.dispose();
    _fxController.dispose();
    _hoverWiggleValue.dispose();
    _fxTimeMs.dispose();
    super.dispose();
  }

  void _tickFx() {
    final elapsed = _fxController.lastElapsedDuration;
    if (elapsed == null) {
      return;
    }
    final nowMs = elapsed.inMilliseconds.toDouble();
    bool changed = false;
    final snapKeys = _snapStartMs.keys.toList();
    for (final key in snapKeys) {
      final start = _snapStartMs[key]!;
      if (nowMs - start > _snapDurationMs) {
        _snapStartMs.remove(key);
        changed = true;
      }
    }
    final appearKeys = _appearStartMs.keys.toList();
    for (final key in appearKeys) {
      final start = _appearStartMs[key]!;
      if (nowMs - start > _appearDurationMs) {
        _appearStartMs.remove(key);
        changed = true;
      }
    }
    if (_fxTimeMs.value != nowMs || changed) {
      _fxTimeMs.value = nowMs;
    }
  }

  void _startSnap(List<Point<int>> cells) {
    for (final p in cells) {
      _snapStartMs[p] = _fxTimeMs.value;
    }
  }

  void _startAppear(List<Point<int>> cells) {
    for (final p in cells) {
      _appearStartMs[p] = _fxTimeMs.value;
    }
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().millisecondsSinceEpoch % 100000;
      eventLog.add('[$timestamp] $message');
      if (eventLog.length > 100) {
        eventLog.removeAt(0);
      }
    });
    // Scroll to bottom after frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        try {
          _logScrollController.jumpTo(
            _logScrollController.position.maxScrollExtent,
          );
        } catch (e) {
          // Silently ignore scroll errors
        }
      }
    });
  }

  void _resetGame() {
    setState(() {
      gameService = GameService();
      deathMessage = null;
      _showFailCat = false;
      dragStartRow = null;
      dragStartCol = null;
      currentDragPosition = null;
    });
    _catPlayer.stop();
    _addLog('Game reset - all states released');
  }

  double get hexHeight => hexSize * 2;
  double get hexWidth => hexSize * sqrt3;
  double get hexStepX => hexWidth + hexGap;
  double get hexStepY => hexHeight * 0.75 + hexGap;

  int get _maxCols {
    int maxCols = 0;
    for (final row in gameService.grid) {
      if (row.length > maxCols) {
        maxCols = row.length;
      }
    }
    return maxCols;
  }

  double _rowOffset(int row) {
    return (_maxCols - gameService.grid[row].length) * hexStepX * 0.5;
  }

  Offset _getHexagonCenter(int row, int col) {
    final x = boardPadding + _rowOffset(row) + col * hexStepX;
    final y = boardPadding + row * hexStepY;
    return Offset(x, y);
  }

  Rect _computeFieldRect() {
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (int r = 0; r < gameService.grid.length; r++) {
      for (int c = 0; c < gameService.grid[r].length; c++) {
        final center = _getHexagonCenter(r, c);
        minX = min(minX, center.dx - hexSize);
        maxX = max(maxX, center.dx + hexSize);
        minY = min(minY, center.dy - hexSize);
        maxY = max(maxY, center.dy + hexSize);
      }
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset _boardTranslation() {
    final fieldRect = _computeFieldRect();
    final sizeCenter = Offset(boardSize.width / 2, boardSize.height / 2);
    return sizeCenter - fieldRect.center;
  }

  /// Returns the row and column of hexagon at position, or (-1, -1) if none found
  List<int> _getHexagonAt(Offset position) {
    for (int r = 0; r < gameService.grid.length; r++) {
      for (int c = 0; c < gameService.grid[r].length; c++) {
        Offset center = _getHexagonCenter(r, c);
        double distance = (position - center).distance;

        // Increased radius to make clicks and hover detection easier
        if (distance <= hexSize + 2) {
          return [r, c];
        }
      }
    }
    return [-1, -1];
  }

  void _onPointerDown(PointerDownEvent event) {
    final localPosition = event.localPosition;
    final boardPosition = localPosition - _boardTranslation();
    final coords = _getHexagonAt(boardPosition);
    final row = coords[0];
    final col = coords[1];

    if (row >= 0 && col >= 0) {
      setState(() {
        dragStartRow = row;
        dragStartCol = col;
        currentDragPosition = boardPosition;
        dragPath
          ..clear()
          ..add(Point(row, col));
        gameService.selectedRow = row;
        gameService.selectedCol = col;
      });
      _setHover(row, col, boardPosition);
      _addLog('Click at (${localPosition.dx.toStringAsFixed(0)}, ${localPosition.dy.toStringAsFixed(0)}) - Grid [$row, $col]');
    } else {
      _setHover(null, null, null);
      _addLog('Click at (${localPosition.dx.toStringAsFixed(0)}, ${localPosition.dy.toStringAsFixed(0)}) - No hexagon');
    }
  }

  void _setHover(int? row, int? col, Offset? position) {
    setState(() {
      hoverRow = row;
      hoverCol = col;
      hoverPosition = position;
    });
    if (hoverRow != null && hoverCol != null) {
      if (!_hoverWiggleController.isAnimating) {
        _hoverWiggleController.repeat();
      }
    } else {
      if (_hoverWiggleController.isAnimating) {
        _hoverWiggleController.stop();
        _hoverWiggleValue.value = 0;
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final localPosition = event.localPosition;
    final boardPosition = localPosition - _boardTranslation();
    final coords = _getHexagonAt(boardPosition);
    final row = coords[0];
    final col = coords[1];

    setState(() {
      currentDragPosition = boardPosition;
      if (row >= 0 && col >= 0) {
        if (dragStartRow != null && dragStartCol != null) {
          if (dragPath.isEmpty) {
            dragPath.add(Point(row, col));
          } else if (dragPath.last.x != row || dragPath.last.y != col) {
            final previousIndex = dragPath.lastIndexWhere(
              (p) => p.x == row && p.y == col,
            );
            if (previousIndex >= 0) {
              dragPath.removeRange(previousIndex + 1, dragPath.length);
            } else {
              dragPath.add(Point(row, col));
            }
          }
        }
      }
    });

    if (row >= 0 && col >= 0) {
      _setHover(row, col, boardPosition);
    } else {
      _setHover(null, null, null);
    }

    // Only log drag movements if we're actively dragging (not just hovering)
    if (dragStartRow != null && dragStartCol != null) {
      _addLog('Pointer move - Dragging from [$dragStartRow, $dragStartCol]');
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (dragStartRow == null || dragStartCol == null) {
      setState(() {
        dragStartRow = null;
        dragStartCol = null;
        currentDragPosition = null;
        hoverRow = null;
        hoverCol = null;
        hoverPosition = null;
      });
      _setHover(null, null, null);
      _addLog('Pointer up - No drag in progress');
      return;
    }

    final localPosition = event.localPosition;
    final boardPosition = localPosition - _boardTranslation();
    final coords = _getHexagonAt(boardPosition);
    final row = coords[0];
    final col = coords[1];

    setState(() {
      if (row >= 0 && col >= 0) {
        if (dragPath.isEmpty ||
            dragPath.last.x != row ||
            dragPath.last.y != col) {
          dragPath.add(Point(row, col));
        }
      }

      if (dragPath.length < 2) {
        // Released outside grid, deselect
        gameService.selectedRow = null;
        gameService.selectedCol = null;
        _addLog('Released outside grid - Deselected');
      } else {
        final matchedCells = gameService.applyDrag(dragPath);
        final fromHex = '[$dragStartRow, $dragStartCol]';
        final toHex = dragPath.isNotEmpty
            ? '[${dragPath.last.x}, ${dragPath.last.y}]'
            : '[-1, -1]';

        if (matchedCells.isNotEmpty) {
          _addLog('Matched! $fromHex -> $toHex - Counter: ${gameService.counter}');
          _triggerSuccessSfx();
          deathMessage = null;
          _startSnap(matchedCells);
          Future.delayed(Duration(milliseconds: (_snapDurationMs + _appearDelayMs).toInt()), () {
            if (!mounted) {
              return;
            }
            setState(() {
              gameService.randomizeCells(matchedCells);
              _startAppear(matchedCells);
            });
          });
        } else {
          _addLog('No match! $fromHex -> $toHex - YOU DEAD');
          deathMessage = 'YOU DEAD';
          _failFxTimer?.cancel();
          _showFailCat = true;
          _catPlayer.stop();
          _catPlayer.play(AssetSource('cat.mp3'));
          _failFxTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _showFailCat = false;
              });
            }
            _catPlayer.stop();
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                deathMessage = null;
                _showFailCat = false;
              });
            }
          });
        }
      }

      dragStartRow = null;
      dragStartCol = null;
      currentDragPosition = null;
      dragPath.clear();
    });
    if (row >= 0 && col >= 0) {
      _setHover(row, col, boardPosition);
    } else {
      _setHover(null, null, null);
    }
  }

  Future<void> _triggerSuccessSfx() async {
    _failFxTimer?.cancel();
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('faaah.mp3'));
    } catch (e) {
      _addLog('Sound error: $e');
    }
  }

  void _onPointerHover(PointerHoverEvent event) {
    final localPosition = event.localPosition;
    final boardPosition = localPosition - _boardTranslation();
    final coords = _getHexagonAt(boardPosition);
    final row = coords[0];
    final col = coords[1];
    if (row >= 0 && col >= 0) {
      _setHover(row, col, boardPosition);
    } else {
      _setHover(null, null, null);
    }
  }

  void _onPointerExit(PointerExitEvent event) {
    _setHover(null, null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        actions: kReleaseMode
            ? const []
            : [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: _resetGame,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Refresh'),
                    ),
                  ),
                ),
              ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.1, -0.2),
            radius: 1.2,
            colors: [
              Color(0xFF3A3A3A),
              Color(0xFF2B2B2B),
              Color(0xFF1E1E1E),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: kReleaseMode
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: -52,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: Stack(
                                children: [
                                  Text(
                                    'You win: ${gameService.counter}',
                                    style: GoogleFonts.luckiestGuy(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      foreground: Paint()
                                        ..style = PaintingStyle.stroke
                                        ..strokeWidth = 4
                                        ..color = Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'You win: ${gameService.counter}',
                                    style: GoogleFonts.luckiestGuy(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Listener(
                        onPointerDown: _onPointerDown,
                        onPointerMove: _onPointerMove,
                        onPointerUp: _onPointerUp,
                        child: MouseRegion(
                          opaque: true,
                          onHover: _onPointerHover,
                          onExit: _onPointerExit,
                          child: CustomPaint(
                            size: boardSize,
                            painter: HexagonGridPainter(
                              repaint: Listenable.merge([
                                _hoverWiggleController,
                                _fxController,
                                _hoverWiggleValue,
                                _fxTimeMs,
                              ]),
                              grid: gameService.grid,
                              selectedRow: gameService.selectedRow,
                              selectedCol: gameService.selectedCol,
                              hexSize: hexSize,
                                boardPadding: boardPadding,
                                hexGap: hexGap,
                                dragStartRow: dragStartRow,
                                dragStartCol: dragStartCol,
                                currentDragPosition: currentDragPosition,
                              hoverRow: hoverRow,
                              hoverCol: hoverCol,
                              dragPath: dragPath,
                              hoverWiggleValue: _hoverWiggleValue,
                              hoverPosition: hoverPosition,
                              fxTimeMs: _fxTimeMs,
                              snapStartMs: _snapStartMs,
                              appearStartMs: _appearStartMs,
                            ),
                          ),
                        ),
                        ),
                        if (deathMessage != null)
                          Positioned(
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                deathMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (_showFailCat)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: AnimatedBuilder(
                              animation: _fxController,
                              child: Image.asset(
                                'assets/cat.gif',
                                width: 240,
                                height: 240,
                                filterQuality: FilterQuality.high,
                              ),
                              builder: (context, child) {
                                final t = _fxController.value * 2 * pi * 6;
                                final dx = sin(t) * 6;
                                final dy = cos(t * 1.3) * 4;
                                final rot = sin(t) * 0.03;
                                return Transform.translate(
                                  offset: Offset(dx, dy),
                                  child: Transform.rotate(
                                    angle: rot,
                                    child: Transform.scale(
                                      scale: 2.0,
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  // Game area
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.topCenter,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: -52,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: Center(
                                    child: Stack(
                                      children: [
                                        Text(
                                          'You win: ${gameService.counter}',
                                          style: GoogleFonts.luckiestGuy(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                            foreground: Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = 4
                                              ..color = Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'You win: ${gameService.counter}',
                                          style: GoogleFonts.luckiestGuy(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Listener(
                                onPointerDown: _onPointerDown,
                                onPointerMove: _onPointerMove,
                                onPointerUp: _onPointerUp,
                                child: MouseRegion(
                                  opaque: true,
                                  onHover: _onPointerHover,
                                  onExit: _onPointerExit,
                                  child: CustomPaint(
                                    size: boardSize,
                                    painter: HexagonGridPainter(
                                      repaint: Listenable.merge([
                                        _hoverWiggleController,
                                        _fxController,
                                        _hoverWiggleValue,
                                        _fxTimeMs,
                                      ]),
                                      grid: gameService.grid,
                                      selectedRow: gameService.selectedRow,
                                      selectedCol: gameService.selectedCol,
                                      hexSize: hexSize,
                                      boardPadding: boardPadding,
                                      hexGap: hexGap,
                                      dragStartRow: dragStartRow,
                                      dragStartCol: dragStartCol,
                                      currentDragPosition: currentDragPosition,
                                      hoverRow: hoverRow,
                                      hoverCol: hoverCol,
                                      dragPath: dragPath,
                                      hoverWiggleValue: _hoverWiggleValue,
                                      hoverPosition: hoverPosition,
                                      fxTimeMs: _fxTimeMs,
                                      snapStartMs: _snapStartMs,
                                      appearStartMs: _appearStartMs,
                                    ),
                                  ),
                                ),
                              ),
                              if (deathMessage != null)
                                Positioned(
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      deathMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_showFailCat)
                                Positioned(
                                  top: 0,
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: AnimatedBuilder(
                                    animation: _fxController,
                                    child: Image.asset(
                                      'assets/cat.gif',
                                      width: 240,
                                      height: 240,
                                      filterQuality: FilterQuality.high,
                                    ),
                                    builder: (context, child) {
                                      final t = _fxController.value * 2 * pi * 6;
                                      final dx = sin(t) * 6;
                                      final dy = cos(t * 1.3) * 4;
                                      final rot = sin(t) * 0.03;
                                      return Transform.translate(
                                        offset: Offset(dx, dy),
                                        child: Transform.rotate(
                                          angle: rot,
                                          child: Transform.scale(
                                            scale: 2.0,
                                            child: child,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Debug log panel
                  Container(
                    width: 300,
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.grey[400]!, width: 1)),
                      color: Colors.grey[900],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[850],
                            border: Border(bottom: BorderSide(color: Colors.grey[700]!, width: 1)),
                          ),
                          child: const Text(
                            'Event Log',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _logScrollController,
                            itemCount: eventLog.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Text(
                                  eventLog[index],
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class HexagonGridPainter extends CustomPainter {
  final Listenable repaint;
  final List<List<HexagonObject>> grid;
  final int? selectedRow;
  final int? selectedCol;
  final double hexSize;
  final int? dragStartRow;
  final int? dragStartCol;
  final Offset? currentDragPosition;
  final int? hoverRow;
  final int? hoverCol;
  final double boardPadding;
  final List<Point<int>> dragPath;
  final double hexGap;
  final ValueNotifier<double> hoverWiggleValue;
  final Offset? hoverPosition;
  final ValueNotifier<double> fxTimeMs;
  final Map<Point<int>, double> snapStartMs;
  final Map<Point<int>, double> appearStartMs;

  HexagonGridPainter({
    required this.repaint,
    required this.grid,
    required this.selectedRow,
    required this.selectedCol,
    required this.hexSize,
    required this.boardPadding,
    required this.hexGap,
    this.dragStartRow,
    this.dragStartCol,
    this.currentDragPosition,
    this.hoverRow,
    this.hoverCol,
    required this.dragPath,
    required this.hoverWiggleValue,
    this.hoverPosition,
    required this.fxTimeMs,
    required this.snapStartMs,
    required this.appearStartMs,
  }) : super(repaint: repaint);

  static const double sqrt3 = 1.7320508;
  static const double borderInset = 12;

  int get _maxCols {
    int maxCols = 0;
    for (final row in grid) {
      if (row.length > maxCols) {
        maxCols = row.length;
      }
    }
    return maxCols;
  }

  double _rowOffset(int row) {
    return (_maxCols - grid[row].length) * hexStepX * 0.5;
  }

  double get hexHeight => hexSize * 2;
  double get hexWidth => hexSize * sqrt3;
  double get hexStepX => hexWidth + hexGap;
  double get hexStepY => hexHeight * 0.75 + hexGap;

  @override
  void paint(Canvas canvas, Size size) {
    final fieldRect = _computeFieldRect();
    final fieldCenter = fieldRect.center;
    final sizeCenter = Offset(size.width / 2, size.height / 2);
    final translation = sizeCenter - fieldCenter;
    canvas.save();
    canvas.translate(translation.dx, translation.dy);

    final shadowRect = Rect.fromLTRB(
      fieldRect.left + 6,
      fieldRect.bottom - 4,
      fieldRect.right + 12,
      fieldRect.bottom + 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(14)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Draw hexagons
    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        _drawHexagon(canvas, r, c, size);
      }
    }

    // Pointer glare is handled per-hex in the foil shader.

    if (dragStartRow != null && dragStartCol != null && hoverRow != null && hoverCol != null) {
      final hoverCenter = _getHexagonCenter(hoverRow!, hoverCol!);
      final hoverPath = _createHexagonPath(hoverCenter);
      canvas.drawPath(
        hoverPath,
        Paint()
          ..color = Colors.orange.withValues(alpha: 0.2)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        hoverPath,
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // Draw drag line if dragging
    if (dragStartRow != null && dragStartCol != null && dragPath.length >= 2) {
      final path = Path();
      final first = _getHexagonCenter(dragPath.first.x, dragPath.first.y);
      path.moveTo(first.dx, first.dy);
      for (int i = 1; i < dragPath.length; i++) {
        final next = _getHexagonCenter(dragPath[i].x, dragPath[i].y);
        path.lineTo(next.dx, next.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.yellow.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }

    final borderRect = Rect.fromLTRB(
      fieldRect.left - borderInset,
      fieldRect.top - borderInset,
      fieldRect.right + borderInset,
      fieldRect.bottom + borderInset,
    );
    canvas.drawRect(
      borderRect,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.restore();
  }

  Offset _getHexagonCenter(int row, int col) {
    double x = boardPadding + _rowOffset(row) + col * hexStepX;
    double y = boardPadding + row * hexStepY;
    return Offset(x, y);
  }

  void _drawHexagon(Canvas canvas, int row, int col, Size size) {
    Offset center = _getHexagonCenter(row, col);
    Color fillColor = grid[row][col].color;
    final isSelected = selectedRow == row && selectedCol == col;
    final isHovered = hoverRow == row && hoverCol == col;
    final cell = Point(row, col);
    final snapStart = snapStartMs[cell];
    final appearStart = appearStartMs[cell];
    final nowMs = fxTimeMs.value;
    final snapProgress = snapStart != null
        ? ((nowMs - snapStart) / _MyHomePageState._snapDurationMs)
            .clamp(0.0, 1.0)
        : 0.0;
    final appearProgress = appearStart != null
        ? ((nowMs - appearStart) / _MyHomePageState._appearDurationMs)
            .clamp(0.0, 1.0)
        : 0.0;
    final isSnapping = snapStart != null && snapProgress < 1.0;
    final isAppearing = appearStart != null && appearProgress < 1.0;
    const stepCount = 7;
    final steppedAppear = isAppearing
        ? ((appearProgress * stepCount).floor() / stepCount).clamp(0.0, 1.0)
        : appearProgress;
    final steppedSnap = isSnapping
        ? ((snapProgress * stepCount).floor() / stepCount).clamp(0.0, 1.0)
        : snapProgress;
    final animationScale = isAppearing
        ? (0.08 + 0.92 * steppedAppear)
        : (isSnapping ? (1.0 - 0.25 * steppedSnap) : 1.0);
    final animationAlpha = isAppearing
        ? steppedAppear
        : (isSnapping ? (1.0 - steppedSnap) : 1.0);
    final dustProgress = isSnapping ? steppedSnap : 0.0;
    final snapJitter = isSnapping ? (1.0 - steppedSnap) : 0.0;

    canvas.save();

    Path path = isHovered && hoverPosition != null
        ? _createDeformedHexagonPath(center, hoverPosition!)
        : _createHexagonPath(center);
    if (isSnapping) {
      path = _createSnapDeformedPath(path, row, col, snapJitter);
    }

    final shadowPath = _createShadowPath(path, row, col);
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    if (animationScale != 1.0) {
      canvas.translate(center.dx, center.dy);
      canvas.scale(animationScale);
      canvas.translate(-center.dx, -center.dy);
    }

    // Apply 80% scale when hexagon is selected
    if (isSelected) {
      canvas.translate(center.dx, center.dy);
      canvas.scale(0.8);
      canvas.translate(-center.dx, -center.dy);
    }

    if (isSnapping) {
      _drawSnapPieces(canvas, path, fillColor, row, col, dustProgress);
      if (isSnapping) {
        _drawDust(canvas, center, dustProgress, fillColor, row, col);
      }
      canvas.restore();
      return;
    }

    final foilRect = Rect.fromCircle(center: center, radius: hexSize);
    final localWiggle = isHovered ? hoverWiggleValue.value : 0.0;
    final shimmer = (sin(localWiggle * 2 * pi)).abs();
    final boardCenter = _computeFieldRect().center;
    final lightVec = boardCenter - center;
    final lightAngle = atan2(lightVec.dy, lightVec.dx);
    final pointer = hoverPosition;
    final pointerVec = pointer != null ? pointer - center : Offset.zero;
    final pointerDist = pointer != null ? pointerVec.distance : double.infinity;
    final pointerDir = pointerDist > 0 ? pointerVec / pointerDist : const Offset(0, 0);
    final glareStrength = (1.0 - (pointerDist / (hexSize * 2.2))).clamp(0.0, 1.0);
    final base = HSVColor.fromColor(fillColor);
    final foilColors = [
      _tintColor(base, -35, 0.9, 0.95),
      _tintColor(base, -5, 1.0, 1.02),
      _tintColor(base, 20, 1.05, 1.08),
      _tintColor(base, 45, 0.95, 1.0),
      _tintColor(base, 70, 0.9, 0.95),
    ];
    final glareShift = (pointerDir.dx * 0.4 + pointerDir.dy * 0.2) * glareStrength;
    final foilPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + glareShift, -0.8 - glareShift * 0.5),
        end: Alignment(1 + glareShift, 0.8 + glareShift * 0.5),
        colors: foilColors,
        stops: const [0.0, 0.26, 0.5, 0.74, 1.0],
        transform: GradientRotation(lightAngle + 0.35 * sin(localWiggle * 2 * pi)),
      ).createShader(foilRect)
      ..style = PaintingStyle.fill;
    canvas.saveLayer(foilRect, Paint()..color = Colors.white.withValues(alpha: animationAlpha));
    canvas.drawPath(path, foilPaint);

    final sparklePaint = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.6, -1),
        end: const Alignment(0.6, 1),
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.04 + shimmer * 0.12 + glareStrength * 0.18),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(lightAngle - 0.5 * sin(localWiggle * 2 * pi)),
      ).createShader(foilRect)
      ..blendMode = BlendMode.screen;
    if (isHovered || glareStrength > 0) {
      canvas.drawPath(path, sparklePaint);
    }
    if (glareStrength > 0) {
      final glareRect = Rect.fromCircle(center: center, radius: hexSize * 0.85);
      final glarePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment(pointerDir.dx, pointerDir.dy),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.15 * glareStrength),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(glareRect)
        ..blendMode = BlendMode.screen;
      canvas.drawPath(path, glarePaint);
    }
    canvas.restore();

    if (glareStrength > 0) {
      const pixel = 6.0;
      final startX = center.dx - hexSize;
      final endX = center.dx + hexSize;
      final startY = center.dy - hexSize;
      final endY = center.dy + hexSize;
      final tint = Colors.white.withValues(alpha: 0.06 * glareStrength);
      for (double y = startY; y <= endY; y += pixel) {
        for (double x = startX; x <= endX; x += pixel) {
          final cell = Rect.fromLTWH(x, y, pixel, pixel);
          if (path.contains(cell.center)) {
            canvas.drawRect(cell, Paint()..color = tint);
          }
        }
      }
    }

    // Draw border (black or yellow if selected)
    canvas.drawPath(
      path,
      Paint()
        ..color = isSelected ? Colors.yellow : Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 2,
    );
    if (isSelected) {
      final borderGlare = Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -1),
          end: const Alignment(1, 1),
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: hexSize))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..blendMode = BlendMode.screen;
      canvas.drawPath(path, borderGlare);
    }

    canvas.restore();
  }

  Path _createHexagonPath(Offset center) {
    Path path = Path();
    // Flat-top hexagon: start at 30° and go around
    for (int i = 0; i < 6; i++) {
      double angle = (i * 60 + 30) * pi / 180;
      double x = center.dx + hexSize * cos(angle);
      double y = center.dy + hexSize * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _createShadowPath(Path base, int row, int col) {
    final seedA = _hash(row, col, 1);
    final seedB = _hash(row, col, 2);
    final dx = 3 + seedA * 2;
    final dy = 5 + seedB * 2;
    const jitter = 0.6;
    final shifted = base.shift(Offset(dx, dy));
    final m = shifted.computeMetrics().first;
    final rough = Path();
    const steps = 36;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final pos = m.getTangentForOffset(m.length * t)!.position;
      final jx = (sin((t * 12 + seedA) * pi * 2)) * jitter;
      final jy = (cos((t * 14 + seedB) * pi * 2)) * jitter;
      if (i == 0) {
        rough.moveTo(pos.dx + jx, pos.dy + jy);
      } else {
        rough.lineTo(pos.dx + jx, pos.dy + jy);
      }
    }
    rough.close();
    return rough;
  }

  Path _createSnapDeformedPath(Path base, int row, int col, double t) {
    final m = base.computeMetrics().first;
    final rough = Path();
    const steps = 24;
    final amp = 1.2 + 1.6 * t;
    for (int i = 0; i <= steps; i++) {
      final u = i / steps;
      final pos = m.getTangentForOffset(m.length * u)!.position;
      final jx = sin((u * 9 + row * 0.37 + col * 0.51) * pi * 2) * amp;
      final jy = cos((u * 11 + row * 0.41 + col * 0.29) * pi * 2) * amp;
      if (i == 0) {
        rough.moveTo(pos.dx + jx, pos.dy + jy);
      } else {
        rough.lineTo(pos.dx + jx, pos.dy + jy);
      }
    }
    rough.close();
    return rough;
  }

  void _drawSnapPieces(
    Canvas canvas,
    Path path,
    Color baseColor,
    int row,
    int col,
    double t,
  ) {
    final bounds = path.getBounds();
    const piece = 8.0;
    final drift = 8.0 * t;
    for (double y = bounds.top; y <= bounds.bottom; y += piece) {
      for (double x = bounds.left; x <= bounds.right; x += piece) {
        final cell = Rect.fromLTWH(x, y, piece, piece);
        if (!path.contains(cell.center)) {
          continue;
        }
        final seedIndex = (x * 7 + y * 3).floor();
        final seed = _hash(row, col, seedIndex);
        final angle = seed * 2 * pi;
        final burst = 0.4 + 0.6 * _hash(row + 7, col + 3, seedIndex);
        final dx = cos(angle) * drift * burst;
        final dy = sin(angle) * drift * burst;
        final collide = _hash(row + 11, col + 5, seedIndex);
        if (collide > 0.7) {
          final push = 0.6 * drift;
          final avoid = angle + (collide > 0.85 ? 1 : -1) * (pi * 0.35);
          final cx = cos(avoid) * push;
          final cy = sin(avoid) * push;
          final jitter = 0.3 * drift;
          final jx = (seed - 0.5) * jitter;
          final jy = (_hash(row + 17, col + 9, seedIndex) - 0.5) * jitter;
          final shifted = cell.shift(Offset(dx + cx + jx, dy + cy + jy));
          _drawSnapPieceCell(canvas, shifted, baseColor, t);
          continue;
        }
        final shifted = cell.shift(Offset(dx, dy));
        _drawSnapPieceCell(canvas, shifted, baseColor, t);
      }
    }
  }

  void _drawSnapPieceCell(Canvas canvas, Rect cell, Color baseColor, double t) {
    final shadow = cell.shift(const Offset(2, 3));
    canvas.drawRect(
      shadow,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * (1.0 - t))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRect(
      cell,
      Paint()
        ..color = baseColor.withValues(alpha: 0.85 * (1.0 - t))
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      cell,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6 * (1.0 - t))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawDust(Canvas canvas, Offset center, double t, Color baseColor, int row, int col) {
    const count = 20;
    for (int i = 0; i < count; i++) {
      final seed = _hash(row, col, i);
      final angle = seed * 2 * pi;
      final radius = (0.2 + 0.8 * _hash(row + 3, col + 7, i)) * hexSize;
      final drift = 6 + 18 * t;
      final dx = cos(angle) * radius + cos(angle + t * 2.1) * drift;
      final dy = sin(angle) * radius + sin(angle + t * 1.9) * drift;
      final p = Offset(center.dx + dx, center.dy + dy);
      final alpha = (1.0 - t) * (0.6 + 0.4 * _hash(row + 11, col + 5, i));
      final size = 1.4 + 2.2 * _hash(row + 17, col + 9, i);
      canvas.drawCircle(
        p,
        size,
        Paint()
          ..color = baseColor.withValues(alpha: 0.35 * alpha)
          ..blendMode = BlendMode.screen,
      );
    }
  }

  double _hash(int a, int b, int c) {
    final v = sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453;
    return v - v.floorToDouble();
  }

  Path _createDeformedHexagonPath(Offset center, Offset hover) {
    final dir = hover - center;
    final distance = dir.distance;
    if (distance == 0) {
      return _createHexagonPath(center);
    }
    final maxDist = hexSize;
    final strength = (distance / maxDist).clamp(0.0, 1.0);
    final n = dir / distance;
    final squash = 1.0 - 0.12 * strength;
    final stretch = 1.0 + 0.06 * strength;

    Path path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = (i * 60 + 30) * pi / 180;
      final baseX = center.dx + hexSize * cos(angle);
      final baseY = center.dy + hexSize * sin(angle);
      final v = Offset(baseX - center.dx, baseY - center.dy);
      final dot = v.dx * n.dx + v.dy * n.dy;
      final proj = Offset(n.dx * dot, n.dy * dot);
      final perp = Offset(v.dx - proj.dx, v.dy - proj.dy);
      final scale = dot >= 0 ? stretch : squash;
      final deformed = Offset(
        center.dx + perp.dx + proj.dx * scale,
        center.dy + perp.dy + proj.dy * scale,
      );
      if (i == 0) {
        path.moveTo(deformed.dx, deformed.dy);
      } else {
        path.lineTo(deformed.dx, deformed.dy);
      }
    }
    path.close();
    return path;
  }

  Color _tintColor(HSVColor base, double hueShift, double satMult, double valMult) {
    final hue = (base.hue + hueShift) % 360;
    final sat = (base.saturation * satMult).clamp(0.0, 1.0);
    final val = (base.value * valMult).clamp(0.0, 1.0);
    return base.withHue(hue).withSaturation(sat).withValue(val).toColor();
  }

  Rect _computeFieldRect() {
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        final center = _getHexagonCenter(r, c);
        minX = min(minX, center.dx - hexSize);
        maxX = max(maxX, center.dx + hexSize);
        minY = min(minY, center.dy - hexSize);
        maxY = max(maxY, center.dy + hexSize);
      }
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  @override
  bool shouldRepaint(HexagonGridPainter oldDelegate) {
    return true;
  }
}
