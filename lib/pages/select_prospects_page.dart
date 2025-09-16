// lib/pages/select_prospects_page.dart
// Sélection d'établissements — UI 2025 : fond brand, cartes glass, boutons gradient.

import 'dart:convert';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;

import '../models/prospect.dart';
import '../providers/theme_provider.dart';
import '../services/api_keys.dart';
import '../services/firestore_service.dart';

// fond gradient cohérent avec Login/Home
import '../widgets/brand_background.dart';
// micro-interaction
import '../ui/bling.dart';

class SelectProspectsPage extends StatefulWidget {
  static const routeName = '/select';
  const SelectProspectsPage({Key? key}) : super(key: key);

  @override
  State<SelectProspectsPage> createState() => _SelectProspectsPageState();
}

class _SelectProspectsPageState extends State<SelectProspectsPage> {
  // Contrôleurs
  final _streetCtrl   = TextEditingController(text: 'Saint-Antoine, 13015 Marseille');
  final _categoryCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Pagination & tri
  int  _pageSize    = 20;
  int  _loadedCount = 0;
  bool _asc         = true;

  final List<Prospect> _allOptions = [];
  List<Prospect>       _options    = [];
  final Set<String>    _chosen     = {};

  // État & AdMob
  bool _loading = false;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  final String _apiKey = getGoogleMapsApiKey();

