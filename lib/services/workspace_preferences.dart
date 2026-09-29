import 'package:shared_preferences/shared_preferences.dart';

/// Préférences locales liées au parcours d'entrée et au dernier espace utilisé.
/// Les droits d'accès restent toujours validés côté Firebase.
class WorkspacePreferences {
  static const _onboardingSeenKey = 'workspace_onboarding_seen_v1';
  static const _lastWorkspaceKey = 'last_workspace_type_v1';

  static Future<bool> onboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingSeenKey) ?? false;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
  }

  static Future<String?> lastWorkspace() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastWorkspaceKey);
    if (value == 'personal' || value == 'team') return value;
    return null;
  }

  static Future<void> setLastWorkspace(String type) async {
    if (type != 'personal' && type != 'team') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastWorkspaceKey, type);
    await prefs.setBool(_onboardingSeenKey, true);
  }

  static Future<void> clearSessionChoice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastWorkspaceKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastWorkspaceKey);
    await prefs.remove(_onboardingSeenKey);
  }
}
