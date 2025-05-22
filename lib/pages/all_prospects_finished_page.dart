// lib/pages/all_prospects_finished_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/prospect.dart';
import '../services/firestore_service.dart';
import 'prospects_finished_page.dart';

class AllProspectsFinishedPage extends StatefulWidget {
  static const routeName = '/prospects_finished_all';
  const AllProspectsFinishedPage({Key? key}) : super(key: key);

  @override
  State<AllProspectsFinishedPage> createState() =>
      _AllProspectsFinishedPageState();
}

class _AllProspectsFinishedPageState extends State<AllProspectsFinishedPage> {
  bool _loading = true;
  Map<DateTime, List<Prospect>> _reports = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _reports = await FirestoreService().loadAllReports();
    _reports = Map.fromEntries(
      _reports.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
    if (mounted) setState(() => _loading = false);
  }

  /* ──────────── Camembert générique ──────────── */
  Widget _pieFor(List<Prospect> list, ColorScheme cs, {double r = 36}) {
    final present = list.where((p) => p.status == 'présent').length;
    final absent  = list.where((p) => p.status == 'absent').length;
    final rdv     = list.where((p) => p.status == 'rdv').length;
    final closed  = list.where((p) => p.finishedAt != null).length;
    final total   = present + absent + rdv + closed;
    if (total == 0) return const SizedBox.shrink();

    PieChartSectionData s(int v, Color c) =>
        PieChartSectionData(value: v.toDouble(), color: c, radius: r, title: '');

    return PieChart(PieChartData(
      centerSpaceRadius: r / 2,
      sectionsSpace: 1,
      sections: [
        if (present > 0) s(present, cs.primary),
        if (absent  > 0) s(absent,  cs.error),
        if (rdv     > 0) s(rdv,     cs.tertiary),
        if (closed  > 0) s(closed,  cs.secondary),
      ],
    ));
  }

  Chip _chip(String lbl, int n, Color c, ColorScheme cs, TextTheme t) => Chip(
    avatar: CircleAvatar(backgroundColor: c, radius: 6),
    label : Text('$lbl ($n)', style: t.bodySmall),
    backgroundColor: cs.surfaceVariant,
    visualDensity: VisualDensity.compact,
  );

  /* ──────────── En-tête global ──────────── */
  Widget _globalHeader(BuildContext ctx) {
    final cs  = Theme.of(ctx).colorScheme;
    final t   = Theme.of(ctx).textTheme;
    if (_reports.isEmpty) return const SizedBox.shrink();

    final all   = _reports.values.expand((e) => e).toList();
    final pie   = _pieFor(all, cs, r: 48);

    final present       = all.where((p) => p.status == 'présent').length;
    final presentGerant = all.where((p) =>
    p.status == 'présent' && (p.role?.toLowerCase() == 'gérant')).length;
    final absent  = all.where((p) => p.status == 'absent').length;
    final rdv     = all.where((p) => p.status == 'rdv').length;
    final closed  = all.where((p) => p.finishedAt != null).length;

    /* ---- NOTE UTILISATEUR (nouvelle règle) ---- */
    final scoreGerant = (presentGerant / 10).clamp(0, 1);
    final scoreClot   = (closed / 2).clamp(0, 1);
    final userScore   = ((scoreGerant + scoreClot) / 2) * 10;


    return Card(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    color: cs.surfaceContainerHighest,
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
    children: [
      Text('Vue globale'.tr(), style: t.titleMedium),

      const SizedBox(height: 12),
    SizedBox(height: 140, child: pie),
    const SizedBox(height: 8),
    Wrap(
    spacing: 6,
    alignment: WrapAlignment.center,
    runSpacing: -4,
    children: [
      if (present > 0) _chip('Présent'.tr(),  present, cs.primary, cs, t),
      if (absent  > 0) _chip('Absent'.tr(),   absent,  cs.error, cs, t),
      if (rdv     > 0) _chip('RDV'.tr(),      rdv,     cs.tertiary, cs, t),
      if (closed  > 0) _chip('Clôturé'.tr(),  closed,  cs.secondary, cs, t),

    ],
    ),
    const SizedBox(height: 8),
    Text(
    'Présents gérants : $presentGerant  ·  Clôtures : $closed',
    style: t.bodySmall,
    ),
    const SizedBox(height: 4),
    Text('Note utilisateur : ${userScore.toStringAsFixed(1)}/10',
    style: t.bodyMedium),
    ],
    ),
    ),
    );
  }

  /* camembert + légende pour une journée */
  Widget _dayPie(List<Prospect> list, ColorScheme cs, TextTheme t) {
    final present = list.where((p) => p.status == 'présent').length;
    final absent  = list.where((p) => p.status == 'absent').length;
    final rdv     = list.where((p) => p.status == 'rdv').length;
    final closed  = list.where((p) => p.finishedAt != null).length;
    return Column(
      children: [
        SizedBox(height: 120, child: _pieFor(list, cs)),
        Wrap(
          spacing: 6,
          runSpacing: -4,
          alignment: WrapAlignment.center,
          children: [
            if (present > 0) _chip('Présent'.tr(),  present, cs.primary, cs, t),
            if (absent  > 0) _chip('Absent'.tr(),   absent,  cs.error, cs, t),
            if (rdv     > 0) _chip('RDV'.tr(),      rdv,     cs.tertiary, cs, t),
            if (closed  > 0) _chip('Clôturé'.tr(),  closed,  cs.secondary, cs, t),

          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  /* ──────────── BUILD ──────────── */
  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final t   = Theme.of(context).textTheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_reports.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Historique prospects'.tr()),

          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        body: Center(
          child: Text('Aucune prospection terminée.'.tr(),
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),

      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Historique prospects'.tr()),

        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _reports.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _globalHeader(context); // en-tête global

          final idx  = i - 1;
          final date = _reports.keys.elementAt(idx);
          final list = _reports.values.elementAt(idx);
          final dateFr = DateFormat.yMMMMd('fr_FR').format(date);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color : cs.surfaceVariant,
            shape : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: Icon(Icons.folder, color: cs.primary, size: 28),
              title : Text(dateFr,
                  style: t.titleMedium!.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${list.length} prospect${list.length > 1 ? 's' : ''}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _dayPie(list, cs, t),
                ...list.map(_ProspectTile.new),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        right: 12, bottom: 8, top: 4),
                    child: FilledButton.icon(
                      icon : const Icon(Icons.open_in_new),
                      label: const Text('Voir la fiche'),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primaryContainer,
                        foregroundColor: cs.onPrimaryContainer,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProspectsFinishedPage(date: date),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ───────────── Tuile prospect ───────────── */
class _ProspectTile extends StatelessWidget {
  final Prospect p;
  const _ProspectTile(this.p);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
      ),
      title: Text(p.name, style: TextStyle(color: cs.onSurface)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.address, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6, runSpacing: -4,
            children: [
              Chip(
                label: Text(p.category),
                backgroundColor: cs.secondaryContainer,
                labelStyle: TextStyle(color: cs.onSecondaryContainer),
                visualDensity: VisualDensity.compact,
              ),
              if (p.status != null)
                Chip(
                  label: Text(p.status!),
                  backgroundColor: cs.tertiaryContainer,
                  labelStyle: TextStyle(color: cs.onTertiaryContainer),
                  visualDensity: VisualDensity.compact,
                ),
              if (p.phone != null && p.phone!.isNotEmpty)
                const Icon(Icons.phone, size: 18),
              if (p.email != null && p.email!.isNotEmpty)
                const Icon(Icons.mail_outline, size: 18),
            ],
          ),
        ],
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      isThreeLine: true,
    );
  }
}
