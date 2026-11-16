import 'package:flutter/material.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class SocialDialog extends StatefulWidget {
  final VoidCallback? onVisit;

  const SocialDialog({super.key, this.onVisit});

  @override
  State<SocialDialog> createState() => _SocialDialogState();
}

class _SocialDialogState extends State<SocialDialog> {
  final List<Map<String, dynamic>> _friends = [
    {
      'id': 1,
      'name': 'CanineKing_Alex',
      'level': 24,
      'dog': 'Galaxy Dog',
      'status': 'Online',
      'gifted': false,
    },
    {
      'id': 2,
      'name': 'PupWhisperer_Mia',
      'level': 19,
      'dog': 'Cerberus Pup',
      'status': 'Visiting Park',
      'gifted': false,
    },
    {
      'id': 3,
      'name': 'DesertWolf_Zack',
      'level': 15,
      'dog': 'Pharaoh Hound',
      'status': 'Offline',
      'gifted': false,
    },
    {
      'id': 4,
      'name': 'IslandPaws_Leo',
      'level': 11,
      'dog': 'Golden Retriever',
      'status': 'Online',
      'gifted': false,
    },
  ];

  String? _toastMessage;

  void _sendGift(int id, String name) {
    setState(() {
      for (var f in _friends) {
        if (f['id'] == id) {
          f['gifted'] = true;
        }
      }
      _toastMessage = 'Sent Kibble & Treat gift to $name! (+100 Coins, +50 XP)';
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
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
                final isGifted = friend['gifted'] as bool;

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
                                color: friend['status'] == 'Online'
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
                              friend['name'] as String,
                              style: const TextStyle(
                                color: Color(0xFF3B1404),
                                fontFamily: 'Lilita One',
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'Level ${friend['level']} · ${friend['dog']}',
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

                      // Action Button
                      if (isGifted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF9CA3AF)),
                          ),
                          child: const Text(
                            'GIFT SENT',
                            style: TextStyle(
                              color: Color(0xFF4B5563),
                              fontFamily: 'Lilita One',
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      else
                        HoverScale(
                          scale: 1.08,
                          onTap: () => _sendGift(friend['id'] as int, friend['name'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFEF3C7)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.card_giftcard, size: 14, color: Color(0xFF3B1404)),
                                SizedBox(width: 4),
                                Text(
                                  'SEND GIFT',
                                  style: TextStyle(
                                    color: Color(0xFF3B1404),
                                    fontFamily: 'Lilita One',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
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
