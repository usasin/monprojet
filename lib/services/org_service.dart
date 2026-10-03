import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ActivationPlan {
  final String code;
  final String label;
  final int maxSeats;

  const ActivationPlan({
    required this.code,
    required this.label,
    required this.maxSeats,
  });
}

class OrgService {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseFunctions functions;
  final String appId;

  OrgService(this.appId, {FirebaseFunctions? functions})
    : functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  DocumentReference<Map<String, dynamic>> orgRef(String orgId) =>
      db.collection('apps').doc(appId).collection('orgs').doc(orgId);

  Future<ActivationPlan> precheckActivationCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) throw 'Code requis';
    try {
      final result = await functions
          .httpsCallable('precheckActivationCode')
          .call({'appId': appId, 'code': code});
      final data = Map<String, dynamic>.from(result.data as Map);
      return ActivationPlan(
        code: (data['plan'] ?? 'STANDARD').toString(),
        label: (data['planLabel'] ?? data['plan'] ?? 'Standard').toString(),
        maxSeats: (data['maxSeats'] as num?)?.toInt() ?? 5,
      );
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Code d’activation invalide';
    }
  }

  Future<Map<String, String>> createOrgWithActivation({
    required String name,
    required String activationCode,
  }) async {
    try {
      final result = await functions
          .httpsCallable('createOrgWithActivation')
          .call({
            'appId': appId,
            'name': name.trim(),
            'activationCode': activationCode.trim().toUpperCase(),
          });
      final data = Map<String, dynamic>.from(result.data as Map);
      return {
        'orgId': data['orgId'].toString(),
        'orgName': data['orgName'].toString(),
        'role': data['role'].toString(),
      };
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Création de l’organisation impossible';
    }
  }

  Future<String> createInvite({
    required String orgId,
    String role = 'REP',
    required String email,
    required String firstName,
    required String lastName,
    String? managerUid,
    String? requesterUid,
    String? requesterEmail,
  }) async {
    try {
      final result = await functions.httpsCallable('createOrgInvite').call({
        'appId': appId,
        'orgId': orgId,
        'role': role,
        'email': email.trim(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'managerUid': managerUid ?? '',
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return data['code'].toString();
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Invitation impossible';
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> invites(String orgId) {
    return orgRef(orgId)
        .collection('invites')
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> revokeInvite(String orgId, String code) async {
    try {
      await functions.httpsCallable('revokeOrgInvite').call({
        'appId': appId,
        'orgId': orgId,
        'code': code.trim().toUpperCase(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Révocation de l’invitation impossible';
    }
  }

  Future<void> requestResend({
    required String code,
    String? requesterUid,
    String? requesterEmail,
  }) async {
    await db
        .collection('apps')
        .doc(appId)
        .collection('inviteResendRequests')
        .add({
          'code': code.trim().toUpperCase(),
          'createdAt': FieldValue.serverTimestamp(),
          if (requesterUid != null) 'requesterUid': requesterUid,
          if (requesterEmail != null) 'requesterEmail': requesterEmail,
        });
  }

  Future<Map<String, String>> acceptInvite({required String code}) async {
    try {
      final result = await functions.httpsCallable('acceptOrgInvite').call({
        'appId': appId,
        'code': code.trim().toUpperCase(),
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return {
        'orgId': data['orgId'].toString(),
        'orgName': data['orgName'].toString(),
        'role': data['role'].toString(),
      };
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Invitation invalide';
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> members(String orgId) =>
      orgRef(orgId)
          .collection('members')
          .where('status', isEqualTo: 'active')
          .snapshots();

  Future<void> removeMember(String orgId, String uid) async {
    try {
      await functions.httpsCallable('removeOrgMember').call({
        'appId': appId,
        'orgId': orgId,
        'memberUid': uid,
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Suppression du membre impossible';
    }
  }

  Future<void> updateMemberRole({
    required String orgId,
    required String memberUid,
    required String role,
  }) async {
    try {
      await functions.httpsCallable('updateOrgMemberRole').call({
        'appId': appId,
        'orgId': orgId,
        'memberUid': memberUid,
        'role': role.toUpperCase(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Modification du rôle impossible';
    }
  }

  Future<void> transferOwnership({
    required String orgId,
    required String memberUid,
  }) async {
    try {
      await functions.httpsCallable('transferOrgOwnership').call({
        'appId': appId,
        'orgId': orgId,
        'memberUid': memberUid,
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Transfert de propriété impossible';
    }
  }

  Future<void> leaveOrganization(String orgId) async {
    try {
      await functions.httpsCallable('leaveOrganization').call({
        'appId': appId,
        'orgId': orgId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Impossible de quitter l’entreprise';
    }
  }

  Future<void> deleteAccount() async {
    try {
      await functions.httpsCallable('deleteProspectoAccount').call({
        'appId': appId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Suppression du compte impossible';
    }
  }

  Future<void> updateOrganizationProfile({
    required String orgId,
    required String name,
    String? slogan,
    String? logoUrl,
    String? companyEmail,
    String? companyPhone,
    String? website,
  }) async {
    try {
      await functions.httpsCallable('updateOrgProfile').call({
        'appId': appId,
        'orgId': orgId,
        'name': name.trim(),
        'slogan': slogan?.trim() ?? '',
        'logoUrl': logoUrl?.trim() ?? '',
        'companyEmail': companyEmail?.trim() ?? '',
        'companyPhone': companyPhone?.trim() ?? '',
        'website': website?.trim() ?? '',
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Modification de l’entreprise impossible';
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> activity(String orgId) =>
      orgRef(orgId)
          .collection('activity')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> allMembers(
    String orgId, {
    String? role,
    String? uid,
  }) {
    Query<Map<String, dynamic>> query = orgRef(orgId).collection('members');
    if (role == 'MANAGER')
      query = query
          .where('managerUid', isEqualTo: uid)
          .where('role', isEqualTo: 'REP');
    if (role == 'REP')
      query = query.where(FieldPath.documentId, isEqualTo: uid);
    return query.snapshots();
  }

  Future<void> assignMemberManager({
    required String orgId,
    required String memberUid,
    required String managerUid,
  }) async {
    await functions.httpsCallable('assignMemberManager').call({
      'appId': appId,
      'orgId': orgId,
      'memberUid': memberUid,
      'managerUid': managerUid,
    });
  }

  Future<Map<String, dynamic>> previewInvite(String code) async {
    try {
      final result = await functions.httpsCallable('previewOrgInvite').call({
        'appId': appId,
        'code': code.trim().toUpperCase(),
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Invitation invalide';
    }
  }

  Future<void> setMemberRouteAutonomy({
    required String orgId,
    required String memberUid,
    required bool enabled,
  }) async {
    try {
      await functions.httpsCallable('setMemberRouteAutonomy').call({
        'appId': appId,
        'orgId': orgId,
        'memberUid': memberUid,
        'enabled': enabled,
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Modification de l’autonomie impossible';
    }
  }

  Future<void> assignMemberPlan({
    required String orgId,
    required String memberUid,
    required DateTime date,
    required List<String> prospectIds,
    String notes = '',
    bool replaceExisting = false,
  }) async {
    try {
      final dateId =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      await functions.httpsCallable('assignMemberPlan').call({
        'appId': appId,
        'orgId': orgId,
        'memberUid': memberUid,
        'date': dateId,
        'prospectIds': prospectIds,
        'notes': notes.trim(),
        'replaceExisting': replaceExisting,
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Attribution de la tournée impossible';
    }
  }

  Future<void> upsertMemberAppointment({
    required String orgId,
    required String memberUid,
    required String title,
    required DateTime startsAt,
    int durationMinutes = 60,
    String? appointmentId,
    String? prospectId,
    String address = '',
    String notes = '',
    bool forceConflict = false,
  }) async {
    try {
      await functions.httpsCallable('upsertMemberAppointment').call({
        'appId': appId,
        'orgId': orgId,
        'memberUid': memberUid,
        'title': title.trim(),
        'startsAt': startsAt.toUtc().toIso8601String(),
        'durationMinutes': durationMinutes,
        if (appointmentId != null && appointmentId.isNotEmpty)
          'appointmentId': appointmentId,
        if (prospectId != null && prospectId.isNotEmpty)
          'prospectId': prospectId,
        'address': address.trim(),
        'notes': notes.trim(),
        'forceConflict': forceConflict,
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Ajout du rendez-vous impossible';
    }
  }

  Future<void> cancelMemberAppointment({
    required String orgId,
    required String memberUid,
    required String appointmentId,
  }) async {
    try {
      await functions.httpsCallable('cancelMemberAppointment').call({
        'appId': appId,
        'orgId': orgId,
        'memberUid': memberUid,
        'appointmentId': appointmentId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Annulation du rendez-vous impossible';
    }
  }

  CollectionReference<Map<String, dynamic>> memberPlans(
    String orgId,
    String memberUid,
  ) =>
      orgRef(orgId).collection('memberData').doc(memberUid).collection('plans');

  CollectionReference<Map<String, dynamic>> memberAppointments(
    String orgId,
    String memberUid,
  ) =>
      orgRef(orgId)
          .collection('memberData')
          .doc(memberUid)
          .collection('appointments');

  Future<void> requestActivationResend({required String email}) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) throw 'Renseignez votre adresse e-mail';
    try {
      await functions.httpsCallable('resendStripeActivationCode').call({
        'email': normalized,
      });
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Renvoi du code impossible';
    }
  }
}
