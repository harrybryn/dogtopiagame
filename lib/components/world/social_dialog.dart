import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/friend_visit_model.dart';
import '../../services/audio_service.dart';
import '../../services/social_service.dart';
import '../../state/game_controller.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class SocialDialog extends StatefulWidget {
  final GameController? game;
  final String senderUsername;
  final VoidCallback? onVisit;
  final Function(MockFriend friend)? onVisitFriend;

  const SocialDialog({
    super.key,
    this.game,
    this.senderUsername = 'Keeper',
    this.onVisit,
    this.onVisitFriend,
  });

  @override
  State<SocialDialog> createState() => _SocialDialogState();
}

class _SocialDialogState extends State<SocialDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _giftedIds = {};
  StreamSubscription<void>? _realtimeSub;

  SocialData _data = const SocialData();
  List<PlayerSearchPreview> _searchResults = const [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isBusy = false;
  int _selectedTab = 0; // 0 = Friends, 1 = Requests, 2 = Find Players
  String? _toastMessage;
  bool _toastIsError = false;

  @override
  void initState() {
    super.initState();
    _loadSocial();
    _realtimeSub = SocialService.instance.onSocialChanged.listen((_) {
      _loadSocial(silent: true);
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _toastMessage = message;
      _toastIsError = isError;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _toastMessage == message) {
        setState(() => _toastMessage = null);
      }
    });
  }

  Future<void> _loadSocial({bool silent = false}) async {
    if (!SocialService.instance.isAvailable) {
      if (mounted) {
        setState(() {
          _data = const SocialData();
          _isLoading = false;
        });
      }
      return;
    }

    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final loaded = await SocialService.instance.loadSocialData();
      if (mounted) {
        setState(() {
          _data = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent) {
          _showToast('Failed to sync friends from database.', isError: true);
        }
      }
    }
  }

  Future<void> _handleSearchPlayers() async {
    if (_isSearching) return;
    SoundManager.instance.playClick();
    setState(() {
      _selectedTab = 2;
      _isSearching = true;
    });
    try {
      final results =
          await SocialService.instance.searchPlayers(_searchController.text);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        _showToast(
          'Search failed. Make sure search_players_by_username SQL is added.',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleSendRequest(PlayerSearchPreview player) async {
    if (_isBusy) return;
    SoundManager.instance.playClick();
    setState(() => _isBusy = true);
    final error = await SocialService.instance.sendFriendRequestToUser(
      player.userId,
      player.username,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) {
      _showToast(error, isError: true);
      return;
    }
    _showToast('Friend request sent to ${player.username}!');
    await _loadSocial();
  }

  Future<void> _handleAccept(FriendRequestItem req) async {
    if (_isBusy) return;
    SoundManager.instance.playClick();
    setState(() => _isBusy = true);
    final error = await SocialService.instance.acceptRequest(req.friendshipId);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) {
      _showToast(error, isError: true);
      return;
    }
    _showToast('You and ${req.username} are now friends!');
    await _loadSocial();
  }

  Future<void> _handleRemove(String friendshipId, String successMsg) async {
    if (_isBusy) return;
    SoundManager.instance.playClick();
    setState(() => _isBusy = true);
    final error = await SocialService.instance.removeFriendship(friendshipId);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) {
      _showToast(error, isError: true);
      return;
    }
    _showToast(successMsg);
    await _loadSocial();
  }

  Future<void> _sendGift(String id, String name) async {
    if (_isBusy) return;
    SoundManager.instance.playClick();
    setState(() => _isBusy = true);
    final error = await SocialService.instance.sendGift(
      receiverId: id,
      senderUsername: widget.senderUsername,
    );
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) {
      _showToast(error, isError: true);
      return;
    }
    setState(() {
      _giftedIds.add(id);
    });
    _showToast('Sent +100 Coins & +50 Kibble gift to $name!');
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            maxLength: 12,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\s')),
              LengthLimitingTextInputFormatter(12),
            ],
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _handleSearchPlayers(),
            style: const TextStyle(
              color: Color(0xFF3B1404),
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              hintText: 'Search username (or leave blank to view all)...',
              hintStyle: TextStyle(
                color: const Color(0xFF92400E).withValues(alpha: 0.6),
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFFB45309),
                size: 18,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFD97706), width: 1.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF0F766E), width: 2.0),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        HoverScale(
          scale: 1.05,
          onTap: _isSearching ? null : _handleSearchPlayers,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0F2FE), width: 1.5),
            ),
            child: Text(
              _isSearching ? '...' : 'SEARCH',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final incomingCount = _data.incomingRequests.length;
    return Row(
      children: [
        Expanded(
          child: _buildTabButton(
            label: 'FRIENDS (${_data.friends.length})',
            selected: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildTabButton(
            label: 'REQUESTS',
            badgeCount: incomingCount,
            selected: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildTabButton(
            label: 'FIND PLAYERS',
            selected: _selectedTab == 2,
            onTap: () {
              if (_selectedTab != 2 && _searchResults.isEmpty) {
                _handleSearchPlayers();
              } else {
                setState(() => _selectedTab = 2);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return HoverScale(
      scale: 1.02,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                )
              : null,
          color: selected ? null : const Color(0x3378350F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFFFEF3C7)
                : const Color(0x66D97706),
            width: 1.5,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF78350F),
                  fontFamily: 'Lilita One',
                  fontSize: 11.5,
                  letterSpacing: 0.4,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lilita One',
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisitButton(MockFriend friend) {
    return HoverScale(
      scale: 1.06,
      onTap: () {
        if (widget.onVisitFriend != null) {
          widget.onVisitFriend!(friend);
        } else {
          widget.onVisit?.call();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF22C55E), Color(0xFF15803D)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility, size: 13, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'VISIT ISLAND',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Lilita One',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiftSentButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF9CA3AF)),
      ),
      child: const Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'GIFT SENT',
            style: TextStyle(
              color: Color(0xFF4B5563),
              fontFamily: 'Lilita One',
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar({
    required String username,
    String? avatarUrl,
    double size = 40,
    bool? isOnline,
  }) {
    final initial = username.trim().isNotEmpty
        ? username.trim()[0].toUpperCase()
        : 'K';
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFFFEF08A),
          fontFamily: 'Lilita One',
          fontSize: 17,
        ),
      ),
    );

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
            color: const Color(0xFF381503),
          ),
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                  ),
                )
              : fallback,
        ),
        if (isOnline != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGiftButton(String id, String name) {
    return HoverScale(
      scale: 1.06,
      onTap: () => _sendGift(id, name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFEF3C7)),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.card_giftcard, size: 13, color: Color(0xFF3B1404)),
              SizedBox(width: 4),
              Text(
                'SEND GIFT',
                style: TextStyle(
                  color: Color(0xFF3B1404),
                  fontFamily: 'Lilita One',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_data.friends.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No friends yet!\nUse Search or Find Players to preview players and send a friend request.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF78350F),
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      itemCount: _data.friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final entry = _data.friends[index];
        final friend = entry.friend;
        final isGifted = _giftedIds.contains(friend.id);
        final canVisitThisFriend =
            widget.onVisitFriend != null || widget.onVisit != null;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD97706), width: 1.8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2078350F),
                offset: Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              _buildPlayerAvatar(
                username: friend.name,
                avatarUrl: friend.avatarUrl,
                isOnline: friend.status == 'Online',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      friend.name,
                      style: const TextStyle(
                        color: Color(0xFF3B1404),
                        fontFamily: 'Lilita One',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Level ${friend.level} · ${friend.dogs.length} Dogs · ${friend.habitats.length} Buildings',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontFamily: 'Fredoka',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: canVisitThisFriend ? 114 : 104,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canVisitThisFriend) ...[
                      _buildVisitButton(friend),
                      const SizedBox(height: 4),
                    ],
                    if (isGifted)
                      _buildGiftSentButton()
                    else
                      _buildGiftButton(friend.id, friend.name),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Remove friend',
                icon: const Icon(Icons.person_remove_rounded,
                    color: Color(0xFFB91C1C), size: 18),
                onPressed: _isBusy
                    ? null
                    : () => _handleRemove(
                          entry.friendshipId,
                          'Removed ${friend.name} from friends.',
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestsList() {
    final incoming = _data.incomingRequests;
    final outgoing = _data.outgoingRequests;

    if (incoming.isEmpty && outgoing.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No pending friend requests.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF78350F),
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }

    final all = [...incoming, ...outgoing];
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      itemCount: all.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final req = all[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD97706), width: 1.8),
          ),
          child: Row(
            children: [
              _buildPlayerAvatar(
                username: req.username,
                avatarUrl: req.avatarUrl,
                size: 38,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      req.username,
                      style: const TextStyle(
                        color: Color(0xFF3B1404),
                        fontFamily: 'Lilita One',
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      req.isIncoming
                          ? 'Level ${req.level} · Wants to be friends'
                          : 'Level ${req.level} · Request pending',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontFamily: 'Fredoka',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (req.isIncoming) ...[
                HoverScale(
                  scale: 1.05,
                  onTap: _isBusy ? null : () => _handleAccept(req),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Text(
                      'ACCEPT',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                HoverScale(
                  scale: 1.05,
                  onTap: _isBusy
                      ? null
                      : () => _handleRemove(
                            req.friendshipId,
                            'Declined request from ${req.username}.',
                          ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF87171)),
                    ),
                    child: const Text(
                      'DECLINE',
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontFamily: 'Lilita One',
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ),
              ] else
                HoverScale(
                  scale: 1.05,
                  onTap: _isBusy
                      ? null
                      : () => _handleRemove(
                            req.friendshipId,
                            'Cancelled request to ${req.username}.',
                          ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF9CA3AF)),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Color(0xFF374151),
                        fontFamily: 'Lilita One',
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD97706)),
      );
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No matching players found.\nTry another username or search with an empty box to view all players.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF78350F),
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }

    final friendById = {
      for (final f in _data.friends) f.friend.id: f,
    };
    final incomingById = {
      for (final r in _data.incomingRequests) r.userId: r,
    };
    final outgoingIds = {
      for (final r in _data.outgoingRequests) r.userId,
    };

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final player = _searchResults[index];
        final existingFriend = friendById[player.userId];
        final incomingReq = incomingById[player.userId];
        final isOutgoing = outgoingIds.contains(player.userId);
        final isRecent = player.updatedAt != null &&
            DateTime.now().difference(player.updatedAt!).inMinutes < 5;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD97706), width: 1.8),
          ),
          child: Row(
            children: [
              _buildPlayerAvatar(
                username: player.username,
                avatarUrl: player.avatarUrl,
                isOnline: isRecent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.username,
                      style: const TextStyle(
                        color: Color(0xFF3B1404),
                        fontFamily: 'Lilita One',
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      'Level ${player.level} · ${player.buildingsCount} Buildings · ${isRecent ? 'Online' : 'Keeper'}',
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontFamily: 'Fredoka',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (existingFriend != null)
                _buildVisitButton(existingFriend.friend)
              else if (incomingReq != null)
                HoverScale(
                  scale: 1.05,
                  onTap: _isBusy ? null : () => _handleAccept(incomingReq),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Text(
                      'ACCEPT',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                )
              else if (isOutgoing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF9CA3AF)),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Color(0xFF4B5563),
                      fontFamily: 'Lilita One',
                      fontSize: 10.5,
                    ),
                  ),
                )
              else
                HoverScale(
                  scale: 1.05,
                  onTap: _isBusy ? null : () => _handleSendRequest(player),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFEF3C7)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded,
                            size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'ADD FRIEND',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Lilita One',
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleClaimGift(GiftInboxItem gift) async {
    final game = widget.game;
    if (_isBusy || game == null || gift.claimed) return;
    SoundManager.instance.playQuestReward();
    setState(() => _isBusy = true);
    final err = await SocialService.instance.claimGift(game, gift);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (err != null) {
      _showToast(err, isError: true);
      return;
    }
    _showToast(
      'Claimed +${gift.coins} Coins & +${gift.kibble} Kibble from ${gift.senderUsername}!',
    );
    await _loadSocial(silent: true);
  }

  Future<void> _handleClaimAllGifts() async {
    final game = widget.game;
    if (_isBusy || game == null) return;
    SoundManager.instance.playQuestReward();
    setState(() => _isBusy = true);
    final count =
        await SocialService.instance.claimAllGifts(game, _data.inboxGifts);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (count > 0) {
      _showToast('Claimed $count gift${count > 1 ? 's' : ''}!');
    }
    await _loadSocial(silent: true);
  }

  Widget _buildInboxList() {
    final gifts = _data.inboxGifts;
    if (gifts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Your gift inbox is empty.\nGifts sent by friends will appear here in real time!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF78350F),
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      );
    }

    final hasUnclaimed = gifts.any((g) => !g.claimed);
    final avatarBySenderId = {
      for (final f in _data.friends) f.friend.id: f.friend.avatarUrl,
    };

    return Column(
      children: [
        if (hasUnclaimed && widget.game != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: HoverScale(
                scale: 1.04,
                onTap: _isBusy ? null : _handleClaimAllGifts,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFEF3C7)),
                  ),
                  child: const Text(
                    'CLAIM ALL GIFTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lilita One',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            itemCount: gifts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final gift = gifts[index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFFFBF2),
                      Color(0xFFFAECD5),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: gift.claimed
                        ? const Color(0xFFD6D3D1)
                        : const Color(0xFFD97706),
                    width: 1.8,
                  ),
                ),
                child: Row(
                  children: [
                    _buildPlayerAvatar(
                      username: gift.senderUsername,
                      avatarUrl: avatarBySenderId[gift.senderId],
                      size: 38,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Gift from ${gift.senderUsername}',
                            style: const TextStyle(
                              color: Color(0xFF3B1404),
                              fontFamily: 'Lilita One',
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            '+${gift.coins} Paw Coins · +${gift.kibble} Kibble',
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontFamily: 'Fredoka',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (gift.claimed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF9CA3AF)),
                        ),
                        child: const Text(
                          'CLAIMED',
                          style: TextStyle(
                            color: Color(0xFF4B5563),
                            fontFamily: 'Lilita One',
                            fontSize: 10.5,
                          ),
                        ),
                      )
                    else
                      HoverScale(
                        scale: 1.05,
                        onTap: _isBusy || widget.game == null
                            ? null
                            : () => _handleClaimGift(gift),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFEF3C7)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.card_giftcard_rounded,
                                  size: 13, color: Color(0xFF3B1404)),
                              SizedBox(width: 4),
                              Text(
                                'CLAIM',
                                style: TextStyle(
                                  color: Color(0xFF3B1404),
                                  fontFamily: 'Lilita One',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = SocialService.instance.isAvailable;

    return GenericModal(
      title: 'COMMUNITY & FRIENDS',
      titleExtra: isSignedIn
          ? HoverScale(
              scale: 1.08,
              onTap: _isLoading ? null : _loadSocial,
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF3B1404),
                size: 20,
              ),
            )
          : null,
      onClose: () => Navigator.of(context).pop(),
      child: !isSignedIn
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        color: Color(0xFFB45309), size: 40),
                    SizedBox(height: 10),
                    Text(
                      'Sign in with Google in Settings to search players, add friends, and visit their islands!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF3B1404),
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_toastMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _toastIsError
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF047857),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _toastMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Fredoka',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                _buildSearchBar(),
                const SizedBox(height: 8),
                _buildTabBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFD97706),
                          ),
                        )
                      : (_selectedTab == 0
                          ? _buildFriendsList()
                          : _selectedTab == 1
                              ? _buildRequestsList()
                              : _buildSearchResultsList()),
                ),
              ],
            ),
    );
  }
}
