// lib/pages/select_prospects_page.dart
// UI 2026 — Glassmorphism élégant, hiérarchie claire, animations fluides
// Redesign: fond auroré animé, cartes glass premium, étapes visuelles, barre d'action persistante

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/engagement_tracker.dart';
import '../models/prospect.dart';
import '../providers/theme_provider.dart';
import '../providers/org_provider.dart';
import '../services/firestore_service.dart';
import '../services/access_control.dart';
import '../services/ad_config.dart';
import '../services/ad_service.dart';
import '../services/usage_meter.dart';
import '../services/osm_search_service.dart';
import '../services/directory_online_search.dart';
import '../services/prospecto_directory_api.dart';
import '../directory/directory_models.dart';
import '../directory/directory_service.dart';
import '../directory/directory_page.dart';
import '../directory/directory_selection.dart';
import '../directory/directory_territories.dart';
import '../directory/prospect_search_form.dart';
import '../services/prospect_location_service.dart';
import '../widgets/prospect_location_chooser.dart';
import '../directory/directory_search_feedback.dart';
import '../widgets/osm_search_feedback.dart';
import '../widgets/prospect_info_chip.dart';
import '../screens/credits_paywall_page.dart';
import '../widgets/brand_background.dart';
import '../ui/bling.dart';

import 'home_page.dart';
import 'map_page.dart';
import 'plan_week_page.dart';
import 'smart_route_page.dart';

import '../theme/prospecto_colors.dart';
// ════════════════════════════════════════════════════════════════
//  Palette & tokens 2026
// ════════════════════════════════════════════════════════════════
class _Palette {
  static const indigo       = ProspectoColors.blue;
  static const indigoLight  = ProspectoColors.blueSoft;
  static const violet       = ProspectoColors.green;
  static const sky          = ProspectoColors.blueSoft;
  static const mint         = ProspectoColors.green;
  static const coral        = ProspectoColors.peach;
  static const amber        = ProspectoColors.peachSoft;

  static const bgDark       = Color(0xFF0A0D1A);
  static const bgLight      = ProspectoColors.background;
  static const surfDark     = Color(0xFF131728);
  static const surfLight    = Color(0xFFFFFFFF);
  static const glass        = Color(0x1AFFFFFF);
  static const glassBorder  = Color(0x26FFFFFF);
  static const glassDark    = Color(0x0DFFFFFF);

  static const onDark       = Color(0xFFF0F2FF);
  static const onDarkSub    = Color(0xFF9099C4);
  static const onLight      = ProspectoColors.textPrimary;
  static const onLightSub   = ProspectoColors.textSecondary;

