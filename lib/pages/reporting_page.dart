// lib/pages/reporting_page.dart
// UI 2026 — Glassmorphism, fond auroré, style aligné select_prospects_page
// Logique métier inchangée — seule la présentation est redesignée

import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/prospect.dart';
import '../providers/theme_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/brand_background.dart';

import 'all_prospects_finished_page.dart';
import 'prospect_form_page.dart';

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

  static LinearGradient get primary => const LinearGradient(
    colors: [indigo, violet], begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static LinearGradient get aurora => const LinearGradient(
    colors: [ProspectoColors.backgroundTop, ProspectoColors.blueMist, ProspectoColors.peachMist],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // Couleur par statut
  static Color statusColor(String s) {
    switch (s) {
      case 'présent': return mint;
      case 'absent':  return coral;
      case 'rdv':     return amber;
      default:        return onLightSub;
    }
  }
  static IconData statusIcon(String s) {
    switch (s) {
      case 'présent': return Icons.check_circle_rounded;
      case 'absent':  return Icons.cancel_rounded;
      case 'rdv':     return Icons.event_rounded;
      default:        return Icons.radio_button_unchecked_rounded;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  Page
// ════════════════════════════════════════════════════════════════
class ReportingPage extends StatefulWidget {
  static const routeName = '/reporting';
  const ReportingPage({Key? key}) : super(key: key);

  @override
  State<ReportingPage> createState() => _ReportingPageState();
}

class _ReportingPageState extends State<ReportingPage> {
  DateTime _date = DateTime.now();
  List<Prospect> _options = [];

  Map<String, Map<String, dynamic>> _reports = {};
  Map<String, Map<String, dynamic>> _replanned = {};

  bool _loading = false;
  String? _error;
  bool _dirty = false;

  static const _roles    = ['vide', 'Employé', 'Gérant', 'Responsable'];
  static const _statuses = ['vide', 'présent', 'absent', 'rdv'];

  final Map<String, TextEditingController> _phoneCtrls    = {};
  final Map<String, TextEditingController> _emailCtrls    = {};
  final Map<String, TextEditingController> _noteCtrls     = {};
  final Map<String, TextEditingController> _websiteCtrls  = {};
  final Map<String, TextEditingController> _linkedinCtrls = {};
  final Map<String, TextEditingController> _instagramCtrls = {};
  final Map<String, TextEditingController> _facebookCtrls = {};

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  bool _requiresContact(String role) => role == 'Gérant' || role == 'Responsable';
  bool _hasAnyContact(Map<String, dynamic> r) {
    return (r['phone'] ?? '').toString().trim().isNotEmpty ||
        (r['email'] ?? '').toString().trim().isNotEmpty;
  }

  bool _isComplete(String id) {
    final r = _reports[id] ?? {};
    final role   = (r['role']   ?? 'vide').toString();
    final status = (r['status'] ?? 'vide').toString();
    if (role == 'vide' || status == 'vide') return false;
    if (status == 'rdv' && _toDate(r['nextVisit']) == null) return false;
    if (_requiresContact(role)) return _hasAnyContact(r);
    return true;
  }

  int get _completedCount => _options.where((p) => _isComplete(p.id)).length;
  bool get _allCompleted  => _options.isNotEmpty && _options.every((p) => _isComplete(p.id));

  @override
  void initState() { super.initState(); _loadForDate(); }

  @override
  void dispose() {
    for (final c in [..._phoneCtrls.values, ..._emailCtrls.values, ..._noteCtrls.values,
      ..._websiteCtrls.values, ..._linkedinCtrls.values, ..._instagramCtrls.values,
      ..._facebookCtrls.values]) c.dispose();
    super.dispose();
  }

  Map<String, dynamic> _ensureReport(String id) {
    final r = _reports[id] ??= {
      'status': 'vide', 'role': _roles.first,
      'phone': '', 'email': '', 'website': '', 'linkedin': '',
      'instagram': '', 'facebook': '', 'note': '',
      'extraLinks': <Map<String, String>>[], 'closed': false,
      'finishedAt': null, 'nextVisit': null,
    };
    _phoneCtrls.putIfAbsent(id, () => TextEditingController(text: (r['phone'] ?? '').toString()));
    _emailCtrls.putIfAbsent(id, () => TextEditingController(text: (r['email'] ?? '').toString()));
    _websiteCtrls.putIfAbsent(id, () => TextEditingController(text: (r['website'] ?? '').toString()));
    _linkedinCtrls.putIfAbsent(id, () => TextEditingController(text: (r['linkedin'] ?? '').toString()));
    _instagramCtrls.putIfAbsent(id, () => TextEditingController(text: (r['instagram'] ?? '').toString()));
    _facebookCtrls.putIfAbsent(id, () => TextEditingController(text: (r['facebook'] ?? '').toString()));
    _noteCtrls.putIfAbsent(id, () => TextEditingController(text: (r['note'] ?? '').toString()));
    r['role']   = (r['role']   ?? 'vide').toString();
    r['status'] = (r['status'] ?? 'vide').toString();
    r['nextVisit']  = _toDate(r['nextVisit']);
    r['finishedAt'] = _toDate(r['finishedAt']);
    r['closed'] = r['finishedAt'] != null;
    final rawLinks = r['extraLinks'];
    if (rawLinks is List) {
      r['extraLinks'] = rawLinks.whereType<Map>()
          .map((m) => {'label': (m['label'] ?? '').toString(), 'url': (m['url'] ?? '').toString()})
          .where((m) => m['label']!.trim().isNotEmpty || m['url']!.trim().isNotEmpty)
          .cast<Map<String, String>>().toList();
    } else {
      r['extraLinks'] = <Map<String, String>>[];
    }
    return r;
  }

  Future<void> _loadForDate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await FirestoreService().loadPlanData(_date);
      final ids  = List<String>.from(data['prospectIds'] ?? []);
      final raw  = data['reports']   as Map<String, dynamic>? ?? {};
      final repl = data['replanned'] as Map<String, dynamic>? ?? {};
      _reports  = { for (var e in raw.entries)  e.key: Map<String, dynamic>.from(e.value) };
      _replanned = { for (var e in repl.entries) e.key: Map<String, dynamic>.from(e.value) };
      if (ids.isNotEmpty) {
        final fetched = await FirestoreService().fetchProspectsByIds(ids);
        final byId = {for (final p in fetched) p.id: p};
        _options = [for (final id in ids) if (byId[id] != null) byId[id]!];
      } else { _options = []; }
      for (final p in _options) {
        final r = _ensureReport(p.id);
        _phoneCtrls[p.id]!.text    = (r['phone']     ?? '').toString();
        _emailCtrls[p.id]!.text    = (r['email']     ?? '').toString();
        _websiteCtrls[p.id]!.text  = (r['website']   ?? '').toString();
        _linkedinCtrls[p.id]!.text = (r['linkedin']  ?? '').toString();
        _instagramCtrls[p.id]!.text = (r['instagram'] ?? '').toString();
        _facebookCtrls[p.id]!.text = (r['facebook']  ?? '').toString();
        _noteCtrls[p.id]!.text     = (r['note']      ?? '').toString();
      }
      _dirty = false;
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickDate() async {
    if (_dirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: LText('Modifications non enregistrées'.tr()),
          content: LText('Enregistrer un brouillon avant de changer de date ?'.tr()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: LText('Ignorer'.tr())),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: LText('Enregistrer'.tr())),
          ],
        ),
      );
      if (ok == true) await _save(draft: true);
    }
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) { setState(() => _date = d); await _loadForDate(); }
  }

  Future<void> _replanify(String prospectId) async {
    final newDate = await showDatePicker(
      context: context, initialDate: _date.add(const Duration(days: 1)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (newDate == null) return;
    final sameDay = DateFormat('yyyy-MM-dd').format(newDate) == DateFormat('yyyy-MM-dd').format(_date);
    if (sameDay) { _toast('Choisis une autre date.'.tr(), isError: true); return; }
    setState(() => _loading = true);
    try {
      await FirestoreService().replanProspect(fromDate: _date, toDate: newDate, prospectId: prospectId);
      _toast('Prospect replanifié au ${DateFormat.yMd().format(newDate)}');
      await _loadForDate();
    } catch (_) { _toast('Erreur replanification'.tr(), isError: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _deleteProspect(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: LText('Supprimer ce prospect ?'.tr()),
        content: LText('Cette action est irréversible.'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: LText('Annuler'.tr())),
          TextButton(onPressed: () => Navigator.pop(dCtx, true),
              child: LText('Supprimer'.tr(), style: const TextStyle(color: _P.coral))),
        ],
      ),
    );
    if (confirm != true) return;
    await FirestoreService().deleteProspect(id);
    if (!mounted) return;
    setState(() {
      _options.removeWhere((p) => p.id == id);
      _reports.remove(id); _replanned.remove(id);
      _phoneCtrls.remove(id)?.dispose(); _emailCtrls.remove(id)?.dispose();
      _websiteCtrls.remove(id)?.dispose(); _linkedinCtrls.remove(id)?.dispose();
      _instagramCtrls.remove(id)?.dispose(); _facebookCtrls.remove(id)?.dispose();
      _noteCtrls.remove(id)?.dispose();
      _dirty = true;
    });
  }

  Future<void> _pickNextVisit(String id) async {
    final r = _ensureReport(id);
    final current = _toDate(r['nextVisit']) ?? _date.add(const Duration(days: 1));
    final d = await showDatePicker(
      context: context, initialDate: current,
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    final dt = DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0);
    setState(() { r['nextVisit'] = dt; _dirty = true; });
  }

  Future<void> _save({required bool draft}) async {
    for (final p in _options) {
      final r = _ensureReport(p.id);
      r['phone']     = _phoneCtrls[p.id]?.text.trim()    ?? '';
      r['email']     = _emailCtrls[p.id]?.text.trim()    ?? '';
      r['website']   = _websiteCtrls[p.id]?.text.trim()  ?? '';
      r['linkedin']  = _linkedinCtrls[p.id]?.text.trim() ?? '';
      r['instagram'] = _instagramCtrls[p.id]?.text.trim() ?? '';
      r['facebook']  = _facebookCtrls[p.id]?.text.trim() ?? '';
      r['note']      = _noteCtrls[p.id]?.text.trim()     ?? '';
    }
    if (!draft) {
      for (final p in _options) {
        final r      = _reports[p.id] ?? {};
        final role   = (r['role']   ?? 'vide').toString();
        final status = (r['status'] ?? 'vide').toString();
        if (role == 'vide' || status == 'vide') { _toast('Rôle et statut obligatoires.', isError: true); return; }
        if (status == 'rdv' && _toDate(r['nextVisit']) == null) { _toast('RDV : choisis une date/heure.', isError: true); return; }
        if (_requiresContact(role) && !_hasAnyContact(r)) { _toast('Contact obligatoire pour $role.', isError: true); return; }
      }
    }
    final cleanReports = <String, Map<String, dynamic>>{};
    for (final e in _reports.entries) {
      final r = Map<String, dynamic>.from(e.value)..remove('closed');
      cleanReports[e.key] = r;
    }
    final ids = _options.map((p) => p.id).toList();
    await FirestoreService().savePlanReport(_date, ids, cleanReports);
    if (!mounted) return;
    setState(() => _dirty = false);
    if (!draft && _allCompleted) {
      _toast('Journée terminée 🎉');
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const AllProspectsFinishedPage(),
      ));
    } else {
      _toast(draft ? 'Brouillon enregistré' : 'Reporting sauvegardé ✅');
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

  InputDecoration _dec(String label, IconData icon, ThemeData theme) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: _P.indigo),
    filled: true, fillColor: Colors.white.withOpacity(0.60),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _P.indigo.withOpacity(0.18))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.35))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _P.indigo, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    labelStyle: const TextStyle(fontSize: 13, color: _P.onLightSub),
  );

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final theme  = context.watch<ThemeProvider>().currentTheme;
    final isDark = theme.brightness == Brightness.dark;
    final size   = MediaQuery.of(context).size;
    final maxW   = size.width >= 1024 ? 900.0 : (size.shortestSide >= 600 ? 720.0 : 560.0);

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
          bottomNavigationBar: _buildBottomBar(isDark),
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
                              // ── Date
                              _GlassCard(isDark: isDark, child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionHeader(step: 1, icon: Icons.calendar_today_rounded, title: 'Date du reporting', isDark: isDark),
                                  const SizedBox(height: 12),
                                  GestureDetector(
                                    onTap: _pickDate,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: _P.indigo.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: _P.indigo.withOpacity(0.2)),
                                      ),
                                      child: Row(children: [
                                        Icon(Icons.calendar_month_rounded, color: _P.indigo, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: AutoSizeText(
                                            DateFormat.yMMMMEEEEd(context.locale.languageCode).format(_date),
                                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                                                color: isDark ? _P.onDark : _P.onLight),
                                            maxLines: 1, minFontSize: 12,
                                          ),
                                        ),
                                        Icon(Icons.edit_calendar_rounded, color: _P.indigo.withOpacity(0.6), size: 18),
                                      ]),
                                    ),
                                  ),
                                ],
                              )),
                              const SizedBox(height: 10),

                              // ── Stat bar (si données)
                              if (!_loading && _options.isNotEmpty) ...[
                                _StatsBar(
                                  total: _options.length,
                                  completed: _completedCount,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 10),
                              ],

                              // ── Error
                              if (_error != null)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _P.coral.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _P.coral.withOpacity(0.3)),
                                  ),
                                  child: Row(children: [
                                    Icon(Icons.error_outline_rounded, color: _P.coral, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(child: LText(_error!, style: const TextStyle(color: _P.coral, fontWeight: FontWeight.w600))),
                                  ]),
                                ),

                              // ── Prospects list
                              if (!_loading && _options.isNotEmpty) ...[
                                _GlassCard(
                                  isDark: isDark,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionHeader(
                                        step: 2,
                                        icon: Icons.checklist_rounded,
                                        title: 'Prospects (${_completedCount}/${_options.length})',
                                        isDark: isDark,
                                      ),
                                      const SizedBox(height: 12),
                                      ...List.generate(_options.length, (i) {
                                        final p = _options[i];
                                        return _ProspectReportCard(
                                          key: ValueKey(p.id),
                                          prospect: p,
                                          report: _ensureReport(p.id),
                                          isComplete: _isComplete(p.id),
                                          isReplanned: _replanned.containsKey(p.id),
                                          isDark: isDark,
                                          roles: _roles,
                                          statuses: _statuses,
                                          phoneCtrl: _phoneCtrls[p.id]!,
                                          emailCtrl: _emailCtrls[p.id]!,
                                          noteCtrl: _noteCtrls[p.id]!,
                                          dec: _dec,
                                          theme: theme,
                                          onChanged: () => setState(() => _dirty = true),
                                          onPickNextVisit: () => _pickNextVisit(p.id),
                                          onReplanify: () => _replanify(p.id),
                                          onDelete: () => _deleteProspect(p.id),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],

                              // ── Empty
                              if (!_loading && _options.isEmpty)
                                _EmptyReport(isDark: isDark),

                              // ── Add
                              const SizedBox(height: 10),
                              _GlassOutlineButton(
                                label: 'Ajouter un prospect manuellement'.tr(),
                                icon: Icons.add_rounded,
                                onTap: () async {
                                  await Navigator.pushNamed(context, ProspectFormPage.routeName);
                                  await _loadForDate();
                                },
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

  // ════════ AppBar ════════
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
          child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LText(
            'Reporting'.tr(),
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
      actions: [
        _AppBarAction(icon: Icons.save_rounded, badge: _dirty, tooltip: 'Brouillon'.tr(),
            onTap: () => _save(draft: true)),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark) {
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
              // Badge complétés
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: _completedCount > 0 ? _P.primary : null,
                  color: _completedCount == 0 ? Colors.white.withOpacity(0.25) : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _completedCount > 0
                      ? [BoxShadow(color: _P.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.task_alt_rounded, size: 18, color: _completedCount > 0 ? Colors.white : Colors.black38),
                  const SizedBox(width: 6),
                  LText('$_completedCount/${_options.length}', style: TextStyle(
                    color: _completedCount > 0 ? Colors.white : Colors.black38,
                    fontWeight: FontWeight.w900, fontSize: 14,
                  )),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: _GradientButton(
                label: _allCompleted ? 'Terminer la journée 🎉' : 'Enregistrer'.tr(),
                icon: _allCompleted ? Icons.check_circle_rounded : Icons.save_rounded,
                onTap: _dirty || _options.isNotEmpty ? () => _save(draft: false) : null,
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

class _StatsBar extends StatelessWidget {
  final int total, completed;
  final bool isDark;
  const _StatsBar({required this.total, required this.completed, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : completed / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_P.indigo.withOpacity(0.10), _P.violet.withOpacity(0.06)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _P.indigo.withOpacity(0.18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ShaderMask(
                shaderCallback: (r) => _P.primary.createShader(r),
                child: LText('$completed / $total', style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
              ),
              const Spacer(),
              LText('${(pct * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _P.indigo)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation(pct >= 1.0 ? _P.mint : _P.indigo),
                minHeight: 6,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Carte prospect reporting avec accordéon
class _ProspectReportCard extends StatefulWidget {
  final Prospect prospect;
  final Map<String, dynamic> report;
  final bool isComplete, isReplanned, isDark;
  final List<String> roles, statuses;
  final TextEditingController phoneCtrl, emailCtrl, noteCtrl;
  final InputDecoration Function(String, IconData, ThemeData) dec;
  final ThemeData theme;
  final VoidCallback onChanged, onPickNextVisit, onReplanify, onDelete;

  const _ProspectReportCard({
    super.key, required this.prospect, required this.report,
    required this.isComplete, required this.isReplanned, required this.isDark,
    required this.roles, required this.statuses,
    required this.phoneCtrl, required this.emailCtrl, required this.noteCtrl,
    required this.dec, required this.theme, required this.onChanged,
    required this.onPickNextVisit, required this.onReplanify, required this.onDelete,
  });

  @override
  State<_ProspectReportCard> createState() => _ProspectReportCardState();
}

class _ProspectReportCardState extends State<_ProspectReportCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r      = widget.report;
    final status = (r['status'] ?? 'vide').toString();
    final isDark = widget.isDark;
    final color  = _P.statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: widget.isComplete
              ? _P.mint.withOpacity(0.06)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.55)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isComplete
                ? _P.mint.withOpacity(0.35)
                : Colors.white.withOpacity(0.4),
            width: widget.isComplete ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header tap
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(children: [
                  // Statut icon
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(_P.statusIcon(status), color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LText(widget.prospect.name,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                            color: isDark ? _P.onDark : _P.onLight),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    LText(widget.prospect.address,
                        style: TextStyle(fontSize: 12, color: isDark ? _P.onDarkSub : _P.onLightSub),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  // Status pill
                  _StatusPill(status: status),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: isDark ? _P.onDarkSub : _P.onLightSub),
                  ),
                ]),
              ),
            ),

            // ── Expanded form
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Divider(height: 16),
                  // Rôle + statut
                  Row(children: [
                    Expanded(child: _DropdownField(
                      label: 'Rôle',
                      value: (r['role'] ?? 'vide').toString(),
                      items: widget.roles,
                      onChanged: (v) { if (v != null) { r['role'] = v; widget.onChanged(); setState(() {}); }},
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _DropdownField(
                      label: 'Statut',
                      value: (r['status'] ?? 'vide').toString(),
                      items: widget.statuses,
                      onChanged: (v) { if (v != null) { r['status'] = v; widget.onChanged(); setState(() {}); }},
                    )),
                  ]),
                  const SizedBox(height: 10),
                  // Contact fields
                  TextField(controller: widget.phoneCtrl, decoration: widget.dec('Téléphone', Icons.call_rounded, widget.theme),
                      keyboardType: TextInputType.phone, onChanged: (_) => widget.onChanged()),
                  const SizedBox(height: 10),
                  TextField(controller: widget.emailCtrl, decoration: widget.dec('Email', Icons.email_rounded, widget.theme),
                      keyboardType: TextInputType.emailAddress, onChanged: (_) => widget.onChanged()),
                  const SizedBox(height: 10),
                  // RDV picker
                  if ((r['status'] ?? 'vide') == 'rdv') ...[
                    GestureDetector(
                      onTap: widget.onPickNextVisit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _P.amber.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _P.amber.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Icon(Icons.event_rounded, color: _P.amber, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: LText(
                            r['nextVisit'] != null
                                ? DateFormat.yMMMEd().add_Hm().format(r['nextVisit'] as DateTime)
                                : 'Choisir date & heure du RDV',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                                color: r['nextVisit'] != null ? _P.amber : _P.onLightSub),
                          )),
                          Icon(Icons.edit_rounded, color: _P.amber.withOpacity(0.6), size: 16),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Note
                  TextField(controller: widget.noteCtrl, decoration: widget.dec('Note', Icons.notes_rounded, widget.theme),
                      maxLines: 2, onChanged: (_) => widget.onChanged()),
                  const SizedBox(height: 12),
                  // Actions
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _ActionPill(icon: Icons.redo_rounded, label: 'Replanifier', onTap: widget.onReplanify, color: _P.sky),
                    _ActionPill(icon: Icons.delete_outline_rounded, label: 'Supprimer', onTap: widget.onDelete, color: _P.coral),
                  ]),
                ]),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _P.statusColor(status);
    if (status == 'vide') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: LText(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label, value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.60),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: _P.onLightSub),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _P.onLight),
        dropdownColor: Colors.white,
        items: items
            .map(
              (s) => DropdownMenuItem<String>(
            value: s,
            child: LText(
              s,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionPill({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          LText(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  final bool isDark;
  const _EmptyReport({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_P.sky.withOpacity(0.2), _P.violet.withOpacity(0.15)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.analytics_outlined, size: 36, color: _P.indigo.withOpacity(0.5)),
        ),
        const SizedBox(height: 16),
        LText('Aucun prospect à reporter', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? _P.onDarkSub : _P.onLightSub)),
        const SizedBox(height: 6),
        LText('Planifie d\'abord une tournée pour cette date.', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: (isDark ? _P.onDarkSub : _P.onLightSub).withOpacity(0.7))),
      ]),
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

class _GlassOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GlassOutlineButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.indigo.withOpacity(0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: _P.indigo, size: 20),
          const SizedBox(width: 8),
          Flexible(child: LText(label, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _P.indigo, fontWeight: FontWeight.w700, fontSize: 14))),
        ]),
      ),
    );
  }
}

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
          Positioned(right: 8, top: 8,
              child: Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: _P.coral, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _P.coral.withOpacity(0.5), blurRadius: 4)]))),
      ],
    );
  }
}

class _LoadingOverlay extends StatefulWidget {
  const _LoadingOverlay();
  @override
  State<_LoadingOverlay> createState() => _LoadingOverlayState();
}
class _LoadingOverlayState extends State<_LoadingOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _rot = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override void dispose() { _rot.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(color: Colors.black.withOpacity(0.22),
          child: Center(child: ClipRRect(borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 200, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.35))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  RotationTransition(turns: _rot, child: Container(width: 52, height: 52,
                      decoration: BoxDecoration(gradient: _P.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 28))),
                  const SizedBox(height: 16),
                  const LText('Chargement…', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15), textAlign: TextAlign.center),
                ]),
              ),
            ),
          )),
        ),
      ),
    );
  }
}
