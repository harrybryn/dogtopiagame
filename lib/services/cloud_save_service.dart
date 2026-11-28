import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../state/game_controller.dart';
import 'local_save_service.dart';
import 'oauth_loopback_stub.dart'
    if (dart.library.io) 'oauth_loopback_io.dart';

enum CloudSyncStatus {
  notConfigured,
  notSignedIn,
  uploadedLocal,
  loadedFromCloud,
  upToDate,
  accountAlreadyExists,
  noCloudAccountFound,
  failed,
}

class ExistingCloudAccount {
  final String email;
  final String username;
  final int level;
  final int coins;
  final Map<String, dynamic> saveData;

  const ExistingCloudAccount({
    required this.email,
    required this.username,
    required this.level,
    required this.coins,
    required this.saveData,
  });
}

class CloudSaveService {
  static final CloudSaveService instance = CloudSaveService._internal();
  CloudSaveService._internal();

  static const String _tableName = 'player_saves';
  static const String _preferCloudOnLoginKey = 'dogtopia_prefer_cloud_on_login';
  static const String _connectModeKey = 'dogtopia_google_connect_mode';

  bool _initialized = false;
  bool _isSyncing = false;
  bool _lastSyncWasSwitch = false;
  String? _lastError;
  ExistingCloudAccount? _pendingExistingAccount;
  Timer? _debounceTimer;

  bool get isAvailable => _initialized;
  bool get isSyncing => _isSyncing;
  bool get lastSyncWasSwitch => _lastSyncWasSwitch;
  String? get lastError => _lastError;
  ExistingCloudAccount? get pendingExistingAccount => _pendingExistingAccount;

  SupabaseClient get _client => Supabase.instance.client;

  User? get currentUser => _initialized ? _client.auth.currentUser : null;
  bool get isSignedIn => currentUser != null;
  String? get userEmail => currentUser?.email;

  Stream<AuthState> get onAuthStateChange => _initialized
      ? _client.auth.onAuthStateChange
      : const Stream<AuthState>.empty();

