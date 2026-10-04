// Demonstration data for automated captures only; this file is not imported by lib/main.dart.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:ai_prospect_gps/providers/org_provider.dart';
import 'package:ai_prospect_gps/sales/enterprise_repository.dart';
import 'package:ai_prospect_gps/sales/enterprise_snapshot.dart';
import 'package:ai_prospect_gps/sales/sales_model.dart';
import 'package:ai_prospect_gps/models/prospect.dart';

final captureNow = DateTime(2026, 10, 3, 12);

class CaptureUser implements User {
  @override
  String get uid => 'capture-owner';
  @override
  String? get email => 'demo@example.com';
  @override
  String? get displayName => 'Démonstration';
  @override
  bool get isAnonymous => false;
  @override
  String? get photoURL => null;
  @override
  bool get emailVerified => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CaptureAuth implements FirebaseAuth {
  @override
  User? get currentUser => CaptureUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CaptureOrganization extends OrgProvider {
  @override
  String? get orgId => 'capture-company';
  @override
  String? get orgName => 'Équipe Horizon';
  @override
  String? get role => 'OWNER';
  @override
  bool get isTeam => true;
  @override
  bool get canManageTeam => true;
  @override
  bool get isOwner => true;
  @override
  String get roleLabel => 'Administrateur';
  @override
  String get initials => 'EH';
}

EnterpriseSnapshot captureSnapshot() {
  const names = [
    'Atelier Horizon',
    'Distribution Provence',
    'Équipements du Sud',
    'Fournitures Méditerranée',
    'Négoce des Collines',
    'Solutions Habitat',
  ];
  return EnterpriseSnapshot(
    readAt: captureNow,
    members: const [
      EnterpriseMember('owner', 'Camille', 'OWNER', '', true),
      EnterpriseMember('manager', 'Équipe Provence', 'MANAGER', '', true),
      EnterpriseMember('rep1', 'Alex Martin', 'REP', 'manager', true),
      EnterpriseMember('rep2', 'Lina Bernard', 'REP', 'manager', true),
    ],
    prospects: [
      for (var i = 0; i < names.length; i++)
        EnterpriseProspect(
          Prospect(
            id: 'p$i',
            name: names[i],
            address: 'Marseille',
            category: 'B2B',
            lat: 43.3,
            lng: 5.37,
          ),
          captureNow.subtract(Duration(days: i)),
          i.isEven ? 'rep1' : 'rep2',
        ),
    ],
    deals: [
      for (var i = 0; i < 4; i++)
        SalesDeal(
          id: 'd$i',
          ownerUid: i.isEven ? 'rep1' : 'rep2',
          ownerName: i.isEven ? 'Alex Martin' : 'Lina Bernard',
          prospectId: 'p$i',
          prospectName: names[i],
          title: [
            'Renouvellement fournitures',
            'Équipement atelier',
            'Contrat annuel',
            'Réassort matériel',
          ][i],
          stage: i == 2 ? 'won' : 'qualified',
          interest: i == 0 ? 'hot' : 'warm',
          amountCents: (i + 1) * 125000,
          closedAt: i == 2 ? captureNow : null,
          nextAction: i == 1 ? 'followup' : '',
          nextActionAt: i == 1 ? captureNow.add(const Duration(days: 1)) : null,
          updatedAt: captureNow,
        ),
    ],
    plans: [
      EnterpriseRecord('tour1', 'rep1', {
        'date': captureNow,
        'prospectIds': ['p0', 'p2', 'p4'],
        'reports': {
          'p0': {'status': 'présent'},
          'p2': {'status': 'présent'},
        },
      }),
      EnterpriseRecord('tour2', 'rep2', {
        'date': captureNow,
        'prospectIds': ['p1', 'p3', 'p5'],
        'reports': {
          'p1': {'status': 'présent'},
        },
      }),
    ],
    appointments: [
      EnterpriseRecord('rdv1', 'rep1', {
        'startsAt': captureNow,
        'title': 'Présentation de l’offre',
      }),
    ],
    invites: [],
  );
}

class CaptureRepository extends EnterpriseRepository {
  CaptureRepository()
    : super(
        'capture-company',
        firestore: FakeFirebaseFirestore(),
        auth: CaptureAuth(),
      );
  @override
  Future<EnterpriseSnapshot> load(SalesWindow window) async =>
      captureSnapshot();
}

EnterpriseController captureController() =>
    EnterpriseController(CaptureRepository(), clock: () => captureNow);
