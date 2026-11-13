import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'directory_models.dart';
import 'directory_service.dart';
import 'directory_sample.dart';
import 'directory_territories.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/prospect_info_chip.dart';
import '../services/prospecto_directory_api.dart';
import 'directory_catalog_service.dart';

class DirectoryPage extends StatefulWidget {
  final DirectoryService? directory;
  final ProspectoDirectoryApi? api;
  final DirectoryCatalogService? catalog;
  const DirectoryPage({super.key, this.directory, this.api, this.catalog});
  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  final _input = TextEditingController();
  late final _directory = widget.directory ?? DirectoryService.instance;
  late final _api = widget.api ?? ProspectoDirectoryApi.configured();
  late final _staticCatalog = widget.catalog ??
      (widget.api == null
          ? DirectoryCatalogService.configured(_directory.backend.fetchCatalog)
          : null);
  bool get _hasCatalog => _staticCatalog != null || _api != null;
  final _territoryFilter = TextEditingController();
  bool _showRegions = false;
  List<DirectoryPack> _catalog = [], _installed = [];
  bool _busy = false;
  String? _downloadingId;
  String _message = '';
  bool _messageIsError = false;
  DirectorySample? _sample;
  bool _sampleReady = false;
  @override
  void initState() {
    super.initState();
    _reload();
    if (_hasCatalog && _directory.supported) _refreshCatalog();
  }

