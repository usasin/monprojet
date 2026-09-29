/// Mode administrateur local réservé aux builds de test.
///
/// Activation : --dart-define=ADMIN_TEST_MODE=true
/// Le build Play Store force explicitement cette valeur à false.
/// Ce mode ne modifie aucun droit côté serveur : les opérations entreprise
/// sensibles restent protégées par la custom claim Firebase prospectoDeveloper.
class AdminTestMode {
  const AdminTestMode._();

  static const bool enabled = bool.fromEnvironment(
    'ADMIN_TEST_MODE',
    defaultValue: false,
  );

  static const String label = 'ADMIN TEST';
}
