import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/login_screen.dart';
import '../screens/credits_paywall_page.dart';
import 'usage_meter.dart';

/// Helpers UX pour éviter de dupliquer la logique "login requis" / "premium requis".
class AccessControl {
  static bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  /// Demande une connexion si l'utilisateur n'est pas connecté.
  /// Retourne true si connecté après l'action.
  static Future<bool> requireLogin(BuildContext context, {String? reason}) async {
    if (isLoggedIn) return true;

    await showLoginBottomSheet(
      context,
      reason: reason ?? "Pour utiliser cette fonctionnalité, connecte-toi (Google ou email).",
    );
    return FirebaseAuth.instance.currentUser != null;
  }

  /// Ouvre le paywall Premium.
  static Future<void> openPaywall(BuildContext context) async {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreditsPaywallPage()),
    );
  }

  /// Vérifie si l'utilisateur peut créer une nouvelle tournée.
  /// - Gratuit : 1 tournée enregistrée + 3 clients max
  /// - Premium : illimité
  /// Ouvre le paywall si nécessaire.
  static Future<bool> requireCreateTour(
    BuildContext context, {
    required int prospectCount,
    String? reason,
  }) async {
    // 1) Login d'abord (car les entitlements sont liés au compte)
    final logged = await requireLogin(context, reason: reason);
    if (!logged) return false;

    final meter = UsageMeter();
    await meter.initIfNeeded();
    await meter.syncFromCloud();

    final premium = await meter.isPremium();
    if (premium) return true;

    final can = await meter.canCreateNewTour(prospectCount);
    if (can) return true;

    await openPaywall(context);
    return false;
  }

  /// Vérifie qu'on peut continuer en gratuit (ex: max 3 prospects).
  /// Retourne true si OK, sinon ouvre le paywall.
  static Future<bool> requireWithinFreeProspectLimit(
    BuildContext context, {
    required int prospectCount,
    String? reason,
  }) async {
    final logged = await requireLogin(context, reason: reason);
    if (!logged) return false;

    final meter = UsageMeter();
    await meter.initIfNeeded();
    await meter.syncFromCloud();

    final premium = await meter.isPremium();
    if (premium) return true;

    final maxFree = meter.maxFreeProspectsPerTour;
    if (prospectCount <= maxFree) return true;

    await openPaywall(context);
    return false;
  }
}
