// lib/pages/plan_week_page.dart
// UI 2026 — Glassmorphism, fond auroré animé, style aligné select_prospects_page
// Logique métier inchangée

import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/prospect.dart';
import '../providers/theme_provider.dart';
import '../services/access_control.dart';
import '../services/firestore_service.dart';
import '../services/usage_meter.dart';
import '../services/week_planner.dart';
import '../widgets/brand_background.dart';

import '../theme/prospecto_colors.dart';
// ════════════════════════════════════════════════════════════════
//  Palette 2026
// ════════════════════════════════════════════════════════════════
class _P {
  static const indigo     = ProspectoColors.blue;
  static const violet     = ProspectoColors.green;
  static const sky        = ProspectoColors.blueSoft;
  static const mint       = ProspectoColors.green;
  static const coral      = ProspectoColors.peach;
  static const amber      = ProspectoColors.peachSoft;
  static const onLight    = ProspectoColors.textPrimary;
  static const onLightSub = ProspectoColors.textSecondary;
  static const onDark     = Color(0xFFF0F2FF);
  static const onDarkSub  = Color(0xFF9099C4);

  // Couleur par jour
  static Color dayColor(int i) {
    const colors = [indigo, violet, sky, mint, amber];
    return colors[i % colors.length];
  }

  static LinearGradient get primary => const LinearGradient(
    colors: [indigo, violet], begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static LinearGradient get aurora => const LinearGradient(
    colors: [ProspectoColors.backgroundTop, ProspectoColors.blueMist, ProspectoColors.peachMist],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

// ════════════════════════════════════════════════════════════════
//  Page
// ════════════════════════════════════════════════════════════════
class PlanWeekPage extends StatefulWidget {
  static const routeName = '/plan-week';

  final List<Prospect> pool;
  final List<String> selectedIds;
  final DateTime initialStartDate;

  const PlanWeekPage({
    Key? key,
    required this.pool,
    required this.selectedIds,
    required this.initialStartDate,
  }) : super(key: key);

  @override
  State<PlanWeekPage> createState() => _PlanWeekPageState();
}

enum _Group { artisan, food, retail, health, office, hotel, other }

class _PlanWeekPageState extends State<PlanWeekPage> {
  late DateTime _monday;
  bool _useAllResults = true;
  bool _modeStreet    = false;

  int _stopsPerDay = 10;
  int _rdvPerDay   = 0;

  final Set<_Group> _groupFilter = {};

  List<List<Prospect>> _days      = List.generate(5, (_) => <Prospect>[]);
  List<Prospect>       _remaining = <Prospect>[];

  bool _saving    = false;
  bool _isPremium = false;
  bool _trialUsed = false;

  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    _monday = WeekPlanner.toMonday(widget.initialStartDate);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadEntitlements();
      _generate();
    });
  }

  Future<void> _loadEntitlements() async {
    final meter = UsageMeter();
    await meter.initIfNeeded();
    await meter.syncFromCloud();
    final prem  = await meter.isPremium();
    final trial = await meter.getWeekPlannerTrialUsed();
    if (!mounted) return;
    setState(() { _isPremium = prem; _trialUsed = trial; });
  }

  _Group _classify(Prospect p) {
    final c = p.category.toLowerCase();
    final n = p.name.toLowerCase();
    bool has(List<String> k) => k.any((s) => c.contains(s) || n.contains(s));
    if (has(['artisan','craft','garage','car_repair','plomb','electric','menuis','serrur','peint','chauff','clim','travaux','construction','hardware','doityourself'])) return _Group.artisan;
    if (has(['restaurant','fast_food','cafe','bar','pub','bakery','boulanger','pizza','snack','food'])) return _Group.food;
    if (has(['pharmacy','doctors','hospital','dentist','health','clinic','medical','sant'])) return _Group.health;
    if (has(['office','bureau','cowork','company','entreprise','agency','agence','services'])) return _Group.office;
    if (has(['hotel','hostel','tourism','guest_house','héberg','heberg'])) return _Group.hotel;
    if (has(['shop','store','supermarket','market','magasin','retail','bank','banque','boutique'])) return _Group.retail;
    return _Group.other;
  }

  String _groupLabel(_Group g) {
    switch (g) {
      case _Group.artisan: return 'Pro';
      case _Group.food:    return 'Resto';
      case _Group.retail:  return 'Commerce';
      case _Group.health:  return 'Santé';
      case _Group.office:  return 'Bureau';
      case _Group.hotel:   return 'Hôtel';
      case _Group.other:   return 'Autre';
    }
  }

