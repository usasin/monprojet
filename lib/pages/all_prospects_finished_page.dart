// lib/pages/all_prospects_finished_page.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/prospect.dart';
import '../services/firestore_service.dart';
import '../widgets/brand_background.dart';
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
    final data = await FirestoreService().loadAllReports();
    // tri par date desc
    _reports = Map.fromEntries(
      data.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
    if (mounted) setState(() => _loading = false);
  }

  /* ──────────── Comptage NON-CHEVAUCHANT ────────────
     Règle: closed > rdv > présent > absent
  */
  _Counts _countsFor(List<Prospect> list) {
    int closed = 0, rdv = 0, present = 0, absent = 0, presentGerant = 0;

    for (final p in list) {
      if (p.finishedAt != null) {
        closed++;
        continue;
      }
      final s = (p.status ?? '').toLowerCase();
      if (s == 'rdv') {
        rdv++;
      } else if (s == 'présent' || s == 'present') {
        present++;
        final role = (p.role ?? '').toLowerCase();
        if (role.contains('gérant') || role.contains('gerant')) {
          presentGerant++;
        }
      } else if (s == 'absent') {
        absent++;
      }
    }
    return _Counts(closed: closed, rdv: rdv, present: present, absent: absent, presentGerant: presentGerant);
  }

  /* ──────────── Camembert ──────────── */
  Widget _pieFor(List<Prospect> list, ColorScheme cs, {double r = 44}) {
    final c = _countsFor(list);
    final total = c.total;
    if (total == 0) return const SizedBox.shrink();

    PieChartSectionData s(int v, Color color) => PieChartSectionData(
      value: v.toDouble(),
      color: color,
      radius: r,
      title: '',
    );

    return PieChart(PieChartData(
      centerSpaceRadius: r / 2.2,
      sectionsSpace: 2,
      sections: [
        if (c.present > 0) s(c.present, cs.primary),
        if (c.absent  > 0) s(c.absent , cs.error),
        if (c.rdv     > 0) s(c.rdv    , cs.tertiary),
        if (c.closed  > 0) s(c.closed , cs.secondary),
      ],
    ));
  }

  Chip _chip(String lbl, int n, Color c, ColorScheme cs, TextTheme t) => Chip(
    avatar: CircleAvatar(backgroundColor: c, radius: 6),
    label: Text('$lbl ($n)', style: t.bodySmall),
    backgroundColor: cs.surfaceContainerHighest.withOpacity(.9),
    visualDensity: VisualDensity.compact,
    shape: StadiumBorder(side: BorderSide(color: c.withOpacity(.35))),
  );

  /* ──────────── En-tête global ──────────── */
  Widget _globalHeader(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final t  = Theme.of(ctx).textTheme;
    if (_reports.isEmpty) return const SizedBox.shrink();

    final all  = _reports.values.expand((e) => e).toList();
    final cnt  = _countsFor(all);
    final pie  = _pieFor(all, cs, r: 56);

    // petite note "score" (exemple)
    final scoreGerant = (cnt.presentGerant / 10).clamp(0, 1);
    final scoreClot   = (cnt.closed / 2).clamp(0, 1);
    final userScore   = ((scoreGerant + scoreClot) / 2) * 10;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: cs.surfaceContainerHighest.withOpacity(.95),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Text('Vue globale'.tr(), style: t.titleMedium!.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SizedBox(height: 150, child: pie),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              alignment: WrapAlignment.center,
              runSpacing: -4,
              children: [
                if (cnt.present > 0) _chip('Présent'.tr(),  cnt.present, cs.primary,    cs, t),
                if (cnt.absent  > 0) _chip('Absent'.tr(),   cnt.absent , cs.error,      cs, t),
                if (cnt.rdv     > 0) _chip('RDV'.tr(),      cnt.rdv    , cs.tertiary,   cs, t),
                if (cnt.closed  > 0) _chip('Clôturé'.tr(),  cnt.closed , cs.secondary,  cs, t),
              ],
            ),
            const SizedBox(height: 10),
            Text('Présents gérants : ${cnt.presentGerant}  ·  Clôtures : ${cnt.closed}',
                style: t.bodySmall),
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
    final c = _countsFor(list);
    return Column(
      children: [
        SizedBox(height: 130, child: _pieFor(list, cs)),
        Wrap(
          spacing: 6,
          runSpacing: -4,
          alignment: WrapAlignment.center,
          children: [
            if (c.present > 0) _chip('Présent'.tr(),  c.present, cs.primary,   cs, t),
            if (c.absent  > 0) _chip('Absent'.tr(),   c.absent , cs.error,     cs, t),
            if (c.rdv     > 0) _chip('RDV'.tr(),      c.rdv    , cs.tertiary,  cs, t),
            if (c.closed  > 0) _chip('Clôturé'.tr(),  c.closed , cs.secondary, cs, t),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  /* ──────────── BUILD ──────────── */
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t  = Theme.of(context).textTheme;

    return BrandBackground(
      gradientColors: const [Color(0xFFDEEFFF), Color(0xFFB3C7FF), Color(0xFFDCC8FF)],
      blurSigma: 14,
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text('Historique prospects'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),

        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_reports.isEmpty)
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, color: cs.onSurfaceVariant, size: 48),
              const SizedBox(height: 8),
              Text('Aucune prospection terminée.'.tr(),
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        )
            : Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _reports.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return _globalHeader(context);

                final idx   = i - 1;
                final date  = _reports.keys.elementAt(idx);
                final list  = _reports.values.elementAt(idx);
                final dateFr = DateFormat.yMMMMd('fr_FR').format(date);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color : cs.surfaceContainerHighest.withOpacity(.95),
                  shape : RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    leading: Icon(Icons.folder_rounded, color: cs.primary),
                    title : Text(dateFr,
                        style: t.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${list.length} ${'prospect${list.length > 1 ? 's' : ''}'}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      _dayPie(list, cs, t),
                      ...list.map(_ProspectTile.new),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6, right: 4),
                          child: FilledButton.tonalIcon(
                            icon : const Icon(Icons.open_in_new_rounded),
                            label: Text('Voir la fiche'.tr()),
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
          ),
        ),
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
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.address, style: TextStyle(color: cs.onSurfaceVariant),
              maxLines: 2, overflow: TextOverflow.ellipsis),
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
                const Icon(Icons.phone_rounded, size: 18),
              if (p.email != null && p.email!.isNotEmpty)
                const Icon(Icons.mail_outline_rounded, size: 18),
            ],
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      isThreeLine: true,
    );
  }
}

/* ───────────── Helper counts ───────────── */
class _Counts {
  final int closed, rdv, present, absent, presentGerant;
  const _Counts({
    required this.closed,
    required this.rdv,
    required this.present,
    required this.absent,
    required this.presentGerant,
  });
  int get total => closed + rdv + present + absent;
}
