import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'usage_meter.dart';
import '../widgets/localized_text.dart';

/// Tracks lightweight engagement counters and triggers an in-app "review" prompt.
/// No paid SDK, uses url_launcher to open Play Store listing.
///
/// Strategy:
/// - Never prompt on first launch.
/// - Prompt after the user has saved at least 1 tour AND opened the app at least 2 times.
/// - Prompt only once (unless you reset the flag).
class EngagementTracker {
  static const String _kLaunchCount = 'eng_launch_count';
  static const String _kToursSavedCount = 'eng_tours_saved_count';
  static const String _kFirstLaunchAt = 'eng_first_launch_at_ms';
  static const String _kReviewPromptShown = 'eng_review_prompt_shown';

  static Future<void> registerAppLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    final first = prefs.getInt(_kFirstLaunchAt);
    if (first == null) {
      await prefs.setInt(_kFirstLaunchAt, now);
    }
    final launches = (prefs.getInt(_kLaunchCount) ?? 0) + 1;
    await prefs.setInt(_kLaunchCount, launches);
  }

  static Future<void> registerTourSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_kToursSavedCount) ?? 0) + 1;
    await prefs.setInt(_kToursSavedCount, n);
  }

  static Future<int> getLaunchCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLaunchCount) ?? 0;
  }

  static Future<int> getToursSavedCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kToursSavedCount) ?? 0;
  }

  static Future<bool> hasShownReviewPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kReviewPromptShown) ?? false;
  }

  static Future<void> _markReviewPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReviewPromptShown, true);
  }

  /// Call this after a "success moment" (e.g., tour saved).
  static Future<void> maybePromptForReview(BuildContext context) async {
    final already = await hasShownReviewPrompt();
    if (already) return;

    final launches = await getLaunchCount();
    final tours = await getToursSavedCount();
    if (tours < 1 || launches < 2) return;

    if (!context.mounted) return;

    // Soft gate: don't prompt if user is currently in the middle of a paywall.
    final meter = UsageMeter();
    await meter.initIfNeeded();
    await meter.syncFromCloud();
    final premium = await meter.isPremium();

    final res = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const LText('Un petit avis ?'),
        content: LText(
          premium
              ? "Merci d'avoir pris Premium 🙌\nÇa t'aide pour préparer tes tournées ?"
              : "Ça t'aide pour préparer ta tournée ?\nTon avis nous aide énormément 🙏",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(0),
            child: const LText('Plus tard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(1),
            child: const LText('Pas vraiment'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(2),
            child: const LText('Oui, super'),
          ),
        ],
      ),
    );

    await _markReviewPromptShown();

    if (res == 2) {
      await _openPlayStoreReview();
    } else if (res == 1) {
      // Optional: open email / form. For now, just thank the user.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LText(
            "Merci ! Dis-nous ce qu'on peut améliorer dans Paramètres > Contact.",
          ),
        ),
      );
    }
  }

  static Future<void> _openPlayStoreReview() async {
    const packageName = 'com.ainego.ai_prospect_gps';
    final marketUri = Uri.parse('market://details?id=$packageName');
    final httpsUri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');

    if (await canLaunchUrl(marketUri)) {
      await launchUrl(marketUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(httpsUri, mode: LaunchMode.externalApplication);
    }
  }
}
