import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config.dart';
import 'admin_test_mode.dart';

class DeveloperPlanOption {
  const DeveloperPlanOption({
    required this.code,
    required this.label,
    required this.maxSeats,
  });

  final String code;
  final String label;
  final int maxSeats;
}

class DeveloperActivationCode {
  const DeveloperActivationCode({
    required this.code,
    required this.plan,
    required this.planLabel,
    required this.maxSeats,
  });

  final String code;
  final String plan;
  final String planLabel;
  final int maxSeats;
}

class DeveloperAccessService {
  DeveloperAccessService({FirebaseFunctions? functions})
      : functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions functions;

  static const plans = <DeveloperPlanOption>[
    DeveloperPlanOption(code: 'ESSENTIAL', label: 'Essentiel', maxSeats: 3),
    DeveloperPlanOption(code: 'TEAM', label: 'Équipe', maxSeats: 10),
    DeveloperPlanOption(code: 'BUSINESS', label: 'Business', maxSeats: 25),
  ];

  Future<bool> isDeveloper({bool forceRefresh = false}) async {
    if (AdminTestMode.enabled) return true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
    final token = await user.getIdTokenResult(forceRefresh);
    return token.claims?['prospectoDeveloper'] == true;
  }

  Future<DeveloperActivationCode> createActivationCode(String plan) async {
    try {
      final result = await functions
          .httpsCallable('createDeveloperActivationCode')
          .call({'appId': kAppId, 'plan': plan});
      final data = Map<String, dynamic>.from(result.data as Map);
      return DeveloperActivationCode(
        code: data['code'].toString(),
        plan: data['plan'].toString(),
        planLabel: data['planLabel'].toString(),
        maxSeats: (data['maxSeats'] as num).toInt(),
      );
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Création du code de test impossible.');
    }
  }

  Future<DeveloperPlanOption> setOrganizationPlan({
    required String orgId,
    required String plan,
  }) async {
    try {
      final result = await functions
          .httpsCallable('setDeveloperOrganizationPlan')
          .call({'appId': kAppId, 'orgId': orgId, 'plan': plan});
      final data = Map<String, dynamic>.from(result.data as Map);
      return DeveloperPlanOption(
        code: data['plan'].toString(),
        label: data['planLabel'].toString(),
        maxSeats: (data['maxSeats'] as num).toInt(),
      );
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Changement du forfait de test impossible.');
    }
  }

  Future<void> deleteOrganization(String orgId) async {
    try {
      await functions.httpsCallable('deleteDeveloperOrganization').call({
        'appId': kAppId,
        'orgId': orgId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Réinitialisation de l’entreprise de test impossible.');
    }
  }
}
