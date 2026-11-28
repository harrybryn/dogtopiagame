import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/game_controller.dart';
import 'local_save_service.dart';

/// Data model representing a linked Google user account.
class GoogleUserData {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final int linkedAt;
  int lastSyncedAt;

  GoogleUserData({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.linkedAt,
    required this.lastSyncedAt,
  });

  String get initials {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'G';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'linkedAt': linkedAt,
        'lastSyncedAt': lastSyncedAt,
      };

  factory GoogleUserData.fromJson(Map<String, dynamic> json) => GoogleUserData(
        id: json['id'] as String? ?? 'google_user_default',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Google Keeper',
        photoUrl: json['photoUrl'] as String?,
        linkedAt: json['linkedAt'] as int? ?? 0,
        lastSyncedAt: json['lastSyncedAt'] as int? ?? 0,
      );
}

/// Service managing Google Account connection, cloud persistence & cloud sync.
class GoogleAuthService extends ChangeNotifier {
  GoogleAuthService._internal();
  static final GoogleAuthService instance = GoogleAuthService._internal();

  static const String storageUserKey = 'dogtopia_google_auth_user_v1';
  static const String storageCloudSaveKey = 'dogtopia_google_cloud_save_v1';

  GoogleUserData? _currentUser;
  bool _isSyncing = false;
  bool _isRestoring = false;
  bool _initialized = false;
  Map<String, dynamic>? _cloudSaveMetadata;

  GoogleUserData? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isSyncing => _isSyncing;
  bool get isRestoring => _isRestoring;
  bool get isInitialized => _initialized;
  Map<String, dynamic>? get cloudSaveMetadata => _cloudSaveMetadata;

  /// Initializes the service and restores any existing Google login & cloud save metadata.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userRaw = prefs.getString(storageUserKey);
      if (userRaw != null && userRaw.isNotEmpty) {
        final decoded = jsonDecode(userRaw);
        if (decoded is Map<String, dynamic>) {
          _currentUser = GoogleUserData.fromJson(decoded);
        }
      }

      await _refreshCloudSaveMetadata(prefs);
    } catch (e) {
      debugPrint('GoogleAuthService.init error: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _refreshCloudSaveMetadata([SharedPreferences? existingPrefs]) async {
    try {
      final prefs = existingPrefs ?? await SharedPreferences.getInstance();
      final cloudRaw = prefs.getString(storageCloudSaveKey);
      if (cloudRaw != null && cloudRaw.isNotEmpty) {
        final decoded = jsonDecode(cloudRaw);
        if (decoded is Map<String, dynamic>) {
          _cloudSaveMetadata = {
            'level': decoded['level'] ?? 1,
            'playerUsername': decoded['playerUsername'] ?? 'Keeper',
            'coins': decoded['coins'] ?? 0,
            'crystals': decoded['crystals'] ?? 0,
            'savedAt': decoded['savedAt'] ?? 0,
            'habitatsCount': (decoded['habitats'] as List?)?.length ?? 0,
          };
          return;
        }
      }
      _cloudSaveMetadata = null;
    } catch (e) {
      debugPrint('GoogleAuthService._refreshCloudSaveMetadata error: $e');
      _cloudSaveMetadata = null;
    }
  }

  /// Links a Google Account and immediately executes an initial cloud backup if a [game] instance is provided.
  Future<GoogleUserData> connectAccount({
    required String email,
    required String displayName,
    String? photoUrl,
    GameController? game,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = 'goog_${email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${now % 100000}';

    final user = GoogleUserData(
      id: id,
      email: email.trim(),
      displayName: displayName.trim().isEmpty ? 'Google Keeper' : displayName.trim(),
      photoUrl: photoUrl,
      linkedAt: now,
      lastSyncedAt: now,
    );

    _currentUser = user;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageUserKey, jsonEncode(user.toJson()));

      if (game != null) {
        await syncCloudNow(game, prefs: prefs);
      }
    } catch (e) {
      debugPrint('GoogleAuthService.connectAccount error: $e');
    }

    notifyListeners();
    return user;
  }

  /// Unlinks Google account (local save and existing cloud backup remain intact).
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageUserKey);
    } catch (e) {
      debugPrint('GoogleAuthService.signOut error: $e');
    }

    _currentUser = null;
    notifyListeners();
  }

  /// Immediately backs up the active [game] state to the Google Cloud slot.
  Future<bool> syncCloudNow(GameController game, {SharedPreferences? prefs}) async {
    if (!isSignedIn) return false;
    _isSyncing = true;
    notifyListeners();

    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;

      final payload = game.toJson();
      payload['savedAt'] = now;
      if (_currentUser != null) {
        payload['googleUserId'] = _currentUser!.id;
        payload['googleEmail'] = _currentUser!.email;
      }

      await p.setString(storageCloudSaveKey, jsonEncode(payload));

      _currentUser?.lastSyncedAt = now;
      if (_currentUser != null) {
        await p.setString(storageUserKey, jsonEncode(_currentUser!.toJson()));
      }

      await _refreshCloudSaveMetadata(p);
      return true;
    } catch (e) {
      debugPrint('GoogleAuthService.syncCloudNow error: $e');
      return false;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Reads raw cloud save data.
  Future<Map<String, dynamic>?> getCloudSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageCloudSaveKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint('GoogleAuthService.getCloudSave error: $e');
      return null;
    }
  }

  /// Restores the island progress saved in the Google Cloud slot into [game].
  Future<bool> restoreCloudSave(GameController game) async {
    if (!isSignedIn) return false;
    _isRestoring = true;
    notifyListeners();

    try {
      final data = await getCloudSave();
      if (data == null) return false;

      game.loadFromJson(data);
      await LocalSaveService.instance.saveNow(game);
      return true;
    } catch (e) {
      debugPrint('GoogleAuthService.restoreCloudSave error: $e');
      return false;
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }
}
