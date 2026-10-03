import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/sales/enterprise_repository.dart';
import 'package:ai_prospect_gps/sales/enterprise_snapshot.dart';
import 'package:ai_prospect_gps/sales/sales_model.dart';
import 'enterprise_fixture.dart';

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(String uid) : currentUser = _User(uid);
  @override
  final User currentUser;
}

class _QueuedRepository extends EnterpriseRepository {
  _QueuedRepository()
    : super('org', firestore: FakeFirebaseFirestore(), auth: _Auth('owner'));
  final calls = <Completer<EnterpriseSnapshot>>[];
  @override
  Future<EnterpriseSnapshot> load(SalesWindow window) {
    final c = Completer<EnterpriseSnapshot>();
    calls.add(c);
    return c.future;
  }
}

void main() {
  test(
    'administrator reads all prospect pages and all representative records in only its company',
    () async {
      final db = FakeFirebaseFirestore();
      final root = db.doc('apps/prospecto/orgs/company');
      await root.collection('members').doc('owner').set({
        'role': 'OWNER',
        'status': 'active',
      });
      await root.collection('members').doc('rep').set({
        'role': 'REP',
        'status': 'active',
        'displayName': 'Sarah',
      });
      for (var i = 0; i < 251; i++) {
        await root
            .collection('prospects')
            .doc('p${i.toString().padLeft(3, '0')}')
            .set({'createdBy': 'rep', if (i != 250) 'name': 'Prospect $i'});
      }
      await db.doc('users/owner/prospects/private').set({'name': 'Privé'});
      await db.doc('apps/prospecto/orgs/other/prospects/foreign').set({
        'name': 'Autre entreprise',
      });
      await root
          .collection('memberData')
          .doc('rep')
          .collection('opportunities')
          .doc('won')
          .set({
            'prospectId': 'p001',
            'stage': 'won',
            'closedAt': enterpriseTestNow,
            'amountCents': 2500,
          });
      for (var i = 0; i < 250; i++) {
        await root
            .collection('memberData')
            .doc('rep')
            .collection('opportunities')
            .doc('deal$i')
            .set({'prospectId': 'p001', 'stage': 'qualify'});
      }
      await root
          .collection('memberData')
          .doc('rep')
          .collection('plans')
          .doc('route')
          .set({
            'date': enterpriseTestNow,
            'prospectIds': ['p001'],
            'reports': {
              'p001': {'status': 'présent'},
            },
          });
      await root
          .collection('memberData')
          .doc('rep')
          .collection('appointments')
          .doc('meeting')
          .set({'startsAt': enterpriseTestNow});
      final s = await EnterpriseRepository(
        'company',
        firestore: db,
        auth: _Auth('owner'),
      ).load(SalesWindow.forPeriod(enterpriseTestNow, 'week'));
      expect(s.prospects.length, 251);
      expect(s.prospects.any((p) => p.prospect.id == 'p250'), true);
      expect(
        s.prospects.any((p) => ['private', 'foreign'].contains(p.prospect.id)),
        false,
      );
      expect(s.deals.length, 251);
      expect(s.deals.every((d) => d.ownerName == 'Sarah'), true);
      expect(s.deals.any((d) => d.id == 'won'), true);
      expect(s.plans.single.complete, true);
      expect(s.appointments.length, 1);
    },
  );
  test(
    'supervision gate rejects REP, revoked and wrong organization',
    () async {
      final db = FakeFirebaseFirestore();
      final root = db.doc('apps/prospecto/orgs/company');
      final repo = EnterpriseRepository(
        'company',
        firestore: db,
        auth: _Auth('user'),
      );
      for (final role in ['REP']) {
        await root.collection('members').doc('user').set({
          'role': role,
          'status': 'active',
        });
        await expectLater(
          repo.load(SalesWindow.forPeriod(enterpriseTestNow, 'week')),
          throwsStateError,
        );
      }
      await root.collection('members').doc('user').set({
        'role': 'OWNER',
        'status': 'revoked',
      });
      await expectLater(
        repo.load(SalesWindow.forPeriod(enterpriseTestNow, 'week')),
        throwsStateError,
      );
      await expectLater(
        EnterpriseRepository(
          'other',
          firestore: db,
          auth: _Auth('user'),
        ).load(SalesWindow.forPeriod(enterpriseTestNow, 'week')),
        throwsStateError,
      );
    },
  );
  test(
    'manager snapshot includes only assigned representative records and no invitations',
    () async {
      final db = FakeFirebaseFirestore();
      final root = db.doc('apps/prospecto/orgs/company');
      await root.set({
        'displaySettings': {'showContracts': true, 'showRevenue': false},
      });
      await root.collection('members').doc('manager').set({
        'role': 'MANAGER',
        'status': 'active',
      });
      for (final uid in ['a', 'b']) {
        await root.collection('members').doc(uid).set({
          'role': 'REP',
          'status': 'active',
          'managerUid': uid == 'a' ? 'manager' : 'other',
        });
        await root.collection('prospects').doc(uid).set({
          'name': uid,
          'createdBy': uid,
        });
        await root
            .collection('memberData')
            .doc(uid)
            .collection('opportunities')
            .doc('sale')
            .set({'prospectId': uid, 'stage': 'qualified'});
      }
      final snap = await EnterpriseRepository(
        'company',
        firestore: db,
        auth: _Auth('manager'),
      ).load(SalesWindow.forPeriod(enterpriseTestNow, 'week'));
      final view = snap.view(
        SalesWindow.forPeriod(enterpriseTestNow, 'week'),
        enterpriseTestNow,
        scope: 'manager:manager',
      );
      expect(view.prospects.map((p) => p.prospect.id), ['a']);
      expect(view.deals.single.ownerUid, 'a');
      expect(snap.invites, isEmpty);
      expect(snap.display.showRevenue, false);
      expect(EnterpriseController.scopeOptions(snap).containsKey('all'), false);
      expect(
        EnterpriseController.scopeOptions(snap).containsKey('member:b'),
        false,
      );
    },
  );
  test('a stale request cannot replace new period results or errors', () async {
    final repo = _QueuedRepository();
    final c = EnterpriseController(repo, clock: () => enterpriseTestNow);
    final first = c.refresh();
    c.selectPeriod('month');
    expect(repo.calls.length, 2);
    repo.calls[1].complete(enterpriseFixture());
    await Future<void>.delayed(Duration.zero);
    repo.calls[0].completeError(StateError('old request'));
    await first;
    expect(c.period, 'month');
    expect(c.error, isNull);
    expect(c.snapshot, isNotNull);
    expect(c.loading, false);
    c.dispose();
  });
}

// Manager scope is tested separately from the owner directory.
