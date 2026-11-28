import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friend_visit_model.dart';
import '../state/game_controller.dart';
import 'cloud_save_service.dart';

class FriendRequestItem {
  final String friendshipId;
  final String userId;
  final String username;
  final int level;
  final String? avatarUrl;
  final bool isIncoming;

  const FriendRequestItem({
    required this.friendshipId,
    required this.userId,
    required this.username,
    required this.level,
    this.avatarUrl,
    required this.isIncoming,
  });
}

class SocialFriendEntry {
  final String friendshipId;
  final MockFriend friend;

  const SocialFriendEntry({
    required this.friendshipId,
    required this.friend,
  });
}

class PlayerSearchPreview {
  final String userId;
  final String username;
  final int level;
  final int buildingsCount;
  final String? avatarUrl;
  final DateTime? updatedAt;

  const PlayerSearchPreview({
    required this.userId,
    required this.username,
    required this.level,
    required this.buildingsCount,
    this.avatarUrl,
    this.updatedAt,
  });
}

class GiftInboxItem {
  final String id;
  final String senderId;
  final String senderUsername;
  final String? senderAvatarUrl;
  final int coins;
  final int kibble;
  final bool claimed;
  final DateTime? createdAt;

  const GiftInboxItem({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    this.senderAvatarUrl,
    required this.coins,
    required this.kibble,
    required this.claimed,
    this.createdAt,
  });
}

class SocialData {
  final List<SocialFriendEntry> friends;
  final List<FriendRequestItem> incomingRequests;
  final List<FriendRequestItem> outgoingRequests;
  final List<GiftInboxItem> inboxGifts;

  const SocialData({
    this.friends = const [],
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.inboxGifts = const [],
  });
}

class SocialService {
  static final SocialService instance = SocialService._internal();
  SocialService._internal();

  static const String _friendshipsTable = 'friendships';
  static const String _savesTable = 'player_saves';
  static const String _giftsTable = 'friend_gifts';

  final StreamController<void> _socialChangedController =
      StreamController<void>.broadcast();
  final StreamController<String> _giftNotificationController =
      StreamController<String>.broadcast();

  RealtimeChannel? _channel;
  String? _listeningUserId;
  int _unclaimedGiftCount = 0;

  Stream<void> get onSocialChanged => _socialChangedController.stream;
  Stream<String> get onGiftNotification => _giftNotificationController.stream;
  int get unclaimedGiftCount => _unclaimedGiftCount;

  bool get isAvailable =>
      CloudSaveService.instance.isAvailable &&
      CloudSaveService.instance.isSignedIn;

  SupabaseClient get _client => Supabase.instance.client;
  String? get _myId => _client.auth.currentUser?.id;

  void startRealtime(GameController game) {
    final myId = _myId;
    if (!isAvailable || myId == null) return;
    if (_listeningUserId == myId && _channel != null) return;

    stopRealtime();
    _listeningUserId = myId;
    refreshUnclaimedGiftCount();

    _channel = _client
        .channel('social_realtime_$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _friendshipsTable,
          callback: (_) {
            _socialChangedController.add(null);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _giftsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myId,
          ),
          callback: (payload) {
            refreshUnclaimedGiftCount();
            _socialChangedController.add(null);
            if (payload.eventType == PostgresChangeEvent.insert) {
              final sender =
                  (payload.newRecord['sender_username'] as String?) ??
                  'A friend';
              _giftNotificationController.add(
                'New gift from $sender! Open Inbox to claim.',
              );
            }
          },
        )
        .subscribe();
  }

  Future<void> stopRealtime() async {
    final ch = _channel;
    _channel = null;
    _listeningUserId = null;
    _unclaimedGiftCount = 0;
    if (ch != null) {
      try {
        await _client.removeChannel(ch);
      } catch (e) {
        debugPrint('SocialService.stopRealtime error: $e');
      }
    }
  }

  Future<void> refreshUnclaimedGiftCount() async {
    final myId = _myId;
    if (!isAvailable || myId == null) {
      _unclaimedGiftCount = 0;
      return;
    }
    try {
      final rows = await _client
          .from(_giftsTable)
          .select('id')
          .eq('receiver_id', myId)
          .eq('claimed', false);
      _unclaimedGiftCount = (rows as List).length;
      _socialChangedController.add(null);
    } catch (_) {}
  }

