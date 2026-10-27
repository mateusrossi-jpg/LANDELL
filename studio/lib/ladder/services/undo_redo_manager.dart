import 'dart:convert';
import '../models/ladder_project.dart';

class UndoRedoManager {
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  final int maxHistory;

  UndoRedoManager({this.maxHistory = 50});

  void saveState(LadderProject project) {
    final jsonStr = jsonEncode(project.toJson());
    
    // Prevent saving identical sequential states
    if (_undoStack.isNotEmpty && _undoStack.last == jsonStr) return;
    
    _redoStack.clear(); // Whenever a new action occurs, redo is invalidated
    
    _undoStack.add(jsonStr);
    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
  }

  bool get canUndo => _undoStack.length > 1; // 1 is the current state
  bool get canRedo => _redoStack.isNotEmpty;

  LadderProject? undo(LadderProject current) {
    if (!canUndo) return null;
    
    _redoStack.add(jsonEncode(current.toJson()));
    _undoStack.removeLast(); // Pop current state
    
    final previousStateStr = _undoStack.last;
    return LadderProject.fromJson(jsonDecode(previousStateStr));
  }

  LadderProject? redo(LadderProject current) {
    if (!canRedo) return null;
    
    _undoStack.add(jsonEncode(current.toJson()));
    final nextStateStr = _redoStack.removeLast();
    
    return LadderProject.fromJson(jsonDecode(nextStateStr));
  }
}
