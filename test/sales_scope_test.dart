import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/sales/sales_service.dart';

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

void main() {
  test('Solo portfolio and contracts use the private authenticated root',
      () async {
    final db = FakeFirebaseFirestore();
    final service =
        SalesService('', firestore: db, firebaseAuth: _Auth('alice'));
    expect(service.org.path, 'users/alice');
    // A supplied colleague identifier cannot redirect Solo data.
    expect(service.deals('bob').path, 'users/alice/opportunities');
    await db
        .doc('users/alice/opportunities/a')
        .set({'title': 'Alice', 'stage': 'won'});
    await db
        .doc('users/bob/opportunities/b')
        .set({'title': 'Bob', 'stage': 'won'});
    expect((await service.deals('bob').get()).docs.map((d) => d.id), ['a']);
  });
  test('enterprise and personal drafts and records are independent', () {
    final db = FakeFirebaseFirestore();
    final auth = _Auth('alice');
    final solo = SalesService('', firestore: db, firebaseAuth: auth);
    final team = SalesService('company', firestore: db, firebaseAuth: auth);
    expect(team.deals('alice').path,
        'apps/prospecto/orgs/company/memberData/alice/opportunities');
    expect(solo.draftKey('same-id'), isNot(team.draftKey('same-id')));
    expect(solo.draftKey('same-id'), contains(':alice:'));
  });
}