  @override
  void initState() {
    super.initState();
    _loadForDate();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _streetCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId : 'ca-app-pub-1360261396564293/1162631714',
      request  : const AdRequest(),
      size     : AdSize.banner,
      listener : BannerAdListener(
        onAdLoaded      : (_) => setState(() => _isBannerLoaded = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  /// Charge les IDs cochés pour la date sélectionnée
  Future<void> _loadForDate() async {
    setState(() => _loading = true);
    try {
      final data = await FirestoreService().loadPlanData(_selectedDate);
      final ids  = List<String>.from(data['prospectIds'] ?? []);
      _chosen
        ..clear()
        ..addAll(ids);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Sauvegarde le plan en Firestore
  Future<void> _onSave() async {
    await FirestoreService().savePlan(_selectedDate, _chosen.toList(), _allOptions);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Plan sauvegardé'.tr()),
        content: Text('Le plan du {0} a été mis à jour avec succès.'.tr(
          args: [DateFormat.yMd().format(_selectedDate)],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Continuer la sélection'.tr()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamed('/map'); // Vers map_page.dart
            },
            child: Text('Aller à la carte'.tr()),
          ),
        ],
      ),
    );
  }

  /// Récupère jusqu’à 3 pages de résultats Places TextSearch
  Future<List<Map<String, dynamic>>> _fetchAllPages(Uri firstPage) async {
    Uri? url = firstPage;
    final pages = <Map<String, dynamic>>[];
    while (url != null && pages.length < 3) {
      final resp = await http.get(url);
      final json = jsonDecode(resp.body);
      if (json['status'] != 'OK' && json['status'] != 'ZERO_RESULTS') break;
      pages.add(json);
      final token = json['next_page_token'];
      if (token != null) {
        await Future.delayed(const Duration(seconds: 2));
        url = Uri.https(
          'maps.googleapis.com',
          '/maps/api/place/textsearch/json',
          {'pagetoken': token, 'key': _apiKey},
        );
      } else {
        url = null;
      }
    }
    return pages;
  }

  /// Géocode + TextSearch
  Future<void> _fetchByZone() async {
    final street = _streetCtrl.text.trim();
    final cat    = _categoryCtrl.text.trim();
    if (street.isEmpty) return;

    setState(() {
      _loading     = true;
      _allOptions.clear();
      _options.clear();
      _loadedCount = 0;
    });

    try {
      // 1) Géocode
      final geoResp = await http.get(Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {'address': street, 'key': _apiKey},
      ));
      final geoJson = jsonDecode(geoResp.body);
      if (geoJson['status'] != 'OK') throw 'Géocodage échoué';
      final loc = geoJson['results'][0]['geometry']['location'];
      final lat = (loc['lat'] as num).toDouble();
      final lng = (loc['lng'] as num).toDouble();

      // 2) TextSearch
      final query = cat.isEmpty ? street : '$cat in $street';
      final firstPage = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/textsearch/json',
        {
          'query'   : query,
          'location': '$lat,$lng',
          'radius'  : '1500',
          'key'     : _apiKey,
        },
      );
      final pages = await _fetchAllPages(firstPage);

      for (final page in pages) {
        for (final e in page['results']) {
          final geo = e['geometry']['location'];
          _allOptions.add(Prospect(
            id      : e['place_id'],
            name    : e['name'],
            address : e['formatted_address'] ?? e['vicinity'] ?? '',
            lat     : (geo['lat'] as num).toDouble(),
            lng     : (geo['lng'] as num).toDouble(),
            category: cat.isEmpty ? 'tous' : cat,
          ));
        }
      }

      // 3) Ré-intègre les anciens cochés hors résultat
      final missing = _chosen.where((id) => !_allOptions.any((p) => p.id == id));
      if (missing.isNotEmpty) {
        final existing = await FirestoreService().fetchProspectsByIds(missing.toList());
        _allOptions.addAll(existing);
      }

      // tri et pagination
      _sortByNumber();
      _loadedCount = min(_pageSize, _allOptions.length);
      _options     = _allOptions.sublist(0, _loadedCount);

      // ✅ pas de .tr() sur la chaîne dynamique pour éviter "key not found"
      final total = _allOptions.length;
      final isFr  = context.locale.languageCode.startsWith('fr');
      final word  = isFr ? (total <= 1 ? 'résultat' : 'résultats')
          : (total <= 1 ? 'result'   : 'results');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$total $word')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _sortByNumber() {
    final numRx = RegExp(r'^(\d+)\s');
    _allOptions.sort((a, b) {
      final na = int.tryParse(numRx.firstMatch(a.address)?.group(1) ?? '') ?? 1000000000;
      final nb = int.tryParse(numRx.firstMatch(b.address)?.group(1) ?? '') ?? 1000000000;
      return _asc ? na.compareTo(nb) : nb.compareTo(na);
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context    : context,
      initialDate: _selectedDate,
      firstDate  : DateTime.now().subtract(const Duration(days: 30)),
      lastDate   : DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) {
      setState(() => _selectedDate = d);
      await _loadForDate();
    }
  }

  // ── bouton gradient réutilisable
  Widget _primaryGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    const grad = [Color(0xFF0E2A66), Color(0xFF7A8CEB)]; // bleu → lavande
    return PressableScale(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: grad.last.withOpacity(.28), blurRadius: 14, offset: const Offset(0, 8))],
        ),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 10),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final cs    = theme.colorScheme;

    final size      = MediaQuery.of(context).size;
    final shortest  = size.shortestSide;
    final isTablet  = shortest >= 600;
    final isDesktop = size.width >= 1024;
    final maxW      = isDesktop ? 900.0 : (isTablet ? 720.0 : 560.0);

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: const [Color(0xFFDEEFFF), Color(0xFFB3C7FF), Color(0xFFDCC8FF)],
        blurSigma: 14,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text('Sélection établissements'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(theme.brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => context.read<ThemeProvider>().toggleTheme(),
              ),
            ],
          ),

          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ListView(
                  children: [
                    // ── Carte "Date"
                    _DateCard(date: _selectedDate, onTap: _pickDate),

                    const SizedBox(height: 12),

                    // ── Carte "Recherche" (adresse + catégorie + bouton)
                    Card(
                      color: cs.surfaceContainerHighest.withOpacity(.9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          children: [
                            _InputCard(controller: _streetCtrl, label: 'Adresse / Rue'.tr(), icon: Icons.location_on_rounded),
                            const SizedBox(height: 8),
                            _InputCard(controller: _categoryCtrl, label: 'Enseigne (optionnel)'.tr(), icon: Icons.store_rounded),
                            const SizedBox(height: 12),
                            _primaryGradientButton(
                              label: 'Charger'.tr(),
                              icon: Icons.search_rounded,
                              onPressed: _fetchByZone,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── AdMob
                    if (_isBannerLoaded && _bannerAd != null) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0,3))],
                          ),
                          padding: const EdgeInsets.all(6),
                          child: SizedBox(
                            width : _bannerAd!.size.width.toDouble(),
                            height: _bannerAd!.size.height.toDouble(),
                            child : AdWidget(ad: _bannerAd!),
                          ),
                        ),
                      ),
                    ],

                    // ── Loader
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    // ── Invitation
                    if (!_loading && _allOptions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'Appuie sur “Charger” pour lancer la recherche.'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ),

                    // ── Pagination / Tri / Tout sélectionner
                    if (!_loading && _allOptions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Card(
                        color: cs.surfaceContainerHighest.withOpacity(.9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: _PaginationBar(
                            pageSize: _pageSize,
                            asc: _asc,
                            chosen: _chosen.length,
                            total: _allOptions.length,
                            onPageSize: (n) {
                              if (n == null) return;
                              setState(() {
                                _pageSize    = n;
                                _loadedCount = min(n, _allOptions.length);
                                _options     = _allOptions.sublist(0, _loadedCount);
                              });
                            },
                            onToggleSort: () => setState(() {
                              _asc = !_asc;
                              _sortByNumber();
                              _loadedCount = min(_pageSize, _allOptions.length);
                              _options     = _allOptions.sublist(0, _loadedCount);
                            }),
                            onToggleSelectAll: () => setState(() {
                              if (_chosen.length == _allOptions.length) {
                                _chosen.clear();
                              } else {
                                _chosen
                                  ..clear()
                                  ..addAll(_allOptions.map((p) => p.id));
                              }
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // ── Liste des résultats
                    if (!_loading && _options.isNotEmpty)
                      Card(
                        color: cs.surfaceContainerHighest.withOpacity(.9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListView.separated(
                          shrinkWrap        : true,
                          physics           : const NeverScrollableScrollPhysics(),
                          itemCount         : _options.length,
                          separatorBuilder  : (_, __) => const Divider(height: 0),
                          itemBuilder       : (_, i) {
                            final p   = _options[i];
                            final sel = _chosen.contains(p.id);
                            return CheckboxListTile(
                              value      : sel,
                              activeColor: cs.primary,
                              dense      : true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                              title      : Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle   : Text(
                                p.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onChanged  : (ok) => setState(() {
                                ok == true ? _chosen.add(p.id) : _chosen.remove(p.id);
                              }),
                            );
                          },
                        ),
                      ),

                    // ── Charger plus
                    if (!_loading && _loadedCount < _allOptions.length)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: _primaryGradientButton(
                          label: 'Charger $_pageSize de plus',
                          icon: Icons.keyboard_arrow_down_rounded,
                          onPressed: () => setState(() {
                            _loadedCount = min(_loadedCount + _pageSize, _allOptions.length);
                            _options     = _allOptions.sublist(0, _loadedCount);
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _onSave,
            icon: const Icon(Icons.save_rounded),
            label: Text('Enregistrer'.tr()),
          ),
        ),
      ),
    );
  }
}

// ─────────── Widgets internes ───────────

class _DateCard extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateCard({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surfaceContainerHighest.withOpacity(.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: AutoSizeText(
                  '${'Planifier le'.tr()} ${DateFormat.yMMMMd(context.locale.languageCode).format(date)}',
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  minFontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit_calendar_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  const _InputCard({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled     : true,
        fillColor  : cs.surfaceContainerHighest.withOpacity(.95),
        labelText  : label,
        prefixIcon : Icon(icon, color: cs.primary),
        border     : OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int pageSize;
  final bool asc;
  final int chosen;
  final int total;
  final ValueChanged<int?> onPageSize;
  final VoidCallback onToggleSort;
  final VoidCallback onToggleSelectAll;

  const _PaginationBar({
    required this.pageSize,
    required this.asc,
    required this.chosen,
    required this.total,
    required this.onPageSize,
    required this.onToggleSort,
    required this.onToggleSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final pageSizePicker = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<int>(
        value: pageSize,
        underline: const SizedBox(),
        items: [20, 50]
            .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
            .toList(),
        onChanged: onPageSize,
      ),
    );

    final sortBtn = IconButton.filledTonal(
      icon: Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
      onPressed: onToggleSort,
      tooltip: 'Trier par numéro'.tr(),
    );

    final selectAll = TextButton.icon(
      onPressed: onToggleSelectAll,
      icon: const Icon(Icons.checklist_rounded),
      label: Text(
        chosen == total ? 'Tout décocher'.tr() : 'Tout sélectionner'.tr(),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
      ),
    );

    return LayoutBuilder(
      builder: (_, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            pageSizePicker,
            sortBtn,
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.55),
              child: selectAll,
            ),
          ],
        );
      },
    );
  }
}
