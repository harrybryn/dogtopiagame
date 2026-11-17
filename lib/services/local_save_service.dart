import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/game_controller.dart';

class LocalSaveService {
  static final LocalSaveService instance = LocalSaveService._internal();
  LocalSaveService._internal();

  static const String saveKey = 'dogtopia_save_v1';

  Timer? _debounceTimer;
  bool _isLoading = false;

  /// Loads locally persisted progress into [game], if present.
  /// Returns true when an existing save was found and applied.
  Future<bool> loadInto(GameController game) async {
    _isLoading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(saveKey);
      if (raw == null || raw.isEmpty) {
        return false;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        game.loadFromJson(decoded);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('LocalSaveService.loadInto error: $e');
      return false;
    } finally {
      _isLoading = false;
    }
  }

  /// Debounced auto-save called whenever [GameController] notifies listeners.
  void scheduleAutoSave(
    GameController game, {
    Duration delay = const Duration(milliseconds: 1200),
  }) {
    if (_isLoading) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      saveNow(game);
    });
  }

  /// Immediately writes the current [game] state to local storage.
  Future<bool> saveNow(GameController game) async {
    if (_isLoading) return false;
    _debounceTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(game.toJson());
      return await prefs.setString(saveKey, payload);
    } catch (e) {
      debugPrint('LocalSaveService.saveNow error: $e');
      return false;
    }
  }

  /// Clears saved local progress (e.g. for a fresh start).
  Future<void> clearSave() async {
    _debounceTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(saveKey);
    } catch (e) {
      debugPrint('LocalSaveService.clearSave error: $e');
    }
  }

  void cancelPending() {
    _debounceTimer?.cancel();
  }
}