  IconData _groupIcon(_Group g) {
    switch (g) {
      case _Group.artisan: return Icons.engineering_rounded;
      case _Group.food:    return Icons.restaurant_rounded;
      case _Group.retail:  return Icons.storefront_rounded;
      case _Group.health:  return Icons.local_hospital_rounded;
      case _Group.office:  return Icons.business_rounded;
      case _Group.hotel:   return Icons.hotel_rounded;
      case _Group.other:   return Icons.category_rounded;
    }
  }

  List<_Group> get _presentGroups {
    final set = <_Group>{};
    for (final p in widget.pool) set.add(_classify(p));
    final list = set.toList()..sort((a, b) => _groupLabel(a).compareTo(_groupLabel(b)));
    return list;
  }

  List<Prospect> _candidates() {
    final byId = <String, Prospect>{for (final p in widget.pool) p.id: p};
    Iterable<Prospect> src = _useAllResults
        ? widget.pool
        : widget.selectedIds.map((id) => byId[id]).whereType<Prospect>();
    if (_groupFilter.isNotEmpty) src = src.where((p) => _groupFilter.contains(_classify(p)));
    final seen = <String>{};
    return [for (final p in src) if (seen.add(p.id)) p];
  }

  void _generate() {
    final capacity = (_stopsPerDay - _rdvPerDay).clamp(1, 50);
    final res = WeekPlanner.build(
      prospects: _candidates(), monday: _monday, maxPerDay: capacity, modeStreet: _modeStreet,
    );
    setState(() {
      _days      = List.generate(5, (i) => List<Prospect>.from(res.days[i]));
      _remaining = List<Prospect>.from(res.remaining);
    });
  }

  DateTime _dayDate(int i) => _monday.add(Duration(days: i));
  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven'];

  Future<void> _pickWeek() async {
    final d = await showDatePicker(
      context: context, initialDate: _monday,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() => _monday = WeekPlanner.toMonday(d));
    _generate();
  }

  void _nextWeek() { setState(() => _monday = _monday.add(const Duration(days: 7))); _generate(); }

  Future<void> _openDayInMaps(int i) async {
    final pts = _days[i];
    if (pts.isEmpty) return;
    final coords = pts.take(24).map((p) => '${p.lat},${p.lng}').toList();
    final dest   = coords.last;
    final wp     = coords.length <= 2 ? '' : coords.sublist(0, coords.length - 1).join('|');
    final uri    = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest${wp.isNotEmpty ? '&waypoints=$wp' : ''}&travelmode=driving');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _moveToDay(int from, int idx, int to) {
    if (to < 0 || to > 4 || from < 0 || from > 4) return;
    if (idx < 0 || idx >= _days[from].length) return;
    setState(() { final p = _days[from].removeAt(idx); _days[to].insert(0, p); });
  }

