import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../../services/cloud_save_service.dart';
import '../../state/game_controller.dart';

/// Prompts the user when they try to "Connect with Google" using a Gmail
/// that already has an existing Dogtopia save in `player_saves`.
///
/// Returns `true` if the user chose to log in to the existing account,
/// or `false` if they cancelled (keeping their current local island).
Future<bool> showExistingGoogleAccountDialog(
  BuildContext context,
  GameController game,
  ExistingCloudAccount account,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2A1205),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFFBBF24), width: 2.2),
      ),
      title: const Row(
        children: [
          Icon(Icons.account_circle_rounded,
              color: Color(0xFFFEF08A), size: 26),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'GOOGLE ACCOUNT ALREADY IN USE',
              style: TextStyle(
                color: Color(0xFFFEF08A),
                fontFamily: 'Lilita One',
                fontSize: 16.5,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${account.email} is already connected to an existing Dogtopia account:',
            style: const TextStyle(
              color: Color(0xFFFEF3C7),
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF3E1805),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x99FBBF24), width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.username,
                  style: const TextStyle(
                    color: Color(0xFFFEF08A),
                    fontFamily: 'Lilita One',
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Level ${account.level} · ${account.coins} Coins',
                  style: const TextStyle(
                    color: Color(0xFF67E8F9),
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Do you want to log in to this account? Your current local guest progress on this device will be replaced.',
            style: TextStyle(
              color: Color(0xCCFEF3C7),
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            SoundManager.instance.playClick();
            Navigator.pop(ctx, false);
          },
          child: const Text(
            'CANCEL',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Lilita One',
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            SoundManager.instance.playClick();
            Navigator.pop(ctx, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'YES, LOG IN',
            style: TextStyle(
              fontFamily: 'Lilita One',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );

  if (result == true) {
    await CloudSaveService.instance.confirmLoadExistingAccount(game);
    return true;
  } else {
    await CloudSaveService.instance.cancelExistingAccountSignIn();
    return false;
  }
}

/// Prompts the user when they sign in via "Already have an account?" using a
/// Google account that has no saved cloud progress yet, asking whether to
/// bind/connect the current game to that account.
Future<bool> showBindEmptyGoogleAccountDialog(
  BuildContext context,
  GameController game,
  String email,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2A1205),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFFBBF24), width: 2.2),
      ),
      title: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Color(0xFFFDE047), size: 25),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'NO SAVED PROGRESS FOUND',
              style: TextStyle(
                color: Color(0xFFFEF08A),
                fontFamily: 'Lilita One',
                fontSize: 16.5,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        '$email does not have any saved Dogtopia progress in the cloud yet.\n\nDo you want to bind/connect your current game to this Google account?',
        style: const TextStyle(
          color: Color(0xFFFEF3C7),
          fontFamily: 'Fredoka',
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            SoundManager.instance.playClick();
            Navigator.pop(ctx, false);
          },
          child: const Text(
            'CANCEL',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Lilita One',
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            SoundManager.instance.playClick();
            Navigator.pop(ctx, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'YES, CONNECT',
            style: TextStyle(
              fontFamily: 'Lilita One',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );

  if (result == true) {
    if (game.hasUsername) {
      await CloudSaveService.instance.saveNow(game);
    }
    return true;
  } else {
    await CloudSaveService.instance.discardUnlinkedAuthUser();
    return false;
  }
}

/// Notifies the user when they switch to a Google account that has no saved
/// cloud progress yet, and removes the unlinked auth user record.
Future<void> showNoCloudAccountDialog(
  BuildContext context,
  String email,
) async {
  await CloudSaveService.instance.discardUnlinkedAuthUser();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2A1205),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFFBBF24), width: 2.2),
      ),
      title: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: Color(0xFFFCA5A5), size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'NO CLOUD ACCOUNT FOUND',
              style: TextStyle(
                color: Color(0xFFFEF08A),
                fontFamily: 'Lilita One',
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        '$email does not have an existing Dogtopia account saved in the cloud yet.\n\nTry switching to a Google account that already has a saved island.',
        style: const TextStyle(
          color: Color(0xFFFEF3C7),
          fontFamily: 'Fredoka',
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () {
            SoundManager.instance.playClick();
            Navigator.pop(ctx);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: const Color(0xFF3B1404),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'GOT IT',
            style: TextStyle(
              fontFamily: 'Lilita One',
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}
