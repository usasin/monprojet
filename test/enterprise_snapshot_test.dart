import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/sales/enterprise_snapshot.dart';
import 'package:ai_prospect_gps/sales/sales_model.dart';
import 'enterprise_fixture.dart';

void main() {
  EnterpriseView view() => enterpriseFixture().view(
    SalesWindow.forPeriod(enterpriseTestNow, 'week'),
    enterpriseTestNow,
  );
  test('company portfolio counts unique prospects independently of deals', () {
    final v = view();
    expect(v.prospects.length, 120);
    expect(v.deals.length, 112);
    expect(v.prospectsFor('new').length, 18);
    expect(v.prospectsFor('qualify').length, 24);
    expect(v.prospectsFor('hot').length, 12);
    expect(v.prospectsFor('followup').length, 8);
    expect(v.prospectsFor('won').length, 12);
    expect(v.totals.won.length, 12);
    expect(v.totals.lost.length, 4);
    expect(v.totals.winRate, .75);
    expect(v.totals.signedCents, 2460000);
  });
  test(
    'tour completion requires every distinct planned stop with a report',
    () {
      final v = view();
      expect(v.plans.length, 12);
      expect(v.completedTours, 10);
      expect(v.plannedVisits, 64);
      expect(v.completedVisits, 48);
      expect(v.appointments.length, 9);
      expect(v.activeMembers.length, 6);
      expect(v.overdueFollowUps.length, 2);
      expect(v.pendingInvites.length, 1);
      final p = EnterpriseRecord('duplicate', 'r', {
        'prospectIds': ['x', 'x', 'y'],
        'reports': {
          'x': {'status': 'présent'},
          'y': {},
        },
      });
      expect(p.prospectIds.length, 2);
      expect(p.completedVisits, 1);
      expect(p.complete, false);
    },
  );
  test(
    'team/member filters scope records and stock, keeping orphan prospects globally',
    () {
      final s = enterpriseFixture();
      final w = SalesWindow.forPeriod(enterpriseTestNow, 'week');
      final v = s.view(w, enterpriseTestNow, scope: 'manager:manager0');
      expect(v.selectedMembers.map((m) => m.uid), ['rep0', 'rep3', 'rep6']);
      expect(
        v.deals.every((d) => ['rep0', 'rep3', 'rep6'].contains(d.ownerUid)),
        true,
      );
      final one = s.view(w, enterpriseTestNow, scope: 'member:rep1');
      expect(one.selectedMembers.length, 1);
      expect(one.plans.length, 2);
      expect(one.deals.every((d) => d.ownerUid == 'rep1'), true);
    },
  );
  test(
    'changing period changes outcomes, not current portfolio or open follow-up',
    () {
      final s = enterpriseFixture();
      final next = s.view(
        SalesWindow(DateTime(2026, 11, 1), DateTime(2026, 12, 1)),
        enterpriseTestNow,
      );
      expect(next.prospects.length, 120);
      expect(next.prospectsFor('hot').length, 12);
      expect(next.totals.won, isEmpty);
      expect(next.totals.winRate, isNull);
      expect(next.plans, isEmpty);
      expect(next.prospectsFor('new'), isEmpty);
    },
  );
  test('expired/inactive invites and cancelled appointments are excluded', () {
    final s = enterpriseFixture();
    final v = EnterpriseSnapshot(
      members: s.members,
      prospects: s.prospects,
      deals: s.deals,
      plans: s.plans,
      appointments: [
        EnterpriseRecord('cancel', 'rep0', {
          'startsAt': enterpriseTestNow,
          'status': 'cancelled',
        }),
      ],
      invites: [
        EnterpriseRecord('expired', '', {
          'active': true,
          'expiresAt': enterpriseTestNow,
        }),
        EnterpriseRecord('revoked', '', {
          'active': false,
          'expiresAt': enterpriseTestNow.add(const Duration(days: 1)),
        }),
      ],
      readAt: s.readAt,
    ).view(SalesWindow.forPeriod(enterpriseTestNow, 'week'), enterpriseTestNow);
    expect(v.pendingInvites, isEmpty);
    expect(v.appointments, isEmpty);
  });
}