  Future<void> _saveWeek() async {
    final ok = await AccessControl.requireLogin(context, reason: "Pour enregistrer une semaine, connecte-toi.");
    if (!ok) return;
    final meter = UsageMeter();
    await meter.initIfNeeded();
    await meter.syncFromCloud();
    final premium = await meter.isPremium();
    final planned = _days.fold<int>(0, (s, d) => s + d.length);
    if (!premium) {
      final canTrial = await meter.canUseWeekPlannerTrial(totalProspects: planned);
      if (!canTrial) {
        if (!mounted) return;
        await AccessControl.openPaywall(context);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final fs = FirestoreService();
      for (var i = 0; i < 5; i++) {
        final ids = _days[i].map((p) => p.id).toList();
        if (ids.isEmpty) continue;
        await fs.savePlan(_dayDate(i), ids, widget.pool);
      }
      if (!premium) {
        await meter.markWeekPlannerTrialUsed();
        await meter.pushToCloud();
        await _loadEntitlements();
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: LText(msg),
      backgroundColor: isError ? _P.coral : _P.mint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme  = context.watch<ThemeProvider>().currentTheme;
    final isDark = theme.brightness == Brightness.dark;
    final size   = MediaQuery.of(context).size;
    final maxW   = size.width >= 1024 ? 900.0 : (size.shortestSide >= 600 ? 720.0 : 560.0);
    final planned = _days.fold<int>(0, (s, d) => s + d.length);

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: _P.aurora.colors,
        blurSigma: 14,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(isDark),
          bottomNavigationBar: _buildBottomBar(isDark, planned),
          body: SafeArea(
            top: true,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── Semaine + réglages
                          _GlassCard(isDark: isDark, child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(step: 1, icon: Icons.calendar_view_week_rounded, title: 'Semaine planifiée', isDark: isDark),
                              const SizedBox(height: 12),
                              // Date
                              GestureDetector(
                                onTap: _pickWeek,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _P.indigo.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _P.indigo.withOpacity(0.2)),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.date_range_rounded, color: _P.indigo, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(child: LText(
                                      'Sem. du ${DateFormat('d MMM', 'fr').format(_monday)} au ${DateFormat('d MMM yyyy', 'fr').format(_dayDate(4))}',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                                          color: isDark ? _P.onDark : _P.onLight),
                                    )),
                                    GestureDetector(
                                      onTap: _nextWeek,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _P.indigo.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                          LText('Suivante', style: TextStyle(color: _P.indigo, fontWeight: FontWeight.w600, fontSize: 12)),
                                          SizedBox(width: 4),
                                          Icon(Icons.chevron_right_rounded, color: _P.indigo, size: 16),
                                        ]),
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                              const SizedBox(height: 10),
                              // Toggles source + mode
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                _ToggleChip(
                                  label: _useAllResults ? 'Tous les résultats' : 'Cochés uniquement',
                                  icon: _useAllResults ? Icons.public_rounded : Icons.check_box_rounded,
                                  active: true,
                                  onTap: () { setState(() => _useAllResults = !_useAllResults); _generate(); },
                                ),
                                _ToggleChip(
                                  label: _modeStreet ? 'Par rue' : 'Par secteur',
                                  icon: _modeStreet ? Icons.signpost_rounded : Icons.location_city_rounded,
                                  active: _modeStreet,
                                  onTap: () { setState(() => _modeStreet = !_modeStreet); _generate(); },
                                ),
                                _ToggleChip(
                                  label: 'Réglages',
                                  icon: Icons.tune_rounded,
                                  active: _settingsOpen,
                                  onTap: () => setState(() => _settingsOpen = !_settingsOpen),
                                ),
                              ]),
                              // Réglages accordéon
                              AnimatedSize(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeInOut,
                                child: _settingsOpen
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          _SliderRow(
                                            label: 'Stops/jour',
                                            value: _stopsPerDay,
                                            min: 1, max: 30,
                                            onChanged: (v) { setState(() => _stopsPerDay = v); _generate(); },
                                          ),
                                          _SliderRow(
                                            label: 'RDV/jour',
                                            value: _rdvPerDay,
                                            min: 0, max: 10,
                                            onChanged: (v) { setState(() => _rdvPerDay = v); _generate(); },
                                          ),
                                          const SizedBox(height: 8),
                                          // Filtres groupe
                                          Wrap(spacing: 6, runSpacing: 6, children: _presentGroups.map((g) {
                                            final active = _groupFilter.contains(g);
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() { active ? _groupFilter.remove(g) : _groupFilter.add(g); });
                                                _generate();
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: active ? _P.indigo.withOpacity(0.15) : Colors.white.withOpacity(0.45),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: active ? _P.indigo.withOpacity(0.4) : Colors.white.withOpacity(0.6)),
                                                ),
                                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                  Icon(_groupIcon(g), size: 14, color: active ? _P.indigo : _P.onLightSub),
                                                  const SizedBox(width: 5),
                                                  LText(_groupLabel(g), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                                      color: active ? _P.indigo : _P.onLightSub)),
                                                ]),
                                              ),
                                            );
                                          }).toList()),
                                        ]),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          )),
                          const SizedBox(height: 10),

                          // ── 5 jours
                          _GlassCard(isDark: isDark, child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(step: 2, icon: Icons.view_week_rounded, title: 'Planning Lun → Ven', isDark: isDark),
                              const SizedBox(height: 12),
                              ...List.generate(5, (i) => _DayCard(
                                day: _dayLabels[i],
                                date: _dayDate(i),
                                prospects: _days[i],
                                color: _P.dayColor(i),
                                isDark: isDark,
                                onMaps: () => _openDayInMaps(i),
                                otherDays: List.generate(5, (j) => _dayLabels[j]).where((l) => l != _dayLabels[i]).toList(),
                                onMove: (fromIdx, toDay) {
                                  final toI = _dayLabels.indexOf(toDay);
                                  _moveToDay(i, fromIdx, toI);
                                },
                              )),
                              if (_remaining.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _P.amber.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _P.amber.withOpacity(0.3)),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.warning_amber_rounded, color: _P.amber, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: LText(
                                      '${_remaining.length} prospect${_remaining.length > 1 ? 's' : ''} non planifié${_remaining.length > 1 ? 's' : ''} (capacité atteinte)',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _P.amber),
                                    )),
                                  ]),
                                ),
                              ],
                            ],
                          )),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 8,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.white.withOpacity(isDark ? 0.05 : 0.28)),
        ),
      ),
      title: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.calendar_view_week_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LText(
            'Planif. semaine',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? _P.onDark : _P.onLight,
            ),
          ),
        ),
      ]),
      centerTitle: false,
    );
  }

  Widget _buildBottomBar(bool isDark, int planned) {
    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.25), width: 0.8)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: planned > 0 ? _P.primary : null,
                  color: planned == 0 ? Colors.white.withOpacity(0.25) : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: planned > 0
                      ? [BoxShadow(color: _P.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.event_note_rounded, size: 18, color: planned > 0 ? Colors.white : Colors.black38),
                  const SizedBox(width: 6),
                  LText('$planned planifiés', style: TextStyle(
                    color: planned > 0 ? Colors.white : Colors.black38,
                    fontWeight: FontWeight.w900, fontSize: 14,
                  )),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: _GradientButton(
                label: _saving ? 'Enregistrement…' : 'Enregistrer la semaine',
                icon: Icons.save_rounded,
                onTap: _saving || planned == 0 ? null : _saveWeek,
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Widgets
// ════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _GlassCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.75)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final bool isDark;
  const _SectionHeader({required this.step, required this.icon, required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: _P.indigo.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4))]),
        alignment: Alignment.center,
        child: LText('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      ),
      const SizedBox(width: 10),
      Icon(icon, size: 18, color: _P.indigo),
      const SizedBox(width: 8),
      Expanded(child: LText(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
          color: isDark ? _P.onDark : _P.onLight))),
    ]);
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _P.indigo.withOpacity(0.14) : Colors.white.withOpacity(0.50),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _P.indigo.withOpacity(0.4) : Colors.white.withOpacity(0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? _P.indigo : _P.onLightSub),
          const SizedBox(width: 5),
          LText(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: active ? _P.indigo : _P.onLightSub)),
        ]),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _SliderRow({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 90, child: LText('$label : $value',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _P.onLight))),
      Expanded(child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 4,
          activeTrackColor: _P.indigo,
          inactiveTrackColor: _P.indigo.withOpacity(0.15),
          thumbColor: Colors.white,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          overlayColor: _P.indigo.withOpacity(0.12),
        ),
        child: Slider(
          value: value.toDouble(), min: min.toDouble(), max: max.toDouble(), divisions: max - min,
          onChanged: (v) => onChanged(v.round()),
        ),
      )),
    ]);
  }
}