  Future<Map<String, String>> _fetchAvatarUrls(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    try {
      final res = await _client.rpc(
        'get_player_avatars',
        params: {'p_user_ids': userIds},
      );
      final map = <String, String>{};
      for (final raw in res as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final uid = m['user_id'] as String?;
        final url = m['avatar_url'] as String?;
        if (uid != null && url != null && url.isNotEmpty) {
          map[uid] = url;
        }
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  Future<List<GiftInboxItem>> loadInboxGiftsWithAvatars() async {
    final myId = _myId;
    if (!isAvailable || myId == null) return const [];
    final gifts = await _loadInboxGifts(myId);
    if (gifts.isEmpty) return gifts;

    final senderIds = gifts
        .map((g) => g.senderId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (senderIds.isEmpty) return gifts;

    try {
      final saves = await _client
          .from(_savesTable)
          .select('user_id, save_data')
          .inFilter('user_id', senderIds);
      final avatars = await _fetchAvatarUrls(senderIds);
      for (final raw in saves as List) {
        final m = Map<String, dynamic>.from(raw as Map);
        final uid = m['user_id'] as String?;
        final saveData = m['save_data'] is Map
            ? Map<String, dynamic>.from(m['save_data'] as Map)
            : null;
        final url = saveData?['avatarUrl'] as String?;
        if (uid != null &&
            url != null &&
            url.isNotEmpty &&
            !avatars.containsKey(uid)) {
          avatars[uid] = url;
        }
      }
      return gifts
          .map(
            (g) => GiftInboxItem(
              id: g.id,
              senderId: g.senderId,
              senderUsername: g.senderUsername,
              senderAvatarUrl: avatars[g.senderId],
              coins: g.coins,
              kibble: g.kibble,
              claimed: g.claimed,
              createdAt: g.createdAt,
            ),
          )
          .toList();
    } catch (_) {
      return gifts;
    }
  }

  Future<String?> claimGift(GameController game, GiftInboxItem gift) async {
    if (gift.claimed) return null;
    try {
      final updated = await _client
          .from(_giftsTable)
          .update({'claimed': true})
          .eq('id', gift.id)
          .eq('claimed', false)
          .select('id');
      if ((updated as List).isEmpty) {
        return 'Gift was already claimed.';
      }
      game.addCurrency(coins: gift.coins, kibble: gift.kibble);
      if (_unclaimedGiftCount > 0) _unclaimedGiftCount--;
      _socialChangedController.add(null);
      return null;
    } catch (e) {
      debugPrint('SocialService.claimGift error: $e');
      return 'Failed to claim gift.';
    }
  }

  Future<int> claimAllGifts(
    GameController game,
    List<GiftInboxItem> gifts,
  ) async {
    int claimedCount = 0;
    for (final g in gifts) {
      if (g.claimed) continue;
      final err = await claimGift(game, g);
      if (err == null) claimedCount++;
    }
    return claimedCount;
  }

  Future<String?> sendGift({
    required String receiverId,
    required String senderUsername,
    int coins = 100,
    int kibble = 50,
  }) async {
    final myId = _myId;
    if (!isAvailable || myId == null) {
      return 'Sign in with Google in Settings first.';
    }
    try {
      await _client.from(_giftsTable).insert({
        'sender_id': myId,
        'receiver_id': receiverId,
        'sender_username': senderUsername.isEmpty ? 'Keeper' : senderUsername,
        'coins': coins,
        'kibble': kibble,
      });
      return null;
    } catch (e) {
      debugPrint('SocialService.sendGift error: $e');
      return 'Could not send gift. Check friend_gifts SQL setup.';
    }
  }

  Future<List<GiftInboxItem>> _loadInboxGifts(String myId) async {
    try {
      final rows = await _client
          .from(_giftsTable)
          .select('id, sender_id, sender_username, coins, kibble, claimed, created_at')
          .eq('receiver_id', myId)
          .order('claimed', ascending: true)
          .order('created_at', ascending: false)
          .limit(30);
      final items = (rows as List).map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return GiftInboxItem(
          id: m['id'] as String,
          senderId: (m['sender_id'] as String?) ?? '',
          senderUsername: (m['sender_username'] as String?) ?? 'Keeper',
          coins: (m['coins'] as num?)?.toInt() ?? 100,
          kibble: (m['kibble'] as num?)?.toInt() ?? 50,
          claimed: m['claimed'] == true,
          createdAt: m['created_at'] is String
              ? DateTime.tryParse(m['created_at'] as String)
              : null,
        );
      }).toList();
      _unclaimedGiftCount = items.where((g) => !g.claimed).length;
      return items;
    } catch (e) {
      debugPrint('SocialService._loadInboxGifts error: $e');
      return const [];
    }
  }

  Future<SocialData> loadSocialData() async {
    final myId = _myId;
    if (!isAvailable || myId == null) {
      return const SocialData();
    }

    final inboxGifts = await _loadInboxGifts(myId);

    final rows = await _client
        .from(_friendshipsTable)
        .select('id, requester_id, addressee_id, status')
        .or('requester_id.eq.$myId,addressee_id.eq.$myId')
        .order('created_at', ascending: false);

    final friendshipRows = List<Map<String, dynamic>>.from(rows as List);
    if (friendshipRows.isEmpty) {
      return SocialData(inboxGifts: inboxGifts);
    }

    final otherIds = <String>{};
    for (final row in friendshipRows) {
      final requesterId = row['requester_id'] as String;
      final addresseeId = row['addressee_id'] as String;
      otherIds.add(requesterId == myId ? addresseeId : requesterId);
    }

    final savesRows = await _client
        .from(_savesTable)
        .select('user_id, username, level, save_data, updated_at')
        .inFilter('user_id', otherIds.toList());

    final savesById = <String, Map<String, dynamic>>{};
    for (final raw in savesRows as List) {
      final map = Map<String, dynamic>.from(raw as Map);
      final uid = map['user_id'] as String?;
      if (uid != null) savesById[uid] = map;
    }

    final rpcAvatars = await _fetchAvatarUrls(otherIds.toList());

    final friends = <SocialFriendEntry>[];
    final incoming = <FriendRequestItem>[];
    final outgoing = <FriendRequestItem>[];

    for (final row in friendshipRows) {
      final friendshipId = row['id'] as String;
      final requesterId = row['requester_id'] as String;
      final addresseeId = row['addressee_id'] as String;
      final status = row['status'] as String? ?? 'pending';
      final otherId = requesterId == myId ? addresseeId : requesterId;
      final save = savesById[otherId];
      final username = (save?['username'] as String?) ?? 'Keeper';
      final level = (save?['level'] as num?)?.toInt() ?? 1;

      final saveData = save?['save_data'] is Map
          ? Map<String, dynamic>.from(save!['save_data'] as Map)
          : <String, dynamic>{};
      final resolvedAvatar =
          (saveData['avatarUrl'] as String?) ?? rpcAvatars[otherId];
      if (resolvedAvatar != null && resolvedAvatar.isNotEmpty) {
        saveData['avatarUrl'] = resolvedAvatar;
      }

      if (status == 'accepted') {
        final updatedAt = save?['updated_at'] is String
            ? DateTime.tryParse(save!['updated_at'] as String)
            : null;
        friends.add(
          SocialFriendEntry(
            friendshipId: friendshipId,
            friend: MockFriend.fromCloudSave(
              userId: otherId,
              username: username,
              level: level,
              saveData: saveData,
              updatedAt: updatedAt,
            ),
          ),
        );
      } else if (status == 'pending') {
        final item = FriendRequestItem(
          friendshipId: friendshipId,
          userId: otherId,
          username: username,
          level: level,
          avatarUrl: resolvedAvatar,
          isIncoming: addresseeId == myId,
        );
        if (item.isIncoming) {
          incoming.add(item);
        } else {
          outgoing.add(item);
        }
      }
    }

    return SocialData(
      friends: friends,
      incomingRequests: incoming,
      outgoingRequests: outgoing,
      inboxGifts: inboxGifts,
    );
  }

  /// Searches players by username (empty query lists players for browsing).
  Future<List<PlayerSearchPreview>> searchPlayers(String query) async {
    if (!CloudSaveService.instance.isAvailable) return const [];
    final myId = _myId;

    try {
      final res = await _client.rpc(
        'search_players_by_username',
        params: {'p_query': query.trim()},
      );
      final rows = List<Map<String, dynamic>>.from(res as List);
      return rows.map((row) {
        return PlayerSearchPreview(
          userId: row['user_id'] as String,
          username: (row['username'] as String?) ?? 'Keeper',
          level: (row['level'] as num?)?.toInt() ?? 1,
          buildingsCount: (row['buildings_count'] as num?)?.toInt() ?? 0,
          avatarUrl: row['avatar_url'] as String?,
          updatedAt: row['updated_at'] is String
              ? DateTime.tryParse(row['updated_at'] as String)
              : null,
        );
      }).toList();
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202') rethrow;
      // Fallback if search_players_by_username RPC is not deployed yet.
      final q = query.trim();
      var req = _client
          .from(_savesTable)
          .select('user_id, username, level, save_data, updated_at');
      if (myId != null) {
        req = req.neq('user_id', myId);
      }
      if (q.isNotEmpty) {
        req = req.ilike('username', '%$q%');
      }
      final fallbackRows =
          List<Map<String, dynamic>>.from(await req.limit(30) as List);
      return fallbackRows.map((row) {
        final saveData = row['save_data'] is Map
            ? Map<String, dynamic>.from(row['save_data'] as Map)
            : const <String, dynamic>{};
        final habitats = saveData['placedHabitats'] as List<dynamic>? ?? [];
        return PlayerSearchPreview(
          userId: row['user_id'] as String,
          username: (row['username'] as String?) ?? 'Keeper',
          level: (row['level'] as num?)?.toInt() ?? 1,
          buildingsCount: habitats.length,
          avatarUrl: saveData['avatarUrl'] as String?,
          updatedAt: row['updated_at'] is String
              ? DateTime.tryParse(row['updated_at'] as String)
              : null,
        );
      }).toList();
    }
  }

  /// Sends a friend request to [targetUserId] from a search preview.
  /// Returns null on success, or a user-facing error message.
  Future<String?> sendFriendRequestToUser(
    String targetUserId,
    String targetUsername,
  ) async {
    final myId = _myId;
    if (!isAvailable || myId == null) {
      return 'Sign in with Google in Settings first.';
    }
    if (targetUserId == myId) {
      return 'You cannot add yourself as a friend.';
    }

    try {
      final existing = await _client
          .from(_friendshipsTable)
          .select('id, status, requester_id')
          .or(
            'and(requester_id.eq.$myId,addressee_id.eq.$targetUserId),'
            'and(requester_id.eq.$targetUserId,addressee_id.eq.$myId)',
          )
          .maybeSingle();

      if (existing != null) {
        final status = existing['status'] as String?;
        if (status == 'accepted') {
          return 'You are already friends with $targetUsername!';
        }
        if (existing['requester_id'] == myId) {
          return 'Friend request already sent to $targetUsername.';
        }
        return '$targetUsername already sent you a request! Check Requests.';
      }

      await _client.from(_friendshipsTable).insert({
        'requester_id': myId,
        'addressee_id': targetUserId,
        'status': 'pending',
      });
      return null;
    } catch (e) {
      debugPrint('SocialService.sendFriendRequestToUser error: $e');
      return 'Could not send request. Check Supabase setup.';
    }
  }

  /// Sends a friend request by exact (case-insensitive) username.
  /// Returns null on success, or a user-facing error message.
  Future<String?> sendFriendRequestByUsername(String rawUsername) async {
    final myId = _myId;
    if (!isAvailable || myId == null) {
      return 'Sign in with Google in Settings first.';
    }
    final username = rawUsername.replaceAll(RegExp(r'\s+'), '');
    if (username.length < 2 || username.length > 12) {
      return 'Enter a valid username (2-12 characters, no spaces).';
    }

    try {
      final res = await _client.rpc(
        'find_player_by_username',
        params: {'p_username': username},
      );
      final matches = List<Map<String, dynamic>>.from(res as List);
      if (matches.isEmpty) {
        return 'No player found with username "$username".';
      }

      final targetId = matches.first['user_id'] as String;
      if (targetId == myId) {
        return 'You cannot add yourself as a friend.';
      }

      final existing = await _client
          .from(_friendshipsTable)
          .select('id, status, requester_id')
          .or(
            'and(requester_id.eq.$myId,addressee_id.eq.$targetId),'
            'and(requester_id.eq.$targetId,addressee_id.eq.$myId)',
          )
          .maybeSingle();

      if (existing != null) {
        final status = existing['status'] as String?;
        if (status == 'accepted') {
          return 'You are already friends with $username!';
        }
        if (existing['requester_id'] == myId) {
          return 'Friend request already sent to $username.';
        }
        return '$username already sent you a request! Check Requests.';
      }

      await _client.from(_friendshipsTable).insert({
        'requester_id': myId,
        'addressee_id': targetId,
        'status': 'pending',
      });
      return null;
    } catch (e) {
      debugPrint('SocialService.sendFriendRequestByUsername error: $e');
      return 'Could not send request. Check Supabase setup.';
    }
  }

  Future<String?> acceptRequest(String friendshipId) async {
    try {
      await _client
          .from(_friendshipsTable)
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', friendshipId);
      return null;
    } catch (e) {
      debugPrint('SocialService.acceptRequest error: $e');
      return 'Failed to accept request.';
    }
  }

  Future<String?> removeFriendship(String friendshipId) async {
    try {
      await _client
          .from(_friendshipsTable)
          .delete()
          .eq('id', friendshipId);
      return null;
    } catch (e) {
      debugPrint('SocialService.removeFriendship error: $e');
      return 'Failed to update friendship.';
    }
  }
}
