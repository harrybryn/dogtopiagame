import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../../services/social_service.dart';
import '../../state/game_controller.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class InboxDialog extends StatefulWidget {
  final GameController game;

  const InboxDialog({super.key, required this.game});

  @override
  State<InboxDialog> createState() => _InboxDialogState();
}

class _InboxDialogState extends State<InboxDialog> {
  StreamSubscription<void>? _realtimeSub;
  List<GiftInboxItem> _gifts = const [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _toastMessage;
  bool _toastIsError = false;

  @override
  void initState() {
    super.initState();
    _loadGifts();
    _realtimeSub = SocialService.instance.onSocialChanged.listen((_) {
      _loadGifts(silent: true);
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
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

  Future<void> _loadGifts({bool silent = false}) async {
    if (!SocialService.instance.isAvailable) {
      if (mounted) {
        setState(() {
          _gifts = const [];
          _isLoading = false;
        });
      }
      return;
    }

    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final loaded = await SocialService.instance.loadInboxGiftsWithAvatars();
      if (mounted) {
        setState(() {
          _gifts = loaded;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!silent) {
          _showToast('Failed to load gift inbox.', isError: true);
        }
      }
    }
  }

  Future<void> _handleClaimGift(GiftInboxItem gift) async {
    if (_isBusy || gift.claimed) return;
    SoundManager.instance.playQuestReward();
    setState(() => _isBusy = true);
    final err = await SocialService.instance.claimGift(widget.game, gift);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (err != null) {
      _showToast(err, isError: true);
      return;
    }
    _showToast(
      'Claimed +${gift.coins} Paw Coins & +${gift.kibble} Kibble!',
    );
    await _loadGifts(silent: true);
  }

  Future<void> _handleClaimAll() async {
    if (_isBusy) return;
    SoundManager.instance.playQuestReward();
    setState(() => _isBusy = true);
    final count =
        await SocialService.instance.claimAllGifts(widget.game, _gifts);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (count > 0) {
      _showToast('Claimed $count gift${count > 1 ? 's' : ''}!');
    }
    await _loadGifts(silent: true);
  }

  Widget _buildAvatar(String username, String? avatarUrl) {
    final initial =
        username.trim().isNotEmpty ? username.trim()[0].toUpperCase() : 'K';
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFFFEF08A),
          fontFamily: 'Lilita One',
          fontSize: 16,
        ),
      ),
    );
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
        color: const Color(0xFF381503),
      ),
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                avatarUrl,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            )
          : fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = SocialService.instance.isAvailable;
    final hasUnclaimed = _gifts.any((g) => !g.claimed);

    return GenericModal(
      title: 'GIFT INBOX',
      titleExtra: isSignedIn
          ? HoverScale(
              scale: 1.08,
              onTap: _isLoading ? null : _loadGifts,
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF3B1404),
                size: 20,
              ),
            )
          : null,
      onClose: () => Navigator.of(context).pop(),
      child: Column(
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
                if (hasUnclaimed && !_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_gifts.where((g) => !g.claimed).length} unclaimed gift(s)',
                          style: const TextStyle(
                            color: Color(0xFF78350F),
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        HoverScale(
                          scale: 1.04,
                          onTap: _isBusy ? null : _handleClaimAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFFEF3C7)),
                            ),
                            child: const Text(
                              'CLAIM ALL',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Lilita One',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFD97706),
                          ),
                        )
                      : _gifts.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Your gift inbox is empty.\nGifts sent by friends will appear here!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF78350F),
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 2, horizontal: 2),
                              itemCount: _gifts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final gift = _gifts[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
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
                                      _buildAvatar(
                                        gift.senderUsername,
                                        gift.senderAvatarUrl,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: const Color(0xFF9CA3AF)),
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
                                          onTap: _isBusy
                                              ? null
                                              : () => _handleClaimGift(gift),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 7),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFFBBF24),
                                                  Color(0xFFD97706),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFFEF3C7)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.card_giftcard_rounded,
                                                    size: 13,
                                                    color: Color(0xFF3B1404)),
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
            ),
    );
  }
}