class _DayCard extends StatelessWidget {
  final String day;
  final DateTime date;
  final List<Prospect> prospects;
  final Color color;
  final bool isDark;
  final VoidCallback onMaps;
  final List<String> otherDays;
  final void Function(int fromIdx, String toDay) onMove;

  const _DayCard({
    required this.day, required this.date, required this.prospects,
    required this.color, required this.isDark, required this.onMaps,
    required this.otherDays, required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Center(child: LText(day, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LText(DateFormat('d MMMM', 'fr').format(date),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? _P.onDark : _P.onLight)),
                LText('${prospects.length} arrêt${prospects.length > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ])),
              if (prospects.isNotEmpty)
                GestureDetector(
                  onTap: onMaps,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.navigation_rounded, color: color, size: 14),
                      const SizedBox(width: 4),
                      LText('GPS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                    ]),
                  ),
                ),
            ]),
          ),
          // Prospects
          if (prospects.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: LText('Aucun prospect ce jour', style: TextStyle(fontSize: 12, color: isDark ? _P.onDarkSub : _P.onLightSub)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
              itemCount: prospects.length,
              separatorBuilder: (_, __) => Divider(height: 0, color: Colors.white.withOpacity(0.3)),
              itemBuilder: (ctx, i) {
                final p = prospects[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(7)),
                      alignment: Alignment.center,
                      child: LText('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      LText(p.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                          color: isDark ? _P.onDark : _P.onLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                      LText(p.address, style: TextStyle(fontSize: 11, color: isDark ? _P.onDarkSub : _P.onLightSub),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    // Déplacer vers autre jour
                    PopupMenuButton<String>(
                      icon: Icon(Icons.swap_horiz_rounded, size: 16, color: isDark ? _P.onDarkSub : _P.onLightSub),
                      onSelected: (d) => onMove(i, d),
                      itemBuilder: (_) => otherDays.map((d) => PopupMenuItem(value: d,
                          child: LText('→ $d', style: const TextStyle(fontWeight: FontWeight.w600)))).toList(),
                    ),
                  ]),
                );
              },
            ),
        ]),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _GradientButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            gradient: enabled ? _P.primary : const LinearGradient(colors: [Color(0xFF9099C4), Color(0xFF9099C4)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled ? [BoxShadow(color: _P.indigo.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(child: LText(label, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
          ]),
        ),
      ),
    );
  }
}
