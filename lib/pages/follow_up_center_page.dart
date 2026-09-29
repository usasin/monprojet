import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/prospect.dart';
import '../services/export_service.dart';
import '../services/firestore_service.dart';

class FollowUpCenterPage extends StatefulWidget {
  static const routeName = '/follow-ups';
  const FollowUpCenterPage({super.key});

  @override
  State<FollowUpCenterPage> createState() => _FollowUpCenterPageState();
}

class _FollowUpCenterPageState extends State<FollowUpCenterPage> {
  final _firestore = FirestoreService();
  final _export = const ExportService();
  bool _loading = true;
  bool _exporting = false;
  List<Prospect> _all = const [];
  String? _error;

  List<Prospect> get _followUps {
    final list = _all.where((p) => p.prochaineVisite != null).toList();
    list.sort((a, b) => a.prochaineVisite!.compareTo(b.prochaineVisite!));
    return list;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await _firestore.loadAllProspects();
      if (mounted) setState(() => _all = values);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _exporting = true);
    try {
      final file = await _export.createProspectsCsv(_all);
      await _export.shareFile(file, text: 'Export Prospecto – prospects et relances');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCalendar() async {
    if (_followUps.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final file = await _export.createCalendarIcs(_followUps);
      await _export.shareFile(file, text: 'Calendrier des relances Prospecto');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openMaps(Prospect p) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${p.lat},${p.lng}')}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final followUps = _followUps;
    return Scaffold(
      appBar: AppBar(
        title: const LText('Relances & exports'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: LText(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LText(
                                '${followUps.length} relance(s) programmée(s)',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              const LText(
                                'Les rappels sont envoyés 24 h puis 1 h avant la visite lorsque les Cloud Functions sont déployées.',
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  FilledButton.icon(
                                    onPressed: _exporting || _all.isEmpty ? null : _exportCsv,
                                    icon: const Icon(Icons.table_view_rounded),
                                    label: const LText('Exporter en CSV'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _exporting || followUps.isEmpty
                                        ? null
                                        : _exportCalendar,
                                    icon: const Icon(Icons.calendar_month_rounded),
                                    label: const LText('Ajouter au calendrier'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (followUps.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.event_available_rounded, size: 48),
                                SizedBox(height: 10),
                                LText(
                                  'Aucune relance programmée.',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 4),
                                LText('Ajoutez une prochaine visite depuis le reporting.'),
                              ],
                            ),
                          ),
                        )
                      else
                        ...followUps.map((p) {
                          final date = p.prochaineVisite!;
                          final overdue = date.isBefore(DateTime.now());
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: overdue
                                    ? Theme.of(context).colorScheme.errorContainer
                                    : Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(overdue
                                    ? Icons.warning_amber_rounded
                                    : Icons.notifications_active_rounded),
                              ),
                              title: LText(p.name),
                              subtitle: LText(
                                '${DateFormat('EEE dd MMM yyyy – HH:mm', 'fr').format(date)}\n${p.address}',
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: 'Ouvrir dans Maps'.tr(),
                                onPressed: () => _openMaps(p),
                                icon: const Icon(Icons.directions_rounded),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
