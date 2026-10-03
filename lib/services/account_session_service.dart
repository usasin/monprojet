import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'ad_service.dart';
import 'reminder_service.dart';
import 'workspace_preferences.dart';
import 'workspace_scope.dart';

/// Centralise la fin de session pour éviter qu'un appareil conserve des
/// données de contexte appartenant au compte précédent.
class AccountSessionService {
  AccountSessionService._();

  static Future<void> signOut({
    bool forceAccountPicker = false,
    bool clearOnboarding = false,
  }) async {
    // Retire le token FCM du compte qui quitte la session afin que ce téléphone
    // ne reçoive plus ses rappels / notifications après un changement de compte.
    await ReminderService.instance.unregisterCurrentDevice();

    if (!kIsWeb) {
      try {
        final google = GoogleSignIn();
        // signOut opens the account picker while preserving the granted consent.
        // disconnect is for explicit withdrawal, never a routine account switch.
        await google.signOut();
      } catch (_) {}
    }

    await FirebaseAuth.instance.signOut();
    if (clearOnboarding) {
      await WorkspacePreferences.clearAll();
    } else {
      await WorkspacePreferences.clearSessionChoice();
    }
    WorkspaceScope.invalidate();
    AdService.instance.resetAccountCache();
  }
}