  @override
  void dispose() {
    _input.dispose();
    _territoryFilter.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final packs = await _directory.backend.installed();
      if (mounted) setState(() => _installed = packs);
    } catch (error) {
      if (mounted) setState(() { _message = '$error'; _messageIsError = true; });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
      _messageIsError = false;
    });
    try {
      await action();
      await _reload();
    } catch (error) {
      if (mounted) setState(() { _message = '$error'; _messageIsError = true; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadCatalog() => _run(() async {
        final text = _input.text.trim();
        if (text.isEmpty)
          throw const DirectoryException(
            'Collez un catalogue JSON ou un lien HTTPS.',
          );
        var uri = Uri.tryParse(text);
        final remote = uri?.scheme == 'https';
        var source =
            remote ? await _directory.backend.fetchCatalog(uri!) : text;
        var decoded = jsonDecode(source) as Map<String, dynamic>;
        // A published current.json may point to an immutable versioned catalog.
        // Resolve relative pack URLs against that final catalog, not current.json.
        for (var depth = 0;
            remote &&
                decoded['packs'] == null &&
                decoded['catalog'] is String &&
                depth < 2;
            depth++) {
          uri = uri!.resolve(decoded['catalog'] as String);
          if (uri.scheme != 'https')
            throw const DirectoryException(
                'Le catalogue de version doit utiliser HTTPS.');
          source = await _directory.backend.fetchCatalog(uri);
          decoded = jsonDecode(source) as Map<String, dynamic>;
        }
        final packs = parseDirectoryCatalog(
          decoded,
          base: remote ? uri : null,
        );
        _showCatalog(packs);
      });
  Future<void> _refreshCatalog() => _run(() async {
        if (_staticCatalog != null) {
          _showCatalog(await _staticCatalog.load());
          return;
        }
        final api = _api;
        if (api != null) _showCatalog(await api.catalog());
      });

  Future<void> _download(DirectoryPack pack) => _run(() async {
        if (mounted) setState(() => _downloadingId = pack.id);
        try {
          await _directory.backend.install(pack);
          if (mounted)
            setState(() => _message =
                '${directoryTerritoryTitle(pack)} est prêt. Choisissez maintenant votre lieu.');
        } finally {
          if (mounted) setState(() => _downloadingId = null);
        }
      });
  void _showCatalog(List<DirectoryPack> packs) {
    if (mounted)
      setState(() {
        _catalog = packs;
        _message = '';
      });
  }

  Future<void> _chooseCatalog() => _run(() async {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: true,
        );
        if (result == null) return;
        final bytes = result.files.single.bytes;
        if (bytes == null || bytes.length > 4 * 1024 * 1024) {
          throw const DirectoryException(
              'Catalogue inaccessible ou supérieur à 4 Mo.');
        }
        _showCatalog(parseDirectoryCatalog(
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
        ));
      });

  Future<void> _installSample() => _run(() async {
        final sample = await DirectorySample.load();
        await sample.install(_directory.backend);
        if (mounted)
          setState(() {
            _sample = sample;
            _sampleReady = true;
            _message =
                'Extrait public réel vérifié et installé. Couverture partielle : les recherches gardent leur complément en ligne.';
          });
      });
  Future<void> _importLocal(DirectoryPack pack) async {
    await _run(() async {
      pack.ensureInstallable();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gz'],
        withData: false,
      );
      final file = result?.files.single.path;
      if (result == null) return;
      if (file == null)
        throw const DirectoryException(
          'Fichier inaccessible : choisissez un fichier .sqlite.gz enregistré sur cet appareil.',
        );
      await _directory.backend.install(pack, localFile: file);
      if (mounted) setState(() => _message = 'Pack vérifié et installé.');
    });
  }

  List<DirectoryPack> get _visibleCatalog =>
      filterDirectoryTerritories(_catalog,
          regions: _showRegions, query: _territoryFilter.text);

  void _usePack(DirectoryPack pack, {DirectorySearchSeed? seed}) =>
      Navigator.of(context).pop(DirectoryUseSelection(pack, seed: seed));

  Widget _packCard(DirectoryPack pack, {required bool installed}) {
    final title = directoryTerritoryTitle(pack);
    final ready = installed || _installed.any((p) =>
        p.id == pack.id && p.version == pack.version &&
        p.sqliteHash == pack.sqliteHash);
    final rows = pack.json['rows'];
    final packDetails = <String>[
      if (rows is int) '$rows établissements référencés.',
      'Mise à jour des données : ${pack.json['data_date'] ?? 'non indiquée'}.',
      pack.complete
          ? 'Le fournisseur déclare la zone entièrement couverte par ce pack.'
          : 'Ce pack ne contient qu’une partie des professionnels de la zone. Une recherche en ligne peut compléter les résultats.',
      'Téléchargement : ${(pack.gzipBytes / 1048576).toStringAsFixed(1)} Mo. '
          'Espace une fois installé : ${(pack.sqliteBytes / 1048576).toStringAsFixed(1)} Mo.',
      if (pack.demo) 'Cet exemple sert uniquement à découvrir le fonctionnement et utilise des données de démonstration.',
    ].join('\n\n');
    return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(ready ? Icons.offline_pin_rounded : Icons.map_outlined,
                    color: ready ? ProspectoColors.green : ProspectoColors.blue),
                const SizedBox(width: 9),
                Expanded(child: Text(title, style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16))),
                if (installed)
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (value) => _run(() async {
                      if (value == 'remove') {
                        await _directory.backend.remove(pack.id);
                      } else {
                        final restored = await _directory.backend.rollback(pack.id);
                        if (mounted) setState(() => _message = restored
                            ? 'Version précédente restaurée.'
                            : 'Aucune version précédente disponible.');
                      }
                    }),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rollback',
                          child: Text('Version précédente')),
                      PopupMenuItem(value: 'remove',
                          child: Text('Retirer de cet appareil')),
                    ],
                  ),
              ]),
              const SizedBox(height: 9),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ProspectInfoChip(
                  label: ready ? 'Installé' : (pack.url?.scheme == 'https'
                      ? 'Téléchargeable' : 'Non publié'),
                  icon: ready ? Icons.check_circle_rounded : Icons.cloud_outlined,
                  tone: ready ? ProspectInfoTone.installed
                      : pack.url?.scheme == 'https'
                          ? ProspectInfoTone.online : ProspectInfoTone.caution,
                  details: ready
                      ? 'Ce pack est présent sur votre appareil. Il peut être utilisé si la zone recherchée correspond.'
                      : pack.url?.scheme == 'https'
                          ? 'Ce pack peut être téléchargé sur cet appareil.'
                          : 'Le téléchargement de ce territoire n’est pas proposé pour le moment. La recherche en ligne reste possible.',
                ),
                ProspectInfoChip(
                  label: pack.complete ? 'Couverture déclarée' : 'Couverture partielle',
                  icon: pack.complete ? Icons.verified_outlined
                      : Icons.info_outline_rounded,
                  tone: pack.complete ? ProspectInfoTone.installed
                      : ProspectInfoTone.caution,
                  details: pack.complete
                      ? 'La couverture est déclarée complète par le catalogue. Elle ne garantit pas que toutes les entreprises existantes figurent dans ce pack.'
                      : 'Les informations téléchargées ne comprennent pas tous les professionnels de cette zone. Une recherche en ligne peut compléter la liste.',
                ),
                if (pack.demo)
                  const ProspectInfoChip(
                    label: 'Démonstration',
                    tone: ProspectInfoTone.caution,
                    details: 'Ce pack est destiné à des essais : il ne représente pas une liste complète de prospects.',
                  ),
                if (rows is int)
                  ProspectInfoChip(
                    label: '$rows fiches',
                    icon: Icons.business_rounded,
                    details: 'Ce pack contient $rows établissements. Ce nombre ne correspond pas nécessairement à tous les professionnels du territoire.',
                  ),
                ProspectInfoChip(
                  label: 'Détails',
                  details: packDetails,
                  icon: Icons.info_outline_rounded,
                ),
              ]),
              const SizedBox(height: 10),
              if (_downloadingId == pack.id) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('Téléchargement en cours…'),
              ] else if (ready)
                FilledButton.icon(
                    key: ValueKey('use-territory-${pack.id}'),
                    onPressed: _busy ? null : () => _usePack(pack),
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Choisir mon lieu de recherche'))
              else if (!pack.mobileCompatible)
                const ProspectInfoChip(
                    label: 'Non compatible',
                    icon: Icons.warning_amber_outlined,
                    tone: ProspectInfoTone.caution,
                    details: 'Ce pack est trop volumineux pour cet appareil. Vous pouvez choisir une zone plus petite ou utiliser la recherche en ligne.')
              else if (pack.url?.scheme == 'https')
                FilledButton.icon(
                    key: ValueKey('download-territory-${pack.id}'),
                    onPressed: _busy ? null : () => _download(pack),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Télécharger')),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCatalog;
    final downloadableDepartments = _catalog.where((pack) =>
        pack.department.isNotEmpty && pack.mobileCompatible &&
        !pack.demo && pack.url?.scheme == 'https').length;
    final downloadableRegions = _catalog.where((pack) =>
        pack.department.isEmpty && pack.mobileCompatible &&
        !pack.demo && pack.url?.scheme == 'https').length;
    return Scaffold(
        appBar: AppBar(title: const Text('Mes départements et régions')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Wrap(spacing: 7, runSpacing: 7, children: [
            const ProspectInfoChip(
              key: Key('catalog-online-status'),
              label: 'Recherche en ligne',
              tone: ProspectInfoTone.online,
              icon: Icons.wifi_rounded,
              details: 'Même sans téléchargement, vous pouvez rechercher des professionnels depuis « Créer ma tournée ». Les résultats dépendent des données en ligne.',
            ),
            ProspectInfoChip(
              key: const Key('catalog-installed-status'),
              label: '${_installed.length} ${_installed.length == 1 ? 'pack installé' : 'packs installés'}',
              tone: _installed.isEmpty
                  ? ProspectInfoTone.neutral : ProspectInfoTone.installed,
              icon: Icons.offline_pin_outlined,
              details: _installed.isEmpty
                  ? 'Aucun pack sur cet appareil. Le téléchargement est facultatif pour rechercher en ligne.'
                  : 'Vos zones sur cet appareil : ${_installed.map(directoryTerritoryTitle).join(', ')}.',
            ),
            const ProspectInfoChip(
              label: 'Comment ça marche ?',
              icon: Icons.help_outline_rounded,
              details: 'Sélectionnez un territoire publié pour le télécharger, ou retournez à « Créer ma tournée » pour rechercher directement autour d’une adresse.',
            ),
          ]),
          const SizedBox(height: 12),
          if (!_directory.supported)
            const ProspectInfoChip(
              label: 'Téléchargement indisponible',
              tone: ProspectInfoTone.caution,
              details: 'Cet appareil ne prend pas en charge les données téléchargées. La recherche en ligne reste possible.',
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ProspectInfoChip(
                key: const Key('catalog-feedback-chip'),
                label: _messageIsError ? 'Action nécessaire' : 'Information',
                tone: _messageIsError
                    ? ProspectInfoTone.error : ProspectInfoTone.installed,
                icon: _messageIsError
                    ? Icons.error_outline_rounded : Icons.check_circle_outline,
                details: _message,
              ),
            ),
          if (_installed.isNotEmpty) ...[
            Text('Déjà sur mon appareil',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final pack in _installed) _packCard(pack, installed: true),
            const SizedBox(height: 10),
          ],
          if (_directory.supported) ...[
            Text('Ajouter un territoire',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ProspectInfoChip(
              label: _hasCatalog ? 'Disponibilité des packs' : 'Packs non disponibles',
              icon: Icons.info_outline_rounded,
              tone: _hasCatalog ? ProspectInfoTone.online : ProspectInfoTone.caution,
              details: _hasCatalog
                  ? 'Seules les zones publiées peuvent être téléchargées. Vous pouvez rechercher en ligne dans les autres départements.'
                  : 'Aucun catalogue de téléchargements n’est actuellement proposé. La recherche en ligne reste accessible.',
            ),
            const SizedBox(height: 10),
            if (_hasCatalog)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Actualiser les territoires',
                  onPressed: _busy ? null : _refreshCatalog,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            if (_catalog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(key: const Key('published-territories-summary'),
                  spacing: 7, runSpacing: 7, children: [
                ProspectInfoChip(
                  key: const Key('available-departments-chip'),
                  label: '$downloadableDepartments ${downloadableDepartments == 1 ? 'département' : 'départements'}',
                  tone: ProspectInfoTone.online,
                  icon: Icons.map_outlined,
                  details: '$downloadableDepartments ${downloadableDepartments == 1 ? 'département peut' : 'départements peuvent'} être téléchargé${downloadableDepartments == 1 ? '' : 's'} actuellement. Les autres restent accessibles par la recherche en ligne, selon les données disponibles.',
                ),
                ProspectInfoChip(
                  label: '$downloadableRegions ${downloadableRegions == 1 ? 'région' : 'régions'}',
                  tone: ProspectInfoTone.neutral,
                  icon: Icons.layers_outlined,
                  details: '$downloadableRegions ${downloadableRegions == 1 ? 'région peut' : 'régions peuvent'} être téléchargée${downloadableRegions == 1 ? '' : 's'} actuellement.',
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: Text('Départements (${_catalog.where((p) => p.department.isNotEmpty).length})'),
                    selected: !_showRegions,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _showRegions = false)),
                ChoiceChip(
                    label: Text('Régions (${_catalog.where((p) => p.department.isEmpty).length})'),
                    selected: _showRegions,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _showRegions = true)),
              ]),
              const SizedBox(height: 8),
              TextField(
                  controller: _territoryFilter,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: _showRegions
                          ? 'Nom de région'
                          : 'Nom ou numéro du département',
                      hintText: _showRegions
                          ? 'Ex. Île-de-France'
                          : 'Ex. 75 ou Paris',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)))),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                ProspectInfoChip(
                  label: 'Aucune zone dans cette liste',
                  tone: ProspectInfoTone.caution,
                  details: _showRegions && _catalog.every((p) => p.department.isNotEmpty)
                      ? 'Aucune région entière n’est actuellement proposée au téléchargement. Vous pouvez toujours rechercher en ligne.'
                      : 'Aucun territoire ne correspond au filtre. Essayez un autre nom ou numéro.',
                ),
              for (final pack in visible) _packCard(pack, installed: false),
            ],
            const SizedBox(height: 14),
            ExpansionTile(
                title: const Text('Options avancées'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  // The optional example is kept accessible without crowding the main screen.
                  ExpansionTile(
                title: const Text('Essayer avec l’extrait réel de Paris'),
                subtitle:
                    const Text('Petit extrait de test, pas la France entière'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  const Text(
                      'Cet extrait contient 50 établissements publics réels. Il permet d’essayer le choix du lieu et des activités, avec une couverture partielle.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _installSample,
                      icon: const Icon(Icons.offline_pin_outlined),
                      label: const Text('Charger l’extrait Paris')),
                  if (_sampleReady && _sample != null)
                    TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _usePack(
                                _sample!.packs.firstWhere(
                                    (p) => p.department == '75',
                                    orElse: () => _sample!.packs.first),
                                seed: _sample!.seed),
                        icon: const Icon(Icons.place_outlined),
                        label: const Text('Préparer ma recherche à Paris')),
                ]),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                      onPressed: _busy ? null : _chooseCatalog,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Importer un catalogue local')),
                  for (final pack
                      in _catalog.where((p) => p.url?.scheme != 'https'))
                    TextButton.icon(
                        onPressed: _busy ? null : () => _importLocal(pack),
                        icon: const Icon(Icons.file_open_outlined),
                        label: Text(
                            'Importer le fichier : ${directoryTerritoryTitle(pack)}')),
                  TextField(
                      controller: _input,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Catalogue JSON ou lien HTTPS')),
                  const SizedBox(height: 8),
                  OutlinedButton(
                      onPressed: _busy ? null : _loadCatalog,
                      child: const Text('Lire ce catalogue')),
                  SwitchListTile(
                      value: _directory.allowDemo,
                      onChanged: _busy
                          ? null
                          : (value) =>
                              setState(() => _directory.allowDemo = value),
                      title:
                          const Text('Autoriser les données de démonstration'),
                      subtitle: const Text(
                          'Désactivées par défaut. Les données fictives ne sont jamais utilisées automatiquement.')),
                ]),
          ],
        ]));
  }
}

class DirectoryDetails extends StatelessWidget {
  final DirectoryRecord record;
  const DirectoryDetails({super.key, required this.record});
  String _value(Object? value) =>
      value == null || '$value'.isEmpty ? 'inconnue' : '$value';
  @override
  Widget build(BuildContext context) {
    final row = record.establishment;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        '${record.pack.demo ? 'DÉMONSTRATION · ' : ''}Fiche établissement',
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'SIRET : ${_value(row['siret'])}\nNAF : ${_value(row['naf_code'])} (${_value(row['naf_version'])})\nEffectif : ${_value(row['employee_band'])} · taille : ${_value(row['enterprise_size'])}\nSource annuaire : ${_value(row['source'])} · ${_value(row['source_date'])}\nGéocodage : ${_value(row['geo_quality'])}',
          ),
        ),
      ],
    );
  }
}
