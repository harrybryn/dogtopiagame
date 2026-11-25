import 'package:flutter/material.dart';
import '../../models/friend_visit_model.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class SocialDialog extends StatefulWidget {
  final VoidCallback? onVisit;
  final Function(MockFriend friend)? onVisitFriend;

  const SocialDialog({super.key, this.onVisit, this.onVisitFriend});

  @override
  State<SocialDialog> createState() => _SocialDialogState();
}

class _SocialDialogState extends State<SocialDialog> {
  late final List<MockFriend> _friends = MockFriend.allFriends();
  final Set<String> _giftedIds = {};

  String? _toastMessage;

  void _sendGift(String id, String name) {
    setState(() {
      _giftedIds.add(id);
      _toastMessage = 'Sent Kibble & Treat gift to $name! (+100 Coins, +50 XP)';
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility, size: 13, color: Colors.white),
              const SizedBox(width: 4),
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard,
                  size: 13, color: Color(0xFF3B1404)),
              const SizedBox(width: 4),
              Text(
                'SEND GIFT',
                style: TextStyle(
                  color: const Color(0xFF3B1404),
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

  @override
  Widget build(BuildContext context) {
    return GenericModal(
      title: 'COMMUNITY & FRIENDS',
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        children: [
          if (_toastMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF047857),
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
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              itemCount: _friends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final friend = _friends[index];
                final isGifted = _giftedIds.contains(friend.id);
                final canVisitThisFriend = widget.onVisitFriend != null ||
                    (widget.onVisit != null && index == 0);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      // Avatar & Level badge
                      Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                              color: const Color(0xFF381503),
                            ),
                            child: const Center(
                              child: Icon(Icons.pets, color: Colors.amber, size: 22),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: friend.status == 'Online'
                                    ? Colors.green
                                    : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const SizedBox(width: 8, height: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Friend info
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
                              'Level ${friend.level} · ${friend.unlockedIslandCount} Islands · ${friend.favoriteDog}',
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

                      // Actions
                      SizedBox(
                        width: canVisitThisFriend ? 118 : 108,
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
                              _buildGiftButton(
                                friend.id,
                                friend.name,
                              ),
                          ],
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