  Future<void> init() async {
    if (_initialized || !SupabaseConfig.isConfigured) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('CloudSaveService.init error: $e');
    }
  }

  /// Starts Google OAuth sign-in via Supabase.
  ///
  /// When [preferCloud] is true (e.g. "Already have an account? Log in with
  /// Google"), the next login sync will restore the cloud save over any newer
  /// local guest progress.
  ///
  /// On Desktop (Windows/macOS/Linux), spins up a temporary loopback HTTP
  /// server (`http://localhost:<port>`) so Supabase's `?code=...` redirect
  /// completes the session without needing OS custom-scheme registration.
  Future<bool> signInWithGoogle({
    bool preferCloud = false,
    bool selectAccount = false,
    bool switchAccount = false,
  }) async {
    if (!_initialized) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _connectModeKey,
        switchAccount ? 'switch' : (preferCloud ? 'login' : 'connect'),
      );
      if (preferCloud || switchAccount) {
        await prefs.setBool(_preferCloudOnLoginKey, true);
      } else {
        await prefs.remove(_preferCloudOnLoginKey);
      }

      final queryParams =
          selectAccount ? const {'prompt': 'select_account'} : null;

      if (kIsWeb) {
        return await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
          queryParams: queryParams,
        );
      }

      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux) {
        return await signInWithDesktopLoopback(
          _client,
          selectAccount: selectAccount,
        );
      }

      return await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: SupabaseConfig.mobileRedirectUrl,
        queryParams: queryParams,
      );
    } catch (e) {
      debugPrint('CloudSaveService.signInWithGoogle error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    _debounceTimer?.cancel();
    if (!_initialized) return;
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('CloudSaveService.signOut error: $e');
    }
  }

  /// Deletes the current `auth.users` record if it has no row in `player_saves`
  /// (via the `delete_unlinked_auth_user` Supabase RPC) and signs out.
  Future<void> discardUnlinkedAuthUser() async {
    _debounceTimer?.cancel();
    if (!_initialized) return;
    try {
      if (currentUser != null) {
        await _client.rpc('delete_unlinked_auth_user');
      }
    } catch (e) {
      debugPrint('CloudSaveService.discardUnlinkedAuthUser rpc error: $e');
    }
    await signOut();
  }

  /// Debounced cloud auto-save called on game state updates.
  void scheduleAutoSave(
    GameController game, {
    Duration delay = const Duration(seconds: 2),
  }) {
    if (!_initialized || !isSignedIn || !game.hasUsername || _isSyncing) {
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      saveNow(game);
    });
  }

  /// Immediately upserts the current [game] state into `public.player_saves`.
  Future<bool> saveNow(GameController game) async {
    if (!_initialized || !isSignedIn || !game.hasUsername || _isSyncing) {
      return false;
    }
    _debounceTimer?.cancel();
    final user = currentUser;
    if (user == null) return false;

    _lastError = null;
    try {
      final payload = game.toJson();
      final avatarUrl = (user.userMetadata?['avatar_url'] ??
              user.userMetadata?['picture'])
          ?.toString();
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        payload['avatarUrl'] = avatarUrl;
      }
      await _client.from(_tableName).upsert(
        {
          'user_id': user.id,
          'username': game.playerUsername,
          'level': game.level,
          'coins': game.coins,
          'save_data': payload,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('CloudSaveService.saveNow error: $e');
      return false;
    }
  }

  /// Checks if [username] is available in `player_saves` (case-insensitive).
  /// Returns `null` when available, or an error message if taken / check failed.
  Future<String?> checkUsernameAvailability(
    String username, {
    String? excludeUserId,
  }) async {
    if (!_initialized) return null;
    final cleaned = username.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return 'Please enter a username.';
    try {
      final res = await _client.rpc(
        'is_username_available',
        params: {
          'p_username': cleaned,
          if (excludeUserId != null) 'p_exclude_user_id': excludeUserId,
        },
      );
      if (res == false) {
        return 'Username already exists. Choose another.';
      }
      return null;
    } on PostgrestException catch (e) {
      debugPrint('CloudSaveService.checkUsernameAvailability error: $e');
      if (e.code == 'PGRST202') {
        return 'Username check function missing in Supabase (run SQL setup).';
      }
      return 'Could not verify username. Try again.';
    } catch (e) {
      debugPrint('CloudSaveService.checkUsernameAvailability error: $e');
      return null;
    }
  }

  /// Reconciles local and cloud progress using `savedAt` timestamps.
  ///
  /// When [preferCloud] is true (or was persisted via [signInWithGoogle]),
  /// an existing cloud save always takes precedence over local state.
  /// When connecting via "Connect with Google" and an account already exists
  /// in `player_saves`, returns [CloudSyncStatus.accountAlreadyExists] so the
  /// UI can prompt the user before switching accounts.
  Future<CloudSyncStatus> syncOnLogin(
    GameController game, {
    bool preferCloud = false,
    bool switchAccount = false,
  }) async {
    if (!_initialized) return CloudSyncStatus.notConfigured;
    final user = currentUser;
    if (user == null) return CloudSyncStatus.notSignedIn;

    _isSyncing = true;
    _lastError = null;
    _pendingExistingAccount = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final connectMode = prefs.getString(_connectModeKey);
      final isSwitchFlow = switchAccount || connectMode == 'switch';
      _lastSyncWasSwitch = isSwitchFlow;
      final isLoginFlow = !isSwitchFlow &&
          (preferCloud ||
              connectMode == 'login' ||
              (prefs.getBool(_preferCloudOnLoginKey) ?? false));
      final shouldPreferCloud = preferCloud || isSwitchFlow || isLoginFlow;
      final isConnectFlow =
          !preferCloud && !isSwitchFlow && connectMode == 'connect';
      await prefs.remove(_connectModeKey);
      await prefs.remove(_preferCloudOnLoginKey);

      final row = await _client
          .from(_tableName)
          .select('username, level, coins, save_data')
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null || row['save_data'] == null) {
        _isSyncing = false;
        if (isSwitchFlow || isLoginFlow) {
          return CloudSyncStatus.noCloudAccountFound;
        }
        if (game.hasUsername) {
          final uploaded = await saveNow(game);
          return uploaded
              ? CloudSyncStatus.uploadedLocal
              : CloudSyncStatus.failed;
        }
        return CloudSyncStatus.upToDate;
      }

      final cloudData = Map<String, dynamic>.from(row['save_data'] as Map);
      final cloudSavedAt = (cloudData['savedAt'] as num?)?.toInt() ?? 0;

      if (isConnectFlow) {
        _pendingExistingAccount = ExistingCloudAccount(
          email: user.email ?? 'Google Account',
          username: (row['username'] as String?) ?? 'Keeper',
          level: (row['level'] as num?)?.toInt() ?? 1,
          coins: (row['coins'] as num?)?.toInt() ?? 0,
          saveData: cloudData,
        );
        return CloudSyncStatus.accountAlreadyExists;
      }

      if (shouldPreferCloud || !game.hasUsername || cloudSavedAt > game.savedAt) {
        game.loadFromJson(cloudData);
        await LocalSaveService.instance.saveNow(game);
        return CloudSyncStatus.loadedFromCloud;
      }

      if (game.savedAt > cloudSavedAt) {
        _isSyncing = false;
        final uploaded = await saveNow(game);
        return uploaded
            ? CloudSyncStatus.uploadedLocal
            : CloudSyncStatus.failed;
      }

      return CloudSyncStatus.upToDate;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('CloudSaveService.syncOnLogin error: $e');
      return CloudSyncStatus.failed;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> confirmLoadExistingAccount(GameController game) async {
    final pending = _pendingExistingAccount;
    _pendingExistingAccount = null;
    if (pending == null) return;
    game.loadFromJson(pending.saveData);
    await LocalSaveService.instance.saveNow(game);
  }

  Future<void> cancelExistingAccountSignIn() async {
    _pendingExistingAccount = null;
    await signOut();
  }

  void cancelPending() {
    _debounceTimer?.cancel();
  }
}
