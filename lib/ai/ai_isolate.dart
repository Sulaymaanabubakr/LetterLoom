import 'dart:async';
import 'dart:isolate';
import '../models/board_cell.dart';
import '../models/tile.dart';
import 'ai_engine.dart';

class AIComputationResult {
  final Map<String, dynamic>? data;
  final String? error;

  AIComputationResult({this.data, this.error});
}

class AIComputeTask {
  final Isolate _isolate;
  final ReceivePort _receivePort;
  final Completer<AIMove> _completer = Completer<AIMove>();

  AIComputeTask(this._isolate, this._receivePort) {
    _receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        if (message.containsKey('error')) {
          _completer.completeError(Exception(message['error']));
        } else {
          _completer.complete(AIMove.fromJson(message));
        }
      }
      _cleanup();
    }, onError: (err) {
      _completer.completeError(err);
      _cleanup();
    }, onDone: () {
      if (!_completer.isCompleted) {
        _completer.complete(AIMove.pass()); // Fallback pass
      }
    });
  }

  Future<AIMove> get future => _completer.future;

  void cancel() {
    _isolate.kill(priority: Isolate.immediate);
    _cleanup();
    if (!_completer.isCompleted) {
      _completer.complete(AIMove.pass());
    }
  }

  void _cleanup() {
    _receivePort.close();
  }
}

class AIService {
  static AIComputeTask? _currentTask;

  /// Starts the AI computation in a background isolate.
  /// If an AI computation is already active, it cancels it.
  static Future<AIMove> calculateMove({
    required List<List<BoardCell>> board,
    required List<Tile> rack,
    required String difficulty,
    required List<String> dictionaryWords,
  }) async {
    // Cancel any ongoing computation
    cancelCurrentTask();

    final receivePort = ReceivePort();
    final Map<String, dynamic> args = {
      'board': board.map((row) => row.map((cell) => cell.toJson()).toList()).toList(),
      'rack': rack.map((t) => t.toJson()).toList(),
      'difficulty': difficulty,
      'wordsList': dictionaryWords,
      'replyPort': receivePort.sendPort,
    };

    try {
      final isolate = await Isolate.spawn(_isolateEntry, args);
      final task = AIComputeTask(isolate, receivePort);
      _currentTask = task;
      return await task.future;
    } catch (e) {
      print("Failed to spawn AI isolate: $e");
      receivePort.close();
      return AIMove.pass(); // Return fallback pass
    }
  }

  static void cancelCurrentTask() {
    if (_currentTask != null) {
      print("Cancelling active AI isolate task...");
      _currentTask!.cancel();
      _currentTask = null;
    }
  }

  /// Isolate entrypoint function
  static void _isolateEntry(Map<String, dynamic> args) {
    final SendPort replyPort = args['replyPort'] as SendPort;

    try {
      // Calculate move using the engine
      final Map<String, dynamic> resultJson = AIEngine.computeMove(args);
      replyPort.send(resultJson);
    } catch (e) {
      replyPort.send({'error': e.toString()});
    }
  }
}
