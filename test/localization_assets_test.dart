import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('French and English translation assets contain the critical journeys', () {
    final fr = jsonDecode(
      File('assets/translations/fr.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final en = jsonDecode(
      File('assets/translations/en.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    const criticalKeys = <String>[
      'Bienvenue sur Prospecto',
      'Je travaille seul',
      'J’utilise Prospecto en entreprise',
      'Préparation de votre espace…',
      'Créer un espace entreprise',
      'Rejoindre une entreprise',
      'Tarifs & abonnements',
      'Tournée intelligente',
      'Adresse complète, ville, pays…',
      'Rechercher',
      'Paramètres',
      'Choisir cette offre',
      'Envoyer par e-mail',
      'Votre messagerie est ouverte. Appuyez sur Envoyer pour transmettre la demande.',
    ];

    for (final key in criticalKeys) {
      expect(fr.containsKey(key), isTrue, reason: 'Missing FR key: $key');
      expect(en.containsKey(key), isTrue, reason: 'Missing EN key: $key');
      expect(en[key].toString().trim(), isNotEmpty,
          reason: 'Empty EN value: $key');
    }
  });
}
