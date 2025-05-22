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

  /* ─────────────── init ─────────────── */
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
          '${p.name} — ${p.address} — [${p.category}] — Statut : ${p.status}');
    }
    final file = File('${_dateDir.path}/rapport-$dayStr.txt');
    await file.writeAsString(sb.toString());
    await _loadFiles();

    await Share.shareXFiles([XFile(file.path)], subject: 'Prospections $dayStr');
  }

  /* ─────────────── Camembert ─────────────── */
  Widget _buildPieChart(ThemeData theme) {
    if (_list.isEmpty) return const SizedBox.shrink();

    final present  = _list.where((p) => p.status == 'présent').length;
    final absent   = _list.where((p) => p.status == 'absent').length;
    final rdv      = _list.where((p) => p.status == 'rdv').length;
    final closed   = _list.where((p) => p.finishedAt != null).length;
    final total = present + absent + rdv + closed;
    if (total == 0) return const SizedBox.shrink();

    PieChartSectionData sec(String title, int value, Color color) {
      final pct = value / total * 100;
      return PieChartSectionData(
        value   : value.toDouble(),
        title   : value == 0 ? '' : '${pct.toStringAsFixed(0)} %',
        color   : color,
        radius  : 60,
        titleStyle: theme.textTheme.labelSmall!
            .copyWith(color: theme.colorScheme.onPrimary),
      );
    }

    final cs = theme.colorScheme;
    final sections = [
      if (present > 0) sec('Présent',  present,  cs.primary),
      if (absent  > 0) sec('Absent',   absent,   cs.error),
      if (rdv     > 0) sec('RDV',      rdv,      cs.tertiary),
      if (closed  > 0) sec('Clôturé',  closed,   cs.secondary),
    ];

    Widget legend(String lbl, Color clr, int n) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(
            color: clr, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$lbl ($n)', style: theme.textTheme.bodySmall),
      ],
    );

    return Column(
      children: [
        SizedBox(
          height: 180,
          child : PieChart(PieChartData(
            sections        : sections,
            centerSpaceRadius: 24,
            sectionsSpace   : 2,
          )),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            if (present > 0) legend('Présent',  cs.primary,    present),
            if (absent  > 0) legend('Absent',   cs.error,      absent),
            if (rdv     > 0) legend('RDV',      cs.tertiary,   rdv),
            if (closed  > 0) legend('Clôturé',  cs.secondary,  closed),
          ],
        ),
        const Divider(),
      ],
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
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          title: Text('Terminés – $formattedDate'),
          actions: [
            IconButton.filledTonal(
              icon : const Icon(Icons.share),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.folder, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Fichiers du $formattedDate',
                        style: theme.textTheme.titleMedium),
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
                      icon : const Icon(Icons.insert_drive_file),
                      label: Text(name, overflow: TextOverflow.ellipsis),
                      onPressed: () => Share.shareXFiles([XFile(f.path)], subject: name),
                    );
                  },
                ),
              ),
              const Divider(),
            ],

            /* -------- Liste prospects -------- */
            Expanded(
              child: _list.isEmpty
                  ? Center(
                child: Text('Aucun prospect pour le $formattedDate.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              )
                  : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ProspectCard(_list[i]),
              ),
            ),
          ],
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
          Expanded(child: Text(txt)),
        ],
      ),
    );

    return Card(
      color : cs.surfaceContainerHighest,
      shape : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child : Padding(
        padding: const EdgeInsets.all(16),
        child  : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /* ---------- En‑tête ---------- */
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(p.name, style: txtTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),

            /* ---------- Adresse ---------- */
            Text(p.address, style: txtTheme.bodyMedium),
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
              line(Icons.phone, p.phone!),
            if (p.email != null && p.email!.isNotEmpty)
              line(Icons.email, p.email!),
            if (p.role != null && p.role!.isNotEmpty)
              line(Icons.badge, p.role!),
            if (p.note != null && p.note!.isNotEmpty)
              line(Icons.note, p.note!),
            if (p.prochaineVisite != null)
              line(Icons.calendar_month,
                  DateFormat.yMMMd('fr_FR').format(p.prochaineVisite!)),
            line(Icons.flag, 'Clôturé : ${p.finishedAt != null ? 'oui' : 'non'}'),
            if (p.finishedAt != null)
              line(Icons.timer,
                  DateFormat.yMMMd('fr_FR').add_Hm().format(p.finishedAt!)),
          ],
        ),
      ),
    );
  }
}