  static LinearGradient get primaryGrad => const LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get auroraGrad => const LinearGradient(
    colors: [ProspectoColors.backgroundTop, ProspectoColors.blueMist, ProspectoColors.peachMist],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ════════════════════════════════════════════════════════════════
//  Page principale
// ════════════════════════════════════════════════════════════════
class SelectProspectsPage extends StatefulWidget {
  static const routeName = '/select';
  const SelectProspectsPage({Key? key}) : super(key: key);

  @override
  State<SelectProspectsPage> createState() => _SelectProspectsPageState();
}

class _SelectProspectsPageState extends State<SelectProspectsPage>
    with TickerProviderStateMixin {

  // ── Controllers
  final _streetCtrl   = TextEditingController();
  final _categoryCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // ── Pagination & tri
  int  _pageSize    = 20;
  int  _loadedCount = 0;
  bool _asc         = true;

  final List<Prospect> _allOptions = [];
  List<Prospect>       _options    = [];
  final Set<String>    _chosen     = {};

  // ── États
  bool              _loading         = false;
  int               _fetchToken      = 0;
  bool              _dirty           = false;
  bool              _showOnlyChosen  = false;

  // ── Recherche OSM
  static const List<int> _searchRadiiMeters = [500, 1000, 2000, 5000, 10000];
  int  _radiusIndex  = 1;
  static const List<String> _quickKeywordsFr = [
    'restaurant',
    'CHR',
    'GMS',
    'parapharmacie',
    'zone d’activités',
    'TPE/PME',
    'industrie',
    'logistique',
    'coiffeur',
    'grossiste boissons',
    'hôtel',
    'pharmacie',
    'garage',
    'chantier',
  ];
  static const List<String> _quickKeywordsEn = [
    'restaurant',
    'HORECA',
    'GMS',
    'chemist',
    'business park',
    'SME',
    'industry',
    'logistics',
    'hairdresser',
    'beverage wholesaler',
    'hotel',
    'pharmacy',
    'garage',
    'construction',
  ];
  DateTime? _lastSearchAt;
  String    _lastSearchKey = '';

  // ── Sélection ordonnée
  final List<String> _chosenOrder = [];
  Map<String, dynamic> _replanned = {};
  Map<String, dynamic>? _smartRouteMetadata;

  // ── Ads
  BannerAd? _bannerAd;
  bool      _isBannerLoaded = false;

  // ── Entitlements
  bool _isPremium    = false;
  int  _freeToursUsed = 0;

  // ── OSM
  final _directory = DirectoryService.instance;
  final _onlineSearch = DirectoryOnlineSearch();
  Map<String, DirectoryRecord> _directoryDetails = {};
  String _directoryNotice = '';
  String _searchFeedback = '';
  bool _searchFeedbackIsError = false;
  final _locations = ProspectLocationService();
  final _deviceLocation = ProspectDeviceLocation();
  ProspectSearchLocation? _searchLocation;
  List<String> _installedTerritories = [];
  String? _selectedTerritory;
  bool _locating = false;

  // ── Animations
  late final AnimationController _fabAnim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 400),
  );
  late final AnimationController _listAnim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 600),
  );

  // ── Section expansion (accordéon)
  bool _searchExpanded = true;
  bool _targetingExpanded = false;
  final GlobalKey _targetingStepKey = GlobalKey();
  bool _seedApplied = false, _routeArgsRead = false;
  List<String> _seedIds = [];

  @override
  void initState() {
    super.initState();
    _streetCtrl.addListener(_invalidateSearchLocation);
    unawaited(_reloadSearchTerritories());
    _refreshEntitlements();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _loadForDate(); });
    _fabAnim.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgsRead) return;
    _routeArgsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _seedIds = List<String>.from(args['seedIds'] ?? const []);
      if (args['dateMs'] is int) _selectedDate = DateTime.fromMillisecondsSinceEpoch(args['dateMs'] as int);
      if (_seedIds.isNotEmpty) _searchExpanded = false;
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _streetCtrl.dispose();
    _categoryCtrl.dispose();
    _fabAnim.dispose();
    _listAnim.dispose();
    super.dispose();
  }

  // ════════════ Entitlements ════════════

  Future<void> _refreshEntitlements() async {
    final meter = UsageMeter();
    await meter.initIfNeeded();
    await meter.syncFromCloud();
    final prem = await meter.isPremium();
    final used = await meter.getFreeToursUsed();
    AdService.instance.setPremiumStatus(prem);
    if (!mounted) return;
    setState(() { _isPremium = prem; _freeToursUsed = used; });
    if (prem) {
      _bannerAd?.dispose();
      _bannerAd = null;
      if (mounted) setState(() => _isBannerLoaded = false);
    } else if (_bannerAd == null) {
      _loadBannerAd();
    }
  }

  Future<void> _showPremiumDialog(String message) async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PremiumDialog(message: message),
    );
    if (go == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreditsPaywallPage()),
      );
      await _refreshEntitlements();
    }
  }

  // ════════════ Interactions ════════════

  Future<void> _onToggleProspect(Prospect p, bool? checked) async {
    if (checked != true) {
      setState(() {
        _chosen.remove(p.id);
        _chosenOrder.remove(p.id);
        _smartRouteMetadata = null;
        _dirty = true;
      });
      return;
    }
    if (!_isPremium) {
      final nextCount = _chosen.contains(p.id) ? _chosenOrder.length : _chosenOrder.length + 1;
      if (nextCount > UsageMeter.defaultFreeMaxProspectsPerTour) {
        await _showPremiumDialog(
          "Gratuit : ${UsageMeter.defaultFreeMaxProspectsPerTour} clients max.\nPasse en Premium pour illimité.",
        );
        return;
      }
    }
    setState(() {
      _chosen.add(p.id);
      if (!_chosenOrder.contains(p.id)) _chosenOrder.add(p.id);
      _smartRouteMetadata = null;
      _dirty = true;
    });
  }

  // ════════════ Ads ════════════

  void _loadBannerAd() {
    if (_isPremium) return;
    _isBannerLoaded = false;
    _bannerAd?.dispose();
    _bannerAd = null;
    if (!AdService.instance.canRequestAds) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted && !_isPremium && _bannerAd == null) _loadBannerAd();
      });
      return;
    }
    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerHome,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isBannerLoaded = false;
              _bannerAd = null;
            });
          }
        },
      ),
    )..load();
  }

  // ════════════ Helpers liste ════════════

  void _sortByNumber() {
    final numRx = RegExp(r'^(\d+)\s');
    _allOptions.sort((a, b) {
      final na = int.tryParse(numRx.firstMatch(a.address)?.group(1) ?? '') ?? 1000000000;
      final nb = int.tryParse(numRx.firstMatch(b.address)?.group(1) ?? '') ?? 1000000000;
      return _asc ? na.compareTo(nb) : nb.compareTo(na);
    });
  }

  void _rebuildOptions({bool resetCount = false}) {
    List<Prospect> list;
    if (_showOnlyChosen) {
      final map = {for (final p in _allOptions) p.id: p};
      list = [for (final id in _chosenOrder) if (map[id] != null) map[id]!];
      for (final p in _allOptions) {
        if (_chosen.contains(p.id) && !_chosenOrder.contains(p.id)) list.add(p);
      }
    } else {
      list = List<Prospect>.from(_allOptions);
    }
    if (_showOnlyChosen) {
      _loadedCount = list.length;
    } else {
      if (resetCount) _loadedCount = min(_pageSize, list.length);
      else _loadedCount = min(_loadedCount, list.length);
    }
    _options = list.sublist(0, _loadedCount);
  }

  // ════════════ Chargement date ════════════

  Future<void> _loadForDate() async {
    final int token = ++_fetchToken;
    setState(() {
      _loading = true;
      _directoryNotice = '';
      _directoryDetails = {};
      _searchFeedback = '';
      _allOptions.clear();
      _options.clear();
      _chosen.clear();
      _chosenOrder.clear();
      _smartRouteMetadata = null;
      _loadedCount = 0;
    });
    try {
      final data = await FirestoreService().loadPlanData(_selectedDate);
      final ids  = List<String>.from(data['prospectIds'] ?? []);
      var seeded = false;
      if (!_seedApplied && _seedIds.isNotEmpty) {
        if ((data['assignedBy'] ?? '').toString().isNotEmpty) {
          _showToast('Cette tournée est attribuée. Choisissez une autre date pour ajouter des prospects.');
        } else {
          for (final id in _seedIds) { if (!ids.contains(id)) { ids.add(id); seeded = true; } }
          _seedApplied = true;
        }
      }

      _replanned = Map<String, dynamic>.from(
        (data['replanned'] as Map?) ?? const <String, dynamic>{},
      );
      final savedSmartRoute = data['smartRoute'];
      _smartRouteMetadata = savedSmartRoute is Map
          ? Map<String, dynamic>.from(savedSmartRoute)
          : null;
      _chosen ..clear() ..addAll(ids);
      _chosenOrder ..clear() ..addAll(ids);
      if (ids.isNotEmpty) {
        final saved = await FirestoreService().fetchProspectsByIds(ids);
        _allOptions ..clear() ..addAll(saved);
        _sortByNumber();
        _rebuildOptions(resetCount: true);
        _listAnim.forward(from: 0);
      } else {
        _allOptions.clear(); _options.clear(); _loadedCount = 0;
      }
      _dirty = seeded;
    } finally {
      if (mounted && token == _fetchToken) setState(() => _loading = false);
    }
  }

  // ════════════ Sauvegarde ════════════

  Future<void> _onSave() async {
    final org = context.read<OrgProvider>();
    if (org.isTeam && !org.canPlanAutonomously) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LText(
            'Votre responsable commercial doit activer l’autonomie avant que vous puissiez créer ou modifier une tournée.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final existing  = await FirestoreService().loadPlanData(_selectedDate);
    final hadPlan   = existing.isNotEmpty && (existing['prospectIds'] as List?)?.isNotEmpty == true;
    final isNew     = !hadPlan && _chosen.isNotEmpty;

    if (isNew) {
      final ok = await AccessControl.requireCreateTour(context, prospectCount: _chosenOrder.length);
      if (!ok) return;
    }

    await FirestoreService().savePlan(
      _selectedDate,
      _chosenOrder.toList(),
      _allOptions,
      smartRoute: _smartRouteMetadata,
    );

    var showFreeAdOnHome = false;
    if (isNew) {
      final meter = UsageMeter();
      await meter.initIfNeeded();
      final premium = await meter.isPremium();
      if (!premium) {
        await meter.markFreeTourUsed();
        showFreeAdOnHome = true;
      }
      await meter.pushToCloud();
      await _refreshEntitlements();
    }
    if (!mounted) return;
    setState(() => _dirty = false);

    await showDialog(
      context: context,
      builder: (ctx) => _SaveSuccessDialog(
        date: _selectedDate,
        onContinue: () => Navigator.of(ctx).pop(),
        onMap: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pushNamed(MapPage.routeName);
        },
        onHome: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pushNamedAndRemoveUntil(HomePage.routeName, (_) => false);
          if (showFreeAdOnHome) {
            unawaited(
              Future<void>.delayed(
                const Duration(milliseconds: 450),
                AdService.instance.showInterstitialAtNaturalBreak,
              ),
            );
          }
        },
      ),
    );

    await EngagementTracker.registerTourSaved();
    if (mounted) await EngagementTracker.maybePromptForReview(context);
  }

  Future<bool> _confirmSwitchDate() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: LText('Modifications non enregistrées'.tr()),
        content: LText("Voulez-vous enregistrer avant de changer de date ?".tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: LText('Ignorer'.tr())),
          FilledButton(
            onPressed: () async {
              final org = context.read<OrgProvider>();
              if (org.isTeam && !org.canPlanAutonomously) {
                if (ctx.mounted) Navigator.of(ctx).pop(false);
                return;
              }
              await FirestoreService().savePlan(
                _selectedDate,
                _chosenOrder.toList(),
                _allOptions,
                smartRoute: _smartRouteMetadata,
              );
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            },
            child: LText('Enregistrer'.tr()),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: LText('Annuler'.tr())),
        ],
      ),
    ).then((v) => v == null ? false : true);
  }

  // ════════════ Recherche OSM ════════════

  void _invalidateSearchLocation() {
    if (_searchLocation != null && _streetCtrl.text.trim() != _searchLocation!.label) {
      setState(() {
        _searchLocation = null;
        _targetingExpanded = false;
        _searchExpanded = true;
      });
    }
  }

  Future<void> _reloadSearchTerritories() async {
    if (!_directory.supported) return;
    try {
      final packs = await _directory.backend.installed();
      if (!mounted) return;
      setState(() {
        _installedTerritories = packs.map(directoryTerritoryTitle).toSet().toList()..sort();
        if (!_installedTerritories.contains(_selectedTerritory)) _selectedTerritory = null;
      });
    } catch (_) {
      // A local pack issue must not prevent choosing an address or searching online.
    }
  }

  void _applySearchLocation(ProspectSearchLocation location) {
    setState(() {
      _searchLocation = location;
      _streetCtrl.text = location.label;
      _streetCtrl.selection = TextSelection.collapsed(offset: _streetCtrl.text.length);
      _searchFeedback = '';
      // Progressive UI: validate the zone, close step 2, reveal step 3.
      _searchExpanded = false;
      _targetingExpanded = true;
    });
    // Guide the eye to the next step after geocoding or GPS succeeds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _targetingStepKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeInOutCubic, alignment: 0.12);
      }
    });
  }

  Future<bool> _chooseSearchLocation() async {
    if (_loading || _locating) return false;
    final query = _streetCtrl.text.trim();
    if (query.length < 3) {
      _showToast('Saisissez une adresse, une ville ou un code postal, ou utilisez votre position.', isError: true);
      return false;
    }
    FocusScope.of(context).unfocus();
    setState(() => _locating = true);
    try {
      final options = await _locations.search(query);
      if (!mounted) return false;
      if (options.isEmpty) {
        _showToast('Aucun lieu trouvé. Précisez la rue avec la ville ou le code postal.', isError: true);
        return false;
      }
      final choice = await chooseProspectLocation(context, options,
        isFrench: context.locale.languageCode.startsWith('fr'));
      if (!mounted || choice == null) return false;
      _applySearchLocation(choice);
      return true;
    } catch (error) {
      if (mounted) _showToast('$error', isError: true);
      return false;
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _useSearchPosition() async {
    if (_loading || _locating) return;
    FocusScope.of(context).unfocus();
    setState(() => _locating = true);
    try {
      final location = await _deviceLocation.current();
      if (mounted) _applySearchLocation(location);
    } catch (_) {
      if (mounted) _showToast('Position indisponible ou refusée. Vous pouvez choisir une adresse ou un code postal.', isError: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openDirectory() async {
    final choice = await Navigator.of(context).push<DirectoryUseSelection>(
      MaterialPageRoute(builder: (_) => const DirectoryPage()),
    );
    if (!mounted) return;
    await _reloadSearchTerritories();
    if (!mounted || choice == null) return;
    setState(() {
      _selectedTerritory = directoryTerritoryTitle(choice.pack);
      _searchLocation = null;
      _streetCtrl.clear();
      _allOptions.removeWhere((p) => !_chosen.contains(p.id));
      _directoryDetails.removeWhere((id, _) => !_chosen.contains(id));
      _rebuildOptions(resetCount: true);
      _searchFeedback = '';
      _searchExpanded = true;
      _targetingExpanded = false;
    });
    final seed = choice.seed;
    if (seed != null) {
      _applySearchLocation(ProspectSearchLocation(label: seed.address,
        lat: seed.lat, lon: seed.lon, kind: 'sample'));
      setState(() {
        if (_categoryCtrl.text.trim().isEmpty) _categoryCtrl.text = seed.query;
        _radiusIndex = 3;
      });
    }
    // Loading a territory only prepares the form. The user chooses where and
    // which activities to search before requesting any establishments.
  }

  Future<void> _fetchByZone() async {
    if (_loading || _locating) return;
    if (_searchLocation == null && !await _chooseSearchLocation()) return;
    if (!mounted || _searchLocation == null) return;
    final center = _searchLocation!;
    final street = _streetCtrl.text.trim();
    if (street.isEmpty) return;
    final q = prospectActivityTokens(_categoryCtrl.text).join(', ');
    final radius = _searchRadiiMeters[_radiusIndex];
    final key = '${center.lat}|${center.lon}|${q.toLowerCase()}|$radius';
    final now = DateTime.now();
    if (_lastSearchAt != null &&
        _lastSearchKey == key &&
        now.difference(_lastSearchAt!).inMilliseconds < 1200) {
      return;
    }
    _lastSearchAt = now;
    _lastSearchKey = key;
    final int token = ++_fetchToken;
    final selectedBeforeSearch = _allOptions
        .where((prospect) => _chosen.contains(prospect.id))
        .toList(growable: false);
    final selectedDetailsBeforeSearch = <String, DirectoryRecord>{
      for (final entry in _directoryDetails.entries)
        if (_chosen.contains(entry.key)) entry.key: entry.value,
    };

    setState(() {
      _loading = true;
      _directoryNotice = '';
      _directoryDetails = {};
      _searchFeedback = '';
      _allOptions.clear();
      _options.clear();
      _loadedCount = 0;
    });

    try {
      final languageCode = context.locale.languageCode;
      final geo = OSMGeoPoint(center.lat, center.lon);
      if (!mounted || token != _fetchToken) return;

      DirectoryOnlineSearchResult? onlineResult;
      final directoryResult = await _directory.search(
        lat: geo.lat, lon: geo.lng, query: q, radius: radius,
        fallback: () async {
          final result = await _onlineSearch.searchDetailed(
            lat: geo.lat, lng: geo.lng, query: q,
            radiusMeters: radius, languageCode: languageCode,
          );
          onlineResult = result;
          return result.places;
        },
      );
      if (!mounted || token != _fetchToken) return;
      final results = directoryResult.places;
      _directoryDetails = Map<String, DirectoryRecord>.from(directoryResult.details);
      _directoryNotice = [
        if (!directoryResult.networkUnavailable) directoryResult.notice,
        if (onlineResult?.notice.isNotEmpty == true) onlineResult!.notice,
        if (onlineResult?.failedSources.isNotEmpty == true)
          'Source indisponible : ${onlineResult!.failedSources.join(', ')}. Résultats en ligne partiels.',
      ].where((text) => text.isNotEmpty).join(' ');

      // Construit le résultat hors setState : on évite de muter la liste
      // visible pendant le parsing et on protège l'écran d'une ancienne
      // requête qui terminerait après une recherche plus récente.
      final nextOptions = <Prospect>[
        for (final r in results)
          Prospect(
            id: r.id,
            name: r.name,
            address: r.address,
            lat: r.lat,
            lng: r.lng,
            category: r.category.isEmpty
                ? (q.isEmpty
                    ? (languageCode.startsWith('fr')
                        ? 'Tous les professionnels'
                        : 'All businesses')
                    : q)
                : r.category,
            phone: r.phone,
            email: r.email,
            website: r.website,
            openingHours: r.openingHours,
            instagram: r.instagram,
            facebook: r.facebook,
            linkedin: r.linkedin,
            source: r.source,
            siret: r.siret,
            nafCode: r.nafCode,
          ),
      ];

      // Les nouvelles sélections et les champs privés de l'écran priment sur
      // Firestore, où ces prospects ne sont pas forcément encore enregistrés.
      if (_chosen.isNotEmpty) {
        final existing = await loadSelectedDirectoryProspects(
          selectedIds: _chosen,
          inMemory: selectedBeforeSearch,
          loadMissing: FirestoreService().fetchProspectsByIds,
        );
        if (!mounted || token != _fetchToken) return;
        final selection = preserveDirectorySelection(nextOptions, existing);
        for (final entry in selectedDetailsBeforeSearch.entries) {
          _directoryDetails.putIfAbsent(entry.key, () => entry.value);
        }
        for (final alias in selection.aliases.entries) {
          final details = _directoryDetails[alias.key];
          if (details != null) _directoryDetails[alias.value] = details;
        }
        nextOptions..clear()..addAll(selection.prospects);
      }

      _allOptions
        ..clear()
        ..addAll(nextOptions);
      _sortByNumber();
      _rebuildOptions(resetCount: true);

      final total = results.length;
      if (total > 0) _listAnim.forward(from: 0);

      // On garde la recherche ouverte quand il n'y a aucun résultat afin que
      // l'utilisateur puisse corriger l'adresse, élargir le rayon ou vider la catégorie.
      setState(() {
        _searchExpanded = total == 0;
        _targetingExpanded = total == 0;
      });

      final isFr = context.locale.languageCode.startsWith('fr');
      final message = total == 0
          ? (isFr
              ? 'Aucun résultat dans les sources disponibles. Vérifiez l’adresse, essayez un rayon plus large ou laissez la catégorie vide.'
              : 'No prospects found. Check the address, try a wider radius or leave the category empty.')
          : (isFr
              ? '$total ${total == 1 ? 'résultat trouvé' : 'résultats trouvés'}'
              : '$total ${total == 1 ? 'result found' : 'results found'}');
      if (mounted && token == _fetchToken) {
        setState(() {
          _searchFeedback = directoryResult.networkUnavailable
              ? directoryResult.notice : total == 0 ? message : '';
          _searchFeedbackIsError = directoryResult.networkUnavailable;
        });
        _showToast(message, isError: total == 0);
      }
    } catch (e) {
      if (!mounted || token != _fetchToken) return;
      final isFr = context.locale.languageCode.startsWith('fr');
      final friendly = directorySearchFailureMessage(e, isFrench: isFr);
      setState(() {
        _allOptions..clear()..addAll(selectedBeforeSearch);
        _directoryDetails = selectedDetailsBeforeSearch;
        _sortByNumber();
        _rebuildOptions(resetCount: true);
        _searchFeedback = friendly;
        _searchFeedbackIsError = true;
        _searchExpanded = true;
        _targetingExpanded = true;
      });
      _showToast(friendly, isError: true);
    } finally {
      // Une ancienne requête ne doit jamais éteindre le loader d'une nouvelle.
      if (mounted && token == _fetchToken) {
        setState(() => _loading = false);
      }
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: LText(msg),
      backgroundColor: isError ? _Palette.coral : _Palette.mint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  // ════════════ Optimisation ════════════

  Future<void> _optimizeChosenOrder() async {
    if (_chosenOrder.length <= 1) {
      _showToast('Sélectionnez au moins deux prospects.'.tr());
      return;
    }
    final byId = {for (final p in _allOptions) p.id: p};
    final selected = <Prospect>[
      for (final id in _chosenOrder) if (byId[id] != null) byId[id]!,
    ];
    final selection = await Navigator.of(context).push<SmartRouteSelection>(
      MaterialPageRoute(
        builder: (_) => SmartRoutePage(
          prospects: selected,
          date: _selectedDate,
        ),
      ),
    );
    if (selection == null || selection.orderedIds.isEmpty || !mounted) return;
    setState(() {
      _chosenOrder
        ..clear()
        ..addAll(selection.orderedIds);
      _smartRouteMetadata = selection.metadata;
      // Les prospects non retenus par le planning restent sélectionnés après
      // les visites planifiées afin qu'aucune donnée ne soit perdue.
      for (final id in selected.map((p) => p.id)) {
        if (!_chosenOrder.contains(id)) _chosenOrder.add(id);
      }
      _dirty = true;
      _rebuildOptions(resetCount: true);
    });
    _showToast('Tournée intelligente appliquée ✨');
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * pi / 180.0, p2 = lat2 * pi / 180.0;
    final dp = (lat2 - lat1) * pi / 180.0, dl = (lon2 - lon1) * pi / 180.0;
    final a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ════════════ Sélection rapide ════════════

  bool _isArtisanProspect(Prospect p) {
    final c = p.category.toLowerCase(), n = p.name.toLowerCase();
    const keys = ['artisan','craft','garage','car_repair','plomb','electric','menuis',
      'serrur','peint','chauffag','clim','bât','bat','maçon','macon',
      'carrel','couvreur','toiture','travaux','construction','hardware','doityourself','bricolage','atelier'];
    return keys.any((k) => c.contains(k) || n.contains(k));
  }

  Future<void> _selectAllArtisan() async {
    final artisans = _allOptions.where(_isArtisanProspect).toList();
    if (artisans.isEmpty) { _showToast('Aucun artisan trouvé dans cette liste.'); return; }
    final toAdd = artisans.where((p) => !_chosen.contains(p.id)).toList();
    if (!_isPremium && _chosenOrder.length + toAdd.length > UsageMeter.defaultFreeMaxProspectsPerTour) {
      await _showPremiumDialog("Gratuit : ${UsageMeter.defaultFreeMaxProspectsPerTour} clients max.\nPasse en Premium pour cocher tous les artisans.");
      return;
    }
    setState(() {
      for (final p in toAdd) { _chosen.add(p.id); if (!_chosenOrder.contains(p.id)) _chosenOrder.add(p.id); }
      _smartRouteMetadata = null;
      _dirty = true; _rebuildOptions(resetCount: true);
    });
  }

  Future<void> _toggleSelectAll() async {
    if (_chosen.length == _allOptions.length) {
      setState(() {
        _chosen.clear();
        _chosenOrder.clear();
        _smartRouteMetadata = null;
        _dirty = true;
        _rebuildOptions(resetCount: true);
      });
      return;
    }
    if (!_isPremium && _allOptions.length > UsageMeter.defaultFreeMaxProspectsPerTour) {
      await _showPremiumDialog("Gratuit : ${UsageMeter.defaultFreeMaxProspectsPerTour} clients max.\nPasse en Premium pour 'Tout sélectionner'.");
      return;
    }
    setState(() {
      _chosen ..clear() ..addAll(_allOptions.map((p) => p.id));
      _chosenOrder ..clear() ..addAll(_allOptions.map((p) => p.id));
      _smartRouteMetadata = null;
      _dirty = true; _rebuildOptions(resetCount: true);
    });
  }

  Future<void> _openWeekPlanner() async {
    if (_allOptions.isEmpty) return;
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PlanWeekPage(
        pool: _allOptions, selectedIds: _chosenOrder.toList(), initialStartDate: _selectedDate,
      )),
    );
    if (res == true && mounted) {
      await _loadForDate();
      _showToast('Semaine enregistrée ✅');
    }
  }

  Future<void> _pickDate() async {
    final canSwitch = await _confirmSwitchDate();
    if (!canSwitch) return;
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) {
      setState(() {
        _selectedDate = d; _allOptions.clear(); _options.clear();
        _loadedCount = 0; _showOnlyChosen = false;
      });
      await _loadForDate();
    }
  }

  // ════════════ Sheet détail prospect ════════════

  Future<void> _openProspectSheet(Prospect p) async {
    Future<void> openUrl(String raw) async {
      final uri = Uri.tryParse(raw.trim());
      if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    Future<void> openPhone(String phone) async {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
    Future<void> openEmail(String email) async {
      final uri = Uri(scheme: 'mailto', path: email);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
    Future<void> openMaps() async {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${p.lat},${p.lng}')}');
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProspectSheet(
        prospect: p,
        directoryRecord: _directoryDetails[p.id],
        isChosen: _chosen.contains(p.id),
        onToggle: () async {
          await _onToggleProspect(p, !_chosen.contains(p.id));
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
        onMaps: openMaps,
        onPhone: (p.phone?.trim().isNotEmpty == true) ? () => openPhone(p.phone!.trim()) : null,
        onEmail: (p.email?.trim().isNotEmpty == true) ? () => openEmail(p.email!.trim()) : null,
        onWeb: (p.website?.trim().isNotEmpty == true) ? () => openUrl(p.website!.trim()) : null,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme    = context.watch<ThemeProvider>().currentTheme;
    final isDark   = theme.brightness == Brightness.dark;
    final size     = MediaQuery.of(context).size;
    final isTablet = size.shortestSide >= 600;
    final maxW     = size.width >= 1024 ? 900.0 : (isTablet ? 720.0 : 560.0);

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: _Palette.auroraGrad.colors,
        blurSigma: 14,
        animate: !_loading,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(isDark, theme),
          bottomNavigationBar: _buildBottomBar(theme),
          body: SafeArea(
            top: true,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              // ── Bandeau FREE
                              if (!_isPremium) ...[
                                _FreeBanner(
                                  usedTours: _freeToursUsed,
                                  maxProspects: UsageMeter.defaultFreeMaxProspectsPerTour,
                                  maxTours: UsageMeter.defaultFreeMaxTours,
                                  onUpgrade: () => _showPremiumDialog("Débloque illimité + sans pub."),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // ── 1. Planifier : today is already selected by default.
                              _StepCard(
                                step: 1,
                                title: context.locale.languageCode.startsWith('fr')
                                    ? 'Planifier la date' : 'Plan the date',
                                icon: Icons.calendar_today_rounded,
                                completed: true,
                                child: _DatePickerRow(
                                  date: _selectedDate,
                                  onTap: _pickDate,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // ── 2. Zone : no directory, pack or source details.
                              _StepCard(
                                step: 2,
                                title: context.locale.languageCode.startsWith('fr')
                                    ? 'Zone de prospection' : 'Prospecting area',
                                icon: Icons.radar_rounded,
                                completed: _searchLocation != null,
                                subtitle: !_searchExpanded ? _searchLocation?.label : null,
                                trailing: _CollapseToggle(
                                  expanded: _searchExpanded,
                                  onToggle: () => setState(
                                      () => _searchExpanded = !_searchExpanded),
                                ),
                                child: AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOutCubic,
                                  child: _searchExpanded
                                      ? _guidedSearchForm(showZone: true, showTargeting: false)
                                      : const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // ── 3. Activity + radius remain optional; grey until zone verified.
                              _StepCard(
                                key: _targetingStepKey,
                                step: 3,
                                title: context.locale.languageCode.startsWith('fr')
                                    ? 'Activités et rayon' : 'Business types & radius',
                                icon: Icons.tune_rounded,
                                enabled: _searchLocation != null,
                                subtitle: _searchLocation == null
                                    ? (context.locale.languageCode.startsWith('fr')
                                        ? 'Choisissez une zone pour continuer'
                                        : 'Choose an area to continue')
                                    : (!_targetingExpanded
                                        ? _targetingSummary(context.locale.languageCode.startsWith('fr'))
                                        : null),
                                trailing: _searchLocation == null
                                    ? const Icon(Icons.lock_outline_rounded,
                                        size: 19, color: Colors.grey)
                                    : _CollapseToggle(
                                        expanded: _targetingExpanded,
                                        onToggle: () => setState(() =>
                                            _targetingExpanded = !_targetingExpanded),
                                      ),
                                child: AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOutCubic,
                                  child: _searchLocation != null && _targetingExpanded
                                      ? _guidedSearchForm(showZone: false, showTargeting: true)
                                      : const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(height: 10),

                              if (_directoryNotice.isNotEmpty &&
                                  (_directoryNotice.toLowerCase().contains('indisponible') ||
                                   _directoryNotice.toLowerCase().contains('incomplet') ||
                                   _directoryNotice.toLowerCase().contains('source indisponible'))) Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ProspectInfoChip(
                                  key: const Key('search-sources-info'),
                                  label: _directoryNotice.toLowerCase().contains('partiel') ||
                                      _directoryNotice.toLowerCase().contains('indisponible')
                                      ? (context.locale.languageCode.startsWith('fr')
                                          ? 'Résultats partiels' : 'Partial results')
                                      : (context.locale.languageCode.startsWith('fr')
                                          ? 'Sources des résultats' : 'Result sources'),
                                  icon: Icons.info_outline_rounded,
                                  tone: _directoryNotice.toLowerCase().contains('partiel') ||
                                      _directoryNotice.toLowerCase().contains('indisponible')
                                      ? ProspectInfoTone.caution : ProspectInfoTone.online,
                                  details: prospectSearchSourceExplanation(
                                    _directoryNotice,
                                    isFrench: context.locale.languageCode.startsWith('fr'),
                                  ),
                                ),
                              ),
                              if (_searchFeedback.isNotEmpty) OSMSearchFeedback(
                                message: _searchFeedback,
                                isError: _searchFeedbackIsError,
                                onRetry: _searchFeedbackIsError ? _fetchByZone : null,
                              ),

                              if (_smartRouteMetadata != null && _chosenOrder.isNotEmpty) ...[
                                _SavedSmartRouteCard(
                                  metadata: _smartRouteMetadata!,
                                  onRecalculate: _optimizeChosenOrder,
                                ),
                                const SizedBox(height: 10),
                              ],

                              // ── Placeholder vide
                              if (!_loading && _allOptions.isEmpty && _searchFeedback.isEmpty)
                                _EmptyState(onSearch: _fetchByZone),

                              // ── Étape 4 : Sélection des clients (après activité et rayon)
                              if (!_loading && _allOptions.isNotEmpty) ...[
                                _StepCard(
                                  step: 4,
                                  title: context.locale.languageCode.startsWith('fr')
                                      ? 'Sélectionner les clients'
                                      : 'Select customers',
                                  icon: Icons.checklist_rounded,
                                  child: _ResultsToolbar(
                                    pageSize: _pageSize,
                                    asc: _asc,
                                    chosen: _chosen.length,
                                    total: _allOptions.length,
                                    showOnlyChosen: _showOnlyChosen,
                                    dirty: _dirty,
                                    onPageSize: (n) { if (n == null) return; setState(() { _pageSize = n; _rebuildOptions(resetCount: true); }); },
                                    onToggleSort: () => setState(() { _asc = !_asc; _sortByNumber(); _rebuildOptions(resetCount: true); }),
                                    onToggleSelectAll: _toggleSelectAll,
                                    onToggleFilter: () => setState(() { _showOnlyChosen = !_showOnlyChosen; _rebuildOptions(resetCount: true); }),
                                    onSelectArtisan: _selectAllArtisan,
                                    onWeekPlanner: _openWeekPlanner,
                                    onSave: _dirty ? _onSave : null,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              // ── Liste prospects
                              if (!_loading && _options.isNotEmpty)
                                _ProspectList(
                                  options: _options,
                                  chosen: _chosen,
                                  chosenOrder: _chosenOrder,
                                  replanned: _replanned,
                                  showOnlyChosen: _showOnlyChosen,
                                  listAnim: _listAnim,
                                  onToggle: _onToggleProspect,
                                  onMore: _openProspectSheet,
                                  onReorder: (oldIndex, newIndex) {
                                    setState(() {
                                      if (newIndex > oldIndex) newIndex -= 1;
                                      final moved = _options.removeAt(oldIndex);
                                      _options.insert(newIndex, moved);
                                      _chosenOrder ..clear() ..addAll(_options.map((p) => p.id));
                                      _smartRouteMetadata = null;
                                      _dirty = true;
                                    });
                                  },
                                ),

                              // ── Charger plus
                              if (!_loading && _options.length < (_showOnlyChosen
                                  ? _allOptions.where((p) => _chosen.contains(p.id)).length
                                  : _allOptions.length))
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _GradientButton(
                                    label: 'Charger $_pageSize de plus',
                                    icon: Icons.expand_more_rounded,
                                    onTap: () => setState(() { _loadedCount += _pageSize; _rebuildOptions(); }),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loading) const _LoadingOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════ AppBar ══════

  PreferredSizeWidget _buildAppBar(bool isDark, ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 8,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.white.withOpacity(isDark ? 0.05 : 0.30)),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: _Palette.primaryGrad,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.route_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LText(
              'Prospection',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18,
                color: isDark ? _Palette.onDark : _Palette.onLight,
              ),
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        _AppBarAction(
          icon: Icons.save_rounded,
          badge: _dirty,
          tooltip: 'Enregistrer'.tr(),
          onTap: _onSave,
        ),
        _AppBarAction(
          icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          tooltip: 'Thème'.tr(),
          onTap: () => context.read<ThemeProvider>().toggleTheme(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ══════ Bottom bar ══════

  Widget _buildBottomBar(ThemeData theme) {
    final selected = _chosenOrder.length;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AdBanner
          if (!_isPremium && _isBannerLoaded && _bannerAd != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),

          // Barre d'action principale
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.25), width: 0.8)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    // Compteur sélection
                    _SelectionBadge(count: selected, dirty: _dirty),
                    const SizedBox(width: 12),
                    // Bouton enregistrer
                    Expanded(
                      child: _GradientButton(
                        label: 'Enregistrer'.tr(),
                        icon: Icons.save_rounded,
                        onTap: _dirty ? _onSave : null,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Filtrer cochés
                    _GlassIconButton(
                      icon: _showOnlyChosen ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
                      tooltip: 'Filtrer cochés'.tr(),
                      active: _showOnlyChosen,
                      onTap: selected == 0 ? null : () => setState(() {
                        _showOnlyChosen = !_showOnlyChosen;
                        _rebuildOptions(resetCount: true);
                      }),
                    ),
                    const SizedBox(width: 8),
                    // Carte
                    _GlassIconButton(
                      icon: Icons.map_rounded,
                      tooltip: 'Carte'.tr(),
                      primary: true,
                      onTap: selected == 0 ? null : () => Navigator.of(context).pushNamed(MapPage.routeName),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _targetingSummary(bool isFrench) {
    final n = prospectActivityTokens(_categoryCtrl.text).length;
    const distances = ['500 m', '1 km', '2 km', '5 km', '10 km'];
    final activityLabel = isFrench
        ? (n == 0 ? 'Toutes activités' : n == 1 ? '1 activité' : '$n activités')
        : (n == 0 ? 'All types' : n == 1 ? '1 type' : '$n types');
    return '$activityLabel · ${distances[_radiusIndex]}';
  }

  // The two screens share the exact same controllers and search callbacks.
  // This only splits presentation; no search engine or local/online logic changes.
  Widget _guidedSearchForm({required bool showZone, required bool showTargeting}) {
    return ProspectSearchForm(
      showZone: showZone,
      showTargeting: showTargeting,
      addressController: _streetCtrl,
      activityController: _categoryCtrl,
      ownDirectory: ProspectoDirectoryApi.configuredUrl.isNotEmpty,
      quickActivities: (context.locale.languageCode.startsWith('fr')
              ? _quickKeywordsFr : _quickKeywordsEn)
          .map((item) => ProspectoDirectoryApi.configuredUrl.isEmpty
              ? item : item == 'chantier' ? 'artisan'
                  : item == 'construction' ? 'craftsman' : item).toList(),
      radiusIndex: _radiusIndex,
      onRadiusChanged: (v) => setState(() => _radiusIndex = v),
      onActivityToggle: _appendKeyword,
      onSearch: _fetchByZone,
      onOptimize: _optimizeChosenOrder,
      busy: _loading,
      locating: _locating,
      isFrench: context.locale.languageCode.startsWith('fr'),
      offlineSupported: _directory.supported,
      installedTerritories: _installedTerritories,
      selectedTerritory: _selectedTerritory,
      selectedLocation: _searchLocation?.label,
      onChooseAddress: _chooseSearchLocation,
      onUsePosition: _useSearchPosition,
      onManageTerritories: _openDirectory,
    );
  }

  void _appendKeyword(String kw) {
    final normKw = kw.trim();
    if (normKw.isEmpty) return;
    final next = toggleProspectActivity(_categoryCtrl.text, normKw);
    setState(() {
      _categoryCtrl.text = next;
      _categoryCtrl.selection = TextSelection.collapsed(offset: _categoryCtrl.text.length);
    });
  }
}


// ════════════════════════════════════════════════════════════════
//  Widgets composants 2026
// ════════════════════════════════════════════════════════════════

// ── Carte étape avec glassmorphism
class _StepCard extends StatelessWidget {
  final int     step;
  final String  title;
  final IconData icon;
  final Widget  child;
  final Widget? trailing;
  final bool enabled, completed;
  final String? subtitle;

  const _StepCard({
    super.key,
    required this.step, required this.title, required this.icon,
    required this.child, this.trailing,
    this.enabled = true, this.completed = false, this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: !enabled
                ? (isDark ? Colors.white.withOpacity(0.035) : Colors.grey.shade200.withOpacity(0.65))
                : (isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.75)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StepPill(step: step, enabled: enabled, completed: completed),
                    const SizedBox(width: 10),
                    Icon(icon, size: 18,
                      color: enabled ? _Palette.indigo : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LText(title, style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15,
                        color: !enabled ? Colors.grey : (isDark ? _Palette.onDark : _Palette.onLight),
                      )),
                    ),
                    if (completed) ...[
                      const Icon(Icons.check_circle_rounded,
                        color: ProspectoColors.green, size: 19),
                      const SizedBox(width: 6),
                    ],
                    if (trailing != null) trailing!,
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 44, top: 4),
                    child: Text(subtitle!, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: enabled
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Colors.grey)),
                  ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pill numéro d'étape
class _StepPill extends StatelessWidget {
  final int step;
  final bool enabled, completed;
  const _StepPill({required this.step,
    this.enabled = true, this.completed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        gradient: enabled ? _Palette.primaryGrad : null,
        color: enabled ? null : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
        boxShadow: enabled ? [BoxShadow(color: _Palette.indigo.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 4))] : const [],
      ),
      alignment: Alignment.center,
      child: LText('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
    );
  }
}

// ── Toggle collapse
class _CollapseToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  const _CollapseToggle({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedRotation(
        turns: expanded ? 0 : 0.5,
        duration: const Duration(milliseconds: 250),
        child: Icon(Icons.keyboard_arrow_up_rounded,
            color: _Palette.indigo.withOpacity(0.7)),
      ),
    );
  }
}

// ── Bouton gradient principal
class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool compact;

  const _GradientButton({
    required this.label, required this.icon, this.onTap, this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: compact ? 46 : 50,
          decoration: BoxDecoration(
            gradient: enabled
                ? _Palette.primaryGrad
                : const LinearGradient(colors: [Color(0xFF9099C4), Color(0xFF9099C4)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [BoxShadow(color: _Palette.indigo.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: LText(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bouton icône glass
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final bool primary;

  const _GlassIconButton({
    required this.icon, required this.tooltip,
    this.onTap, this.active = false, this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    Color bg, iconColor;
    if (primary) { bg = _Palette.indigo; iconColor = Colors.white; }
    else if (active) { bg = _Palette.indigo.withOpacity(0.18); iconColor = _Palette.indigo; }
    else { bg = Colors.white.withOpacity(0.22); iconColor = Colors.black54; }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.38,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

// ── AppBar action
class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool badge;
  const _AppBarAction({required this.icon, required this.tooltip, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onTap),
        if (badge)
          Positioned(
            right: 8, top: 8,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: _Palette.coral, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _Palette.coral.withOpacity(0.5), blurRadius: 4)]),
            ),
          ),
      ],
    );
  }
}

// ── Bandeau FREE
class _FreeBanner extends StatelessWidget {
  final int usedTours, maxProspects, maxTours;
  final VoidCallback onUpgrade;
  const _FreeBanner({required this.usedTours, required this.maxProspects, required this.maxTours, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final remaining = (maxTours - usedTours).clamp(0, maxTours);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_Palette.amber.withOpacity(0.2), _Palette.coral.withOpacity(0.15)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.amber.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: _Palette.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LText(
                  'Version gratuite',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                LText(
                  '$maxProspects clients max · $remaining tournée${remaining > 1 ? 's' : ''} dispo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_Palette.amber, _Palette.coral]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const LText('Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Picker date inline
class _DatePickerRow extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DatePickerRow({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _Palette.indigo.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Palette.indigo.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: _Palette.indigo, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: AutoSizeText(
                  DateFormat.yMMMMEEEEd(locale).format(date),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1, minFontSize: 12,
                ),
              ),
              Icon(Icons.edit_calendar_rounded, color: _Palette.indigo.withOpacity(0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toolbar résultats
class _ResultsToolbar extends StatelessWidget {
  final int pageSize, chosen, total;
  final bool asc, showOnlyChosen, dirty;
  final ValueChanged<int?> onPageSize;
  final VoidCallback onToggleSort, onToggleSelectAll, onToggleFilter, onSelectArtisan, onWeekPlanner;
  final VoidCallback? onSave;

  const _ResultsToolbar({
    required this.pageSize, required this.chosen, required this.total,
    required this.asc, required this.showOnlyChosen, required this.dirty,
    required this.onPageSize, required this.onToggleSort, required this.onToggleSelectAll,
    required this.onToggleFilter, required this.onSelectArtisan, required this.onWeekPlanner,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne 1 : compteur + tri + pagination
          Row(
            children: [
              LText(
                // The toolbar counts discovered results; the footer counts selected customers.
                Localizations.localeOf(context).languageCode.startsWith('fr')
                    ? '$total résultat${total > 1 ? 's' : ''}'
                    : '$total result${total == 1 ? '' : 's'}',
                style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 16,
                  foreground: Paint()..shader = _Palette.primaryGrad.createShader(const Rect.fromLTWH(0, 0, 80, 20)),
                ),
              ),
              const Spacer(),
              // Tri
              GestureDetector(
                onTap: onToggleSort,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _Palette.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 16, color: _Palette.indigo),
                      const SizedBox(width: 4),
                      LText('N°', style: TextStyle(color: _Palette.indigo, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Page size
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: _Palette.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<int>(
                  value: pageSize,
                  underline: const SizedBox(),
                  style: TextStyle(color: _Palette.indigo, fontWeight: FontWeight.w700, fontSize: 13),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: [20, 50].map((n) => DropdownMenuItem(value: n, child: LText('$n'))).toList(),
                  onChanged: onPageSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Ligne 2 : actions rapides
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _ActionPill(
                icon: chosen == total ? Icons.deselect_rounded : Icons.select_all_rounded,
                label: chosen == total ? 'Tout décocher' : 'Tout sélectionner',
                onTap: onToggleSelectAll,
              ),
              _ActionPill(
                icon: Icons.engineering_rounded,
                label: 'Artisans',
                onTap: onSelectArtisan,
              ),
              _ActionPill(
                icon: Icons.calendar_month_rounded,
                label: 'Semaine',
                onTap: onWeekPlanner,
              ),
              _ActionPill(
                icon: showOnlyChosen ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
                label: showOnlyChosen ? 'Tout voir' : 'Cochés seuls',
                active: showOnlyChosen,
                onTap: onToggleFilter,
              ),
            ],
          ),
          // Bandeau non-sauvegardé
          if (dirty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _Palette.coral.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _Palette.coral.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: _Palette.coral, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: LText('Modifications non enregistrées', style: TextStyle(color: _Palette.coral, fontWeight: FontWeight.w600, fontSize: 13))),
                  if (onSave != null)
                    GestureDetector(
                      onTap: onSave,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _Palette.coral, borderRadius: BorderRadius.circular(8)),
                        child: const LText('Sauver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Pill d'action
class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  const _ActionPill({required this.icon, required this.label, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _Palette.indigo.withOpacity(0.18) : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _Palette.indigo.withOpacity(0.45) : Colors.white.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? _Palette.indigo : _Palette.onLightSub),
            const SizedBox(width: 5),
            LText(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: active ? _Palette.indigo : _Palette.onLightSub)),
          ],
        ),
      ),
    );
  }
}

// ── Badge sélection
class _SelectionBadge extends StatelessWidget {
  final int count;
  final bool dirty;
  const _SelectionBadge({required this.count, required this.dirty});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: count > 0 ? _Palette.primaryGrad : null,
        color: count == 0 ? Colors.white.withOpacity(0.25) : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: count > 0
            ? [BoxShadow(color: _Palette.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_rounded, size: 18, color: count > 0 ? Colors.white : Colors.black38),
          const SizedBox(width: 6),
          LText(
            Localizations.localeOf(context).languageCode.startsWith('fr')
                ? '$count coché${count > 1 ? 's' : ''}'
                : '$count selected',
            style: TextStyle(
              color: count > 0 ? Colors.white : Colors.black38,
              fontWeight: FontWeight.w900, fontSize: 14,
            ),
          ),
          if (dirty) ...[
            const SizedBox(width: 6),
            Container(width: 7, height: 7,
                decoration: BoxDecoration(color: _Palette.coral, shape: BoxShape.circle)),
          ],
        ],
      ),
    );
  }
}

// ── Empty state
class _EmptyState extends StatelessWidget {
  final VoidCallback onSearch;
  const _EmptyState({required this.onSearch});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: ProspectInfoChip(
      label: Localizations.localeOf(context).languageCode.startsWith('fr')
          ? 'Prêt pour la recherche' : 'Ready to search',
      icon: Icons.lightbulb_outline_rounded,
      details: Localizations.localeOf(context).languageCode.startsWith('fr')
          ? 'Choisissez un lieu, une ou plusieurs activités et un rayon, puis appuyez sur « Rechercher les professionnels ».'
          : 'Choose a location, business types and a radius, then tap « Find businesses ». ',
    ),
  );
}

// ── Liste prospects avec animations
class _ProspectList extends StatelessWidget {
  final List<Prospect> options;
  final Set<String> chosen;
  final List<String> chosenOrder;
  final Map<String, dynamic> replanned;
  final bool showOnlyChosen;
  final AnimationController listAnim;
  final Future<void> Function(Prospect, bool?) onToggle;
  final Future<void> Function(Prospect) onMore;
  final void Function(int, int) onReorder;

  const _ProspectList({
    required this.options, required this.chosen, required this.chosenOrder,
    required this.replanned, required this.showOnlyChosen, required this.listAnim,
    required this.onToggle, required this.onMore, required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.75)),
          ),
          child: showOnlyChosen
              ? ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: true,
            itemCount: options.length,
            onReorder: onReorder,
            itemBuilder: (_, i) {
              final p = options[i];
              return _ProspectTile(
                key: ValueKey('p_${p.id}'),
                prospect: p,
                selected: chosen.contains(p.id),
                replanned: replanned[p.id],
                showDrag: true,
                index: i,
                onToggle: (v) => onToggle(p, v),
                onMore: () => onMore(p),
              );
            },
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.length,
            separatorBuilder: (_, __) => Divider(height: 0, color: Colors.white.withOpacity(0.3)),
            itemBuilder: (_, i) {
              final p = options[i];
              return _ProspectTile(
                key: ValueKey('p_${p.id}'),
                prospect: p,
                selected: chosen.contains(p.id),
                replanned: replanned[p.id],
                showDrag: false,
                index: i,
                onToggle: (v) => onToggle(p, v),
                onMore: () => onMore(p),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Tuile prospect redesignée
class _ProspectTile extends StatelessWidget {
  final Prospect prospect;
  final bool selected, showDrag;
  final dynamic replanned;
  final int index;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onMore;

  const _ProspectTile({
    super.key, required this.prospect, required this.selected,
    required this.replanned, required this.showDrag, required this.index,
    required this.onToggle, required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onMore,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: selected
            ? _Palette.indigo.withOpacity(isDark ? 0.18 : 0.07)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Checkbox stylisée
            GestureDetector(
              onTap: () => onToggle(!selected),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24, height: 24,
                decoration: BoxDecoration(
                  gradient: selected ? _Palette.primaryGrad : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected ? Colors.transparent : _Palette.onLightSub.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: _Palette.indigo.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                      : [],
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    prospect.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14,
                      color: isDark ? _Palette.onDark : _Palette.onLight,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  LText(
                    prospect.address,
                    style: TextStyle(fontSize: 12, color: isDark ? _Palette.onDarkSub : _Palette.onLightSub),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  if (prospect.category.isNotEmpty || replanned != null) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 5, runSpacing: 4, children: [
                      if (prospect.category.isNotEmpty)
                        _MiniChip(label: prospect.category, color: _Palette.indigo),
                      if (replanned != null && replanned is Map && replanned['from'] != null)
                        _MiniChip(label: 'Replanifié', color: _Palette.mint, icon: Icons.redo_rounded),
                    ]),
                  ],
                ],
              ),
            ),
            // Actions
            Row(
              children: [
                GestureDetector(
                  onTap: onMore,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.more_horiz_rounded, size: 18,
                        color: isDark ? _Palette.onDarkSub : _Palette.onLightSub),
                  ),
                ),
                if (showDrag) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.drag_handle_rounded, color: _Palette.onLightSub.withOpacity(0.4)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini chip
class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _MiniChip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 3)],
          LText(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ── Sheet détail prospect
class _ProspectSheet extends StatelessWidget {
  final Prospect prospect;
  final DirectoryRecord? directoryRecord;
  final bool isChosen;
  final VoidCallback onToggle, onMaps;
  final VoidCallback? onPhone, onEmail, onWeb;

  const _ProspectSheet({
    required this.prospect, required this.isChosen,
    required this.onToggle, required this.onMaps,
    this.onPhone, this.onEmail, this.onWeb, this.directoryRecord,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.65) : Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: LText(prospect.name,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LText(prospect.address,
                      style: TextStyle(color: isDark ? _Palette.onDarkSub : _Palette.onLightSub, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  if (prospect.category.isNotEmpty)
                    _MiniChip(label: prospect.category, color: _Palette.indigo),
                  const SizedBox(height: 16),
                  if (directoryRecord != null) ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .32),
                    child: SingleChildScrollView(child: DirectoryDetails(record: directoryRecord!)),
                  ),
                  // Actions liens
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _SheetAction(label: 'Maps', icon: Icons.place_rounded, color: _Palette.indigo, onTap: onMaps),
                      if (onPhone != null) _SheetAction(label: 'Appeler', icon: Icons.call_rounded, color: _Palette.mint, onTap: onPhone!),
                      if (onEmail != null) _SheetAction(label: 'Email', icon: Icons.email_rounded, color: _Palette.sky, onTap: onEmail!),
                      if (onWeb != null) _SheetAction(label: 'Site', icon: Icons.public_rounded, color: _Palette.violet, onTap: onWeb!),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Toggle sélection
                  GestureDetector(
                    onTap: onToggle,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: isChosen
                            ? LinearGradient(colors: [_Palette.coral.withOpacity(0.8), _Palette.coral])
                            : _Palette.primaryGrad,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: (isChosen ? _Palette.coral : _Palette.indigo).withOpacity(0.3),
                          blurRadius: 12, offset: const Offset(0, 5),
                        )],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isChosen ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: LText(
                              isChosen ? 'Retirer de la sélection' : 'Ajouter à la tournée',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sheet action button
class _SheetAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SheetAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            LText(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Dialog sauvegarde
class _SaveSuccessDialog extends StatelessWidget {
  final DateTime date;
  final VoidCallback onContinue, onMap, onHome;
  const _SaveSuccessDialog({required this.date, required this.onContinue, required this.onMap, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(gradient: _Palette.primaryGrad, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: LText('Plan sauvegardé', style: TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: LText(
        'Le plan du ${DateFormat.yMd().format(date)} a été mis à jour avec succès.',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      actions: [
        TextButton(onPressed: onContinue, child: const LText('Continuer')),
        OutlinedButton.icon(onPressed: onMap, icon: const Icon(Icons.map_rounded, size: 16), label: const LText('Carte')),
        FilledButton(onPressed: onHome, child: const LText('Accueil')),
      ],
    );
  }
}

// ── Dialog Premium

class _SavedSmartRouteCard extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final VoidCallback onRecalculate;

  const _SavedSmartRouteCard({
    required this.metadata,
    required this.onRecalculate,
  });

  @override
  Widget build(BuildContext context) {
    final stops = (metadata['stops'] as List?)?.length ?? 0;
    final distanceMeters = (metadata['totalDistanceMeters'] as num?)?.toInt() ?? 0;
    final travelSeconds = (metadata['totalTravelSeconds'] as num?)?.toInt() ?? 0;
    final live = metadata['usedLiveTraffic'] == true;
    final unscheduled = (metadata['unscheduledProspectIds'] as List?)?.length ?? 0;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.55),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LText(
                    'Tournée intelligente sauvegardée',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  LText(
                    '$stops visites · ${(distanceMeters / 1000).toStringAsFixed(1)} km · '
                    '${(travelSeconds / 60).round()} min de route',
                  ),
                  LText(
                    live
                        ? 'Estimation locale${unscheduled > 0 ? ' · $unscheduled non planifié(s)' : ''}'
                        : 'Estimation locale gratuite${unscheduled > 0 ? ' · $unscheduled non planifié(s)' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Recalculer la tournée'.tr(),
              onPressed: onRecalculate,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumDialog extends StatelessWidget {
  final String message;
  const _PremiumDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_Palette.amber, _Palette.coral]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: LText('Version gratuite', style: TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: LText(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const LText('Plus tard')),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_Palette.amber, _Palette.coral]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const LText('Débloquer Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

// ── Loading overlay
class _LoadingOverlay extends StatefulWidget {
  const _LoadingOverlay();
  @override
  State<_LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<_LoadingOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _rot = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() { _rot.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          color: Colors.black.withOpacity(0.22),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(
                        turns: _rot,
                        child: Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(gradient: _Palette.primaryGrad, shape: BoxShape.circle),
                          child: const Icon(Icons.radar_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const LText('Recherche en cours…',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation(_Palette.indigo),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
