import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/prospect.dart';
import '../providers/theme_provider.dart';
import '../services/firestore_service.dart';
import '../widgets/brand_background.dart';

class ProspectsFinishedPage extends StatefulWidget {
  static const routeName = '/prospects_finished';
  final DateTime date;
  const ProspectsFinishedPage({Key? key, required this.date}) : super(key: key);

  @override
  State<ProspectsFinishedPage> createState() => _ProspectsFinishedPageState();
}

/* ─────────────────── State ─────────────────── */
class _ProspectsFinishedPageState extends State<ProspectsFinishedPage> {
  List<Prospect> _list = [];
  List<File> _files = [];
  late Directory _dateDir;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    await _prepareDirectory();
    await _loadFiles();
    await _loadFinished();
  }

  /* ─────────────── Files & Firestore ─────────────── */
  Future<void> _prepareDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dayStr  = DateFormat('yyyy-MM-dd').format(widget.date);
    _dateDir = Directory('${baseDir.path}/$dayStr');
    if (!await _dateDir.exists()) await _dateDir.create(recursive: true);
  }

  Future<void> _loadFiles() async {
    final all = await _dateDir.list().toList();
    setState(() => _files = all.whereType<File>().toList());
  }

  Future<void> _loadFinished() async {
    final data = await FirestoreService().loadReportData(widget.date);
    setState(() => _list = data);
  }

  /* ─────────────── Partager tout ─────────────── */
  Future<void> _shareAll() async {
    final dayStr = DateFormat('yyyy-MM-dd').format(widget.date);
    final sb = StringBuffer()..writeln('Prospections du $dayStr\n');
    for (var p in _list) {
      sb.writeln(
          '${p.name} — ${p.address} — [${p.category}] — Statut : ${p.status ?? '-'} — Clôturé : ${p.finishedAt != null ? 'oui' : 'non'}');
    }
    final file = File('${_dateDir.path}/rapport-$dayStr.txt');
    await file.writeAsString(sb.toString());
    await _loadFiles();

    await Share.shareXFiles([XFile(file.path)], subject: 'Prospections $dayStr');
  }

  /* ─────────────── Camembert (non-chevauchant) ─────────────── */
  Widget _buildPieChart(ThemeData theme) {
    if (_list.isEmpty) return const SizedBox.shrink();
    // règle : si finishedAt != null -> "clôturé" (peu importe status)
    // sinon status 'rdv' > 'présent' > 'absent'
    int closed = 0, rdv = 0, present = 0, absent = 0;
    for (final p in _list) {
      if (p.finishedAt != null) {
        closed++;
      } else {
        final s = (p.status ?? '').toLowerCase();
        if (s == 'rdv') rdv++;
        else if (s == 'présent' || s == 'present') present++;
        else if (s == 'absent') absent++;
      }
    }
    final total = closed + rdv + present + absent;
    if (total == 0) return const SizedBox.shrink();

    PieChartSectionData sec(int value, Color color) {
      final pct = value / total * 100;
      return PieChartSectionData(
        value   : value.toDouble(),
        title   : value == 0 ? '' : '${pct.toStringAsFixed(0)} %',
        color   : color,
        radius  : 62,
        titleStyle: theme.textTheme.labelSmall!
            .copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w800),
      );
    }

    final cs = theme.colorScheme;
    final sections = <PieChartSectionData>[
      if (present > 0) sec(present, cs.primary),
      if (absent  > 0) sec(absent , cs.error),
      if (rdv     > 0) sec(rdv    , cs.tertiary),
      if (closed  > 0) sec(closed , cs.secondary),
    ];

    Widget chip(String lbl, Color clr, int n) => Chip(
      backgroundColor: clr.withOpacity(.18),
      shape: StadiumBorder(side: BorderSide(color: clr.withOpacity(.35))),
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: clr, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$lbl ($n)'),
      ]),
    );

    return Card(
      color: cs.surfaceContainerHighest.withOpacity(.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            SizedBox(
              height: 190,
              child : PieChart(PieChartData(
                sections        : sections,
                centerSpaceRadius: 28,
                sectionsSpace   : 2,
              )),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (present > 0) chip('Présent',  cs.primary,   present),
                if (absent  > 0) chip('Absent',   cs.error,     absent),
                if (rdv     > 0) chip('RDV',      cs.tertiary,  rdv),
                if (closed  > 0) chip('Clôturé',  cs.secondary, closed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /* ─────────────────── BUILD ─────────────────── */
  @override
  Widget build(BuildContext context) {
    final theme   = context.watch<ThemeProvider>().currentTheme;
    final cs      = theme.colorScheme;
    final formattedDate = DateFormat.yMMMMd('fr_FR').format(widget.date);

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
            title: Text('Terminés — $formattedDate',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            centerTitle: true,
            actions: [
              IconButton.filledTonal(
                icon : const Icon(Icons.share_rounded),
                tooltip: 'Partager tout',
                onPressed: _list.isEmpty ? null : _shareAll,
              ),
            ],
          ),

          body: Column(
            children: [
              /* -------- Graphique camembert -------- */
              _buildPieChart(theme),

              /* -------- Dossier + fichiers -------- */
              if (_files.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.folder_rounded, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Fichiers du $formattedDate',
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _files[i];
                      final name = f.path.split('/').last;
                      return FilledButton.tonalIcon(
                        icon : const Icon(Icons.insert_drive_file_rounded),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                        onPressed: () => Share.shareXFiles([XFile(f.path)], subject: name),
                      );
                    },
                  ),
                ),
              ],

              /* -------- Liste prospects -------- */
              Expanded(
                child: _list.isEmpty
                    ? Center(
                  child: Text('Aucun prospect pour le $formattedDate.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                )
                    : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ProspectCard(_list[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ──────────────────── Carte Prospect ──────────────────── */
class _ProspectCard extends StatelessWidget {
  final Prospect p;
  const _ProspectCard(this.p);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txtTheme = Theme.of(context).textTheme;

    Widget line(IconData icn, String txt) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icn, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(txt, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );

    return Card(
      color : cs.surfaceContainerHighest.withOpacity(.95),
      shape : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child : Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* ---------- En-tête ---------- */
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(p.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: txtTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 8),

            /* ---------- Adresse ---------- */
            Text(p.address, style: txtTheme.bodyMedium,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),

            /* ---------- Chips cat. + statut ---------- */
            Wrap(
              spacing: 6,
              runSpacing: -4,
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
              ],
            ),
            const Divider(),

            /* ---------- Détails ---------- */
            if (p.phone != null && p.phone!.isNotEmpty)
              line(Icons.phone_rounded, p.phone!),
            if (p.email != null && p.email!.isNotEmpty)
              line(Icons.email_rounded, p.email!),
            if (p.role != null && p.role!.isNotEmpty)
              line(Icons.badge_rounded, p.role!),
            if (p.note != null && p.note!.isNotEmpty)
              line(Icons.notes_rounded, p.note!),
            if (p.prochaineVisite != null)
              line(Icons.calendar_month_rounded,
                  DateFormat.yMMMd('fr_FR').format(p.prochaineVisite!)),
            line(Icons.flag_rounded, 'Clôturé : ${p.finishedAt != null ? 'oui' : 'non'}'),
            if (p.finishedAt != null)
              line(Icons.timer_rounded,
                  DateFormat.yMMMd('fr_FR').add_Hm().format(p.finishedAt!)),
          ],
        ),
      ),
    );
  }
}
