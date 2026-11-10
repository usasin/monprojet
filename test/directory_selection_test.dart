import 'package:flutter_test/flutter_test.dart';
import 'package:ai_prospect_gps/directory/directory_selection.dart';
import 'package:ai_prospect_gps/models/prospect.dart';

Prospect record(String id,
        {String? siret,
        String? note,
        String? phone,
        String? source,
        String category = 'CHR',
        int priority = 3}) =>
    Prospect(
      id: id,
      name: 'Entreprise',
      address: 'Paris',
      category: category,
      lat: 48.865,
      lng: 2.333,
      siret: siret,
      note: note,
      phone: phone,
      source: source,
      priority: priority,
    );

void main() {
  test('online identity reuses the selected offline SIRET and private fields',
      () {
    final saved = record('siret_44533010300026',
        note: 'Note privée', phone: 'contact privé', priority: 5);
    final public =
        record('osm_node_1', siret: '44533010300026', phone: 'contact public');
    final result = preserveDirectorySelection([public], [saved]);
    expect(result.prospects, hasLength(1));
    expect(result.prospects.single.id, saved.id);
    expect(result.prospects.single.note, 'Note privée');
    expect(result.prospects.single.phone, 'contact privé');
    expect(result.prospects.single.priority, 5);
    expect(result.prospects.single.siret, '44533010300026');
    expect(result.aliases, {public.id: saved.id});
  });
  test(
      'same ID retains private fields and a selected outside result remains once',
      () {
    final saved = record('osm_node_1', note: 'Conserver');
    final outside = record('private_2');
    final result =
        preserveDirectorySelection([record(saved.id)], [saved, outside]);
    expect(result.prospects.map((p) => p.id), [saved.id, outside.id]);
    expect(result.prospects.first.note, 'Conserver');
  });
  test('matching names with different official IDs stay separate', () {
    final saved = record('private_1', siret: '44533010300026');
    final public = record('osm_node_2', siret: '44028375206686');
    final result = preserveDirectorySelection([public], [saved]);
    expect(result.prospects, hasLength(2));
    expect(result.aliases, isEmpty);
  });
  test('two public aliases cannot recreate the same selected prospect twice',
      () {
    final saved = record('private_1', siret: '44533010300026');
    final result = preserveDirectorySelection([
      record('siret_44533010300026', siret: saved.siret),
      record('osm_node_1', siret: saved.siret),
    ], [
      saved
    ]);
    expect(result.prospects, hasLength(1));
    expect(result.prospects.single.id, saved.id);
  });
  test('unsaved CHR selection survives a GMS search without a Firestore read',
      () async {
    final unsaved = record('siret_44533010300026',
        siret: '44533010300026',
        note: 'À rappeler demain',
        phone: 'contact privé',
        source: 'source choisie',
        priority: 5);
    var loads = 0;
    final selected = await loadSelectedDirectoryProspects(
      selectedIds: [unsaved.id],
      inMemory: [unsaved, record('unselected_chr')],
      loadMissing: (_) async {
        loads++;
        return [];
      },
    );
    final gms = record('siret_44028375206686',
        siret: '44028375206686', category: 'GMS');
    final result = preserveDirectorySelection([gms], selected);
    expect(loads, 0);
    expect(result.prospects.map((p) => p.id), [gms.id, unsaved.id]);
    final retained = result.prospects.singleWhere((p) => p.id == unsaved.id);
    expect(retained, same(unsaved));
    expect(retained.category, 'CHR');
    expect(retained.note, 'À rappeler demain');
    expect(retained.phone, 'contact privé');
    expect(retained.source, 'source choisie');
    expect(retained.priority, 5);
  });
  test('unsaved selection wins over an online alias with the same SIRET',
      () async {
    final unsaved = record('siret_44533010300026',
        note: 'Note non enregistrée', source: 'source privée', priority: 5);
    final selected = await loadSelectedDirectoryProspects(
      selectedIds: [unsaved.id],
      inMemory: [unsaved],
      loadMissing: (_) async => throw StateError('No saved record exists'),
    );
    final public = record('osm_node_1',
        siret: '44533010300026', note: 'publique', source: 'source publique');
    final result = preserveDirectorySelection([public], selected);
    expect(result.prospects, hasLength(1));
    expect(result.prospects.single.id, unsaved.id);
    expect(result.prospects.single.siret, public.siret);
    expect(result.prospects.single.note, unsaved.note);
    expect(result.prospects.single.source, unsaved.source);
    expect(result.prospects.single.priority, 5);
    expect(result.aliases, {public.id: unsaved.id});
  });
  test('only missing chosen IDs load and cannot replace current private edits',
      () async {
    final current = record('private_chr',
        siret: '44533010300026',
        note: 'Modification locale',
        source: 'source locale',
        priority: 5);
    final saved = record('private_gms',
        siret: '44028375206686', note: 'Fiche sauvegardée', category: 'GMS');
    final requested = <List<String>>[];
    final selected = await loadSelectedDirectoryProspects(
      selectedIds: [current.id, saved.id, current.id],
      inMemory: [current, record('unselected')],
      loadMissing: (ids) async {
        requested.add(List.of(ids));
        return [
          record(current.id, note: 'Ancienne version distante'),
          saved,
          record('not_chosen'),
        ];
      },
    );
    expect(requested, [
      [saved.id]
    ]);
    expect(selected.map((p) => p.id), [current.id, saved.id]);
    expect(selected.first, same(current));
    expect(selected.first.note, 'Modification locale');
    expect(selected.first.source, 'source locale');
    expect(selected.last, same(saved));
  });
}
