import '../models/prospect.dart';

class DirectorySelectionResult {
  final List<Prospect> prospects;

  /// Incoming public ID -> existing private ID, for the public details sheet.
  final Map<String, String> aliases;
  const DirectorySelectionResult(this.prospects, this.aliases);
}

/// Current edits and new selections take priority over older saved records.
/// Firestore is only needed for selected IDs absent from the current screen.
Future<List<Prospect>> loadSelectedDirectoryProspects({
  required Iterable<String> selectedIds,
  required Iterable<Prospect> inMemory,
  required Future<List<Prospect>> Function(List<String> ids) loadMissing,
}) async {
  final ids = selectedIds.toSet();
  final selected = <String, Prospect>{
    for (final prospect in inMemory)
      if (ids.contains(prospect.id)) prospect.id: prospect,
  };
  final missing = ids.where((id) => !selected.containsKey(id)).toList();
  if (missing.isNotEmpty) {
    final missingIds = missing.toSet();
    for (final prospect in await loadMissing(missing)) {
      if (missingIds.contains(prospect.id)) {
        selected.putIfAbsent(prospect.id, () => prospect);
      }
    }
  }
  return [
    for (final id in ids)
      if (selected[id] != null) selected[id]!
  ];
}

/// Preserve private prospect IDs and fields across offline/online searches.
/// Only an exact ID or SIRET may associate a public result with a saved record.
DirectorySelectionResult preserveDirectorySelection(
  List<Prospect> results,
  List<Prospect> selected,
) {
  String? identity(Prospect value) {
    final explicit = value.siret?.trim();
    if (explicit != null && RegExp(r'^\d{14}$').hasMatch(explicit))
      return explicit;
    return RegExp(r'^siret[:_](\d{14})$').firstMatch(value.id)?.group(1);
  }

  final byId = {for (final value in selected) value.id: value};
  final bySiret = <String, Prospect>{};
  for (final value in selected) {
    final siret = identity(value);
    if (siret != null) bySiret.putIfAbsent(siret, () => value);
  }
  final output = <Prospect>[];
  final seen = <String>{};
  final aliases = <String, String>{};
  for (final value in results) {
    final siret = identity(value);
    final saved = byId[value.id] ?? (siret == null ? null : bySiret[siret]);
    final resolved = saved == null
        ? value
        : saved.copyWith(
            source: saved.source ?? value.source,
            siret: saved.siret ?? value.siret,
            nafCode: saved.nafCode ?? value.nafCode,
          );
    if (saved != null && value.id != saved.id) aliases[value.id] = saved.id;
    if (seen.add(resolved.id)) output.add(resolved);
  }
  // Already selected prospects outside the new search remain available.
  for (final value in selected) {
    if (seen.add(value.id)) output.add(value);
  }
  return DirectorySelectionResult(output, aliases);
}
