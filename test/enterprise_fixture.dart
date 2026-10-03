import 'package:ai_prospect_gps/models/prospect.dart';
import 'package:ai_prospect_gps/sales/enterprise_snapshot.dart';
import 'package:ai_prospect_gps/sales/sales_model.dart';

final enterpriseTestNow = DateTime(2026, 10, 3, 12, 9);
EnterpriseSnapshot enterpriseFixture() {
  final members = [
    const EnterpriseMember('owner', 'Ihab', 'OWNER', '', true),
    for (var i = 0; i < 3; i++)
      EnterpriseMember('manager$i', 'Responsable $i', 'MANAGER', '', true),
    for (var i = 0; i < 8; i++)
      EnterpriseMember(
        'rep$i',
        'Commercial $i',
        'REP',
        'manager${i % 3}',
        true,
      ),
  ];
  final prospects = [
    for (var i = 0; i < 120; i++)
      EnterpriseProspect(
        Prospect(
          id: 'p$i',
          name: 'Prospect $i',
          address: 'Marseille',
          category: 'B2B',
          lat: 0,
          lng: 0,
        ),
        i < 18 ? enterpriseTestNow : DateTime(2026, 9, 1),
        'rep${i % 6}',
      ),
  ];
  final deals = [
    for (var i = 0; i < 96; i++)
      SalesDeal(
        id: 'd$i',
        ownerUid: 'rep${i % 6}',
        ownerName: 'Commercial ${i % 6}',
        prospectId: 'p$i',
        prospectName: 'Prospect $i',
        title: 'Affaire $i',
        stage: 'qualified',
        interest: i < 12 ? 'hot' : 'warm',
        updatedAt: enterpriseTestNow,
        nextAction: i >= 12 && i < 20 ? 'followup' : '',
        nextActionAt: i >= 12 && i < 20
            ? enterpriseTestNow.add(Duration(days: i < 14 ? -1 : 1))
            : null,
      ),
    for (var i = 0; i < 16; i++)
      SalesDeal(
        id: 'closed$i',
        ownerUid: 'rep${i % 6}',
        ownerName: 'Commercial ${i % 6}',
        prospectId: 'p${i + 20}',
        prospectName: 'Prospect ${i + 20}',
        title: 'Contrat $i',
        stage: i < 12 ? 'won' : 'lost',
        interest: 'warm',
        amountCents: i < 12 ? 205000 : null,
        closedAt: enterpriseTestNow,
        updatedAt: enterpriseTestNow,
      ),
  ];
  final plans = [
    for (var i = 0; i < 12; i++)
      EnterpriseRecord('plan$i', 'rep${i % 6}', {
        'date': enterpriseTestNow,
        'prospectIds': [
          for (var j = 0; j < (i < 10 ? 4 : 12); j++) 'p${i * 4 + j}',
        ],
        'reports': {
          for (var j = 0; j < 4; j++) 'p${i * 4 + j}': {'status': 'présent'},
        },
      }),
  ];
  return EnterpriseSnapshot(
    members: members,
    prospects: prospects,
    deals: deals,
    plans: plans,
    appointments: [
      for (var i = 0; i < 9; i++)
        EnterpriseRecord('a$i', 'rep${i % 6}', {
          'startsAt': enterpriseTestNow,
          'title': 'RDV $i',
        }),
    ],
    invites: [
      EnterpriseRecord('invite', '', {
        'active': true,
        'expiresAt': enterpriseTestNow.add(const Duration(days: 1)),
        'email': 'invitation@example.com',
        'role': 'REP',
      }),
    ],
    readAt: enterpriseTestNow,
  );
}
