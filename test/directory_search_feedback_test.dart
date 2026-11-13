import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/directory/directory_models.dart';
import 'package:ai_prospect_gps/directory/directory_search_feedback.dart';
import 'package:ai_prospect_gps/models/prospect.dart';

void main() {
  test('network geocoding failure cannot become address not found', () {
    for (final error in [
      Exception('Géocodage indisponible : réseau'),
      Exception('Géocodage échoué (HTTP 503)'),
      TimeoutException('geocoding timed out'),
    ]) {
      final message = directorySearchFailureMessage(error, isFrench: true);
      expect(message, isNot(contains('Adresse introuvable')));
      expect(message.toLowerCase(), anyOf(contains('connexion'), contains('répond pas')));
    }
    expect(directorySearchFailureMessage(
      Exception('Géocodage échoué: adresse introuvable'), isFrench: true,
    ), contains('Adresse introuvable'));
  });

  test('directory failure keeps its actionable explanation', () {
    const message = 'Réseau indisponible, résultats locaux seulement.';
    expect(directorySearchFailureMessage(
      const DirectoryException(message), isFrench: true,
    ), message);
  });

  test('technical directory errors never leak pack information to user', () {
    final result = directorySearchFailureMessage(
      const DirectoryException('Annuaire local et pack endommagé : OpenStreetMap HTTP 503'),
      isFrench: true,
    );
    expect(result, contains('connexion'));
    expect(result.toLowerCase(), isNot(contains('pack')));
    expect(result.toLowerCase(), isNot(contains('openstreetmap')));
  });

  test('public identity survives prospect edits and storage round trip', () {
    final original = Prospect(
      id: 'siret_12345678901234', name: 'Entreprise', address: 'Paris',
      category: 'CHR', lat: 48.865, lng: 2.333,
      source: 'Annuaire public local', siret: '12345678901234', nafCode: '56.10A',
      note: 'Note privée', priority: 5,
    );
    final edited = original.copyWith(visitDurationMinutes: 40);
    final restored = Prospect.fromFirestore(edited.toJson(), edited.id);
    expect(restored.source, original.source);
    expect(restored.siret, original.siret);
    expect(restored.nafCode, original.nafCode);
    expect(restored.note, 'Note privée');
    expect(restored.priority, 5);
    expect(restored.visitDurationMinutes, 40);
  });
}
