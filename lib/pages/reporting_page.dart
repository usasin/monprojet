import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/prospect.dart';
import '../providers/theme_provider.dart';
import '../services/firestore_service.dart';
import 'all_prospects_finished_page.dart';
import 'prospect_form_page.dart';

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
  bool _loading = false;
  String? _error;

  static const _roles = ['vide', 'Employé', 'Gérant', 'Responsable'];

  DateTime? _toDate(dynamic v) =>
      v == null ? null : (v is Timestamp ? v.toDate() : v as DateTime);

  bool _isComplete(String id) {
    final r = _reports[id]!;
    return r['status'] != 'vide' &&
        ((r['phone'] as String).isNotEmpty ||
            (r['email'] as String).isNotEmpty);
  }

  bool get _allCompleted =>
      _options.isNotEmpty &&
          _reports.length == _options.length &&
          _reports.keys.every(_isComplete);

  @override
  void initState() {
    super.initState();
    _loadForDate();
  }

  Future<void> _loadForDate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await FirestoreService().loadPlanData(_date);
      final ids  = List<String>.from(data['prospectIds'] ?? []);
      final raw  = data['reports'] as Map<String, dynamic>? ?? {};

      // Reconstitue le map id → report
      _reports = {
        for (var e in raw.entries)
          e.key: Map<String, dynamic>.from(e.value)
      }..forEach((_, r) {
        r['nextVisit']  = _toDate(r['nextVisit']);
        r['finishedAt'] = _toDate(r['finishedAt']);
        r['closed']     = r['finishedAt'] != null;
      });

      // Charge les prospects Firestore
      if (ids.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('prospects')
            .where(FieldPath.documentId, whereIn: ids)
            .get();

        _options = snap.docs.map((d) {
          final m = d.data();
          return Prospect(
            id      : d.id,
            name    : m['name'] ?? '',
            address : m['address'] ?? '',
            lat     : (m['lat'] as num).toDouble(),
            lng     : (m['lng'] as num).toDouble(),
            category: m['category'] ?? '',
          );
        }).toList();
      } else {
        _options = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context    : context,
      initialDate: _date,
      firstDate  : DateTime.now().subtract(const Duration(days: 30)),
      lastDate   : DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) {
      setState(() => _date = d);
      await _loadForDate();
    }
  }

  Future<void> _onSave() async {
    // Vérifie complétude
    for (final id in _reports.keys) {
      if (!_isComplete(id)) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chaque prospect doit avoir un statut et un contact.'.tr()))
        );
        return;
      }
    }

    // Nettoie la clé local 'closed'
    final cleanReports = {
      for (var e in _reports.entries)
        e.key: {...e.value..remove('closed')}
    };

    await FirestoreService()
        .savePlanReport(_date, _options.map((p) => p.id).toList(), cleanReports);

    // Dialogue de confirmation
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Terminée'.tr()),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Prospections du {date} enregistrées.'.tr(namedArgs: {'date': DateFormat.yMd().format(_date)})),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Fermer'.tr())),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, AllProspectsFinishedPage.routeName);
            },
            child: Text('Voir'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProspect(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer ce prospect ?'.tr()),
        content: Text('Cette action est irréversible.'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: Text('Annuler'.tr())),
          TextButton(onPressed: () => Navigator.pop(_, true),
            child: Text('Supprimer'.tr(), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Supprime dans Firestore + UI
    await FirestoreService().deleteProspect(id);
    setState(() {
      _options.removeWhere((p) => p.id == id);
      _reports.remove(id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Prospect supprimé'.tr())),
    );
  }

  Widget _buildReportFields(String id) {
    final report = _reports[id] ?? {
      'status': 'vide',
      'note': '',
      'nextVisit': null,
      'phone': '',
      'email': '',
      'role': _roles.first,
      'closed': false,
      'finishedAt': null,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Rôle
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: 'Rôle'.tr()),
          value: report['role'] as String?,
          items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.tr()))).toList(),
          onChanged: (v) => setState(() {
            report['role'] = v!;
            _reports[id] = report;
          }),
        ),
        const SizedBox(height: 8),

        // Statut
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: 'Statut'.tr()),
          value: report['status'] as String?,
          items: ['vide','présent','absent','rdv']
              .map((s) => DropdownMenuItem(value: s, child: Text(s.tr())))
              .toList(),
          onChanged: (v) => setState(() {
            report['status'] = v!;
            _reports[id] = report;
          }),
        ),
        const SizedBox(height: 8),

        // Téléphone
        TextFormField(
          initialValue: report['phone'] as String?,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(labelText: 'Téléphone'.tr()),
          onChanged: (t) => setState(() {
            report['phone'] = t;
            _reports[id] = report;
          }),
        ),
        const SizedBox(height: 8),

        // Email
        TextFormField(
          initialValue: report['email'] as String?,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(labelText: 'Email'.tr()),
          onChanged: (t) => setState(() {
            report['email'] = t;
            _reports[id] = report;
          }),
        ),
        const SizedBox(height: 8),

        // Prochaine visite
        FilledButton.tonal(
          onPressed: () async {
            final d0 = _toDate(report['nextVisit']) ?? DateTime.now();
            final d1 = await showDatePicker(
              context: context,
              initialDate: d0,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d1 != null) {
              setState(() {
                report['nextVisit'] = d1;
                _reports[id] = report;
              });
            }
          },
          child: Text(
            report['nextVisit'] != null
                ? DateFormat.yMd().format(_toDate(report['nextVisit'])!)
                : 'Planifier RDV'.tr(),
          ),
        ),
        const SizedBox(height: 8),

        // Note
        TextFormField(
          initialValue: report['note'] as String?,
          decoration: InputDecoration(labelText: 'Note'.tr()),
          maxLines: 2,
          onChanged: (t) => setState(() {
            report['note'] = t;
            _reports[id] = report;
          }),
        ),
        const SizedBox(height: 8),

        // Clôture
        SwitchListTile.adaptive(
          title: Text('Clôturé'.tr()),
          value: report['closed'] as bool,
          onChanged: (v) => setState(() {
            report['closed'] = v;
            report['finishedAt'] = v ? FieldValue.serverTimestamp() : null;
            _reports[id] = report;
          }),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final cs = theme.colorScheme;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          title: AutoSizeText(
            'Plan du {date}'.tr(namedArgs: {'date': DateFormat.yMd().format(_date)}),
            maxLines: 1,
            minFontSize: 14,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
            IconButton(
              icon: const Icon(Icons.save),
              color: _allCompleted
                  ? Colors.green
                  : cs.onPrimary.withOpacity(0.4),
              onPressed: _allCompleted ? _onSave : null,
            ),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          backgroundColor: cs.primary,
          child: const Icon(Icons.person_add_alt_1),
          onPressed: () async {
            final result = await Navigator.pushNamed(
              context,
              ProspectFormPage.routeName,
            ) as Prospect?;
            if (result != null) {
              setState(() {
                _options.add(result);
                _reports[result.id] = {
                  'status':'vide','note':'','nextVisit':null,
                  'phone':'','email':'','role':_roles.first,
                  'closed':false,'finishedAt':null,
                };
              });
            }
          },
        ),

        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('Erreur: $_error'.tr()))
              : _options.isEmpty
              ? Center(child: Text('Aucun prospect.'.tr()))
              : Column(
            children: [
              LinearProgressIndicator(
                value: _options.isNotEmpty
                    ? _reports.length / _options.length
                    : 0,
                color: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _options.length,
                  itemBuilder: (_, i) {
                    final p    = _options[i];
                    final done = _reports.containsKey(p.id) && _isComplete(p.id);
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: done ? Colors.green : Colors.transparent,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ExpansionTile(
                        key: ValueKey(p.id),
                        leading: Icon(
                          done
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: done ? Colors.green : Colors.grey,
                        ),
                        title: Text(p.name, style: TextStyle(color: cs.primary)),
                        subtitle: Text(p.address),
                        children: [
                          _buildReportFields(p.id),
                          const Divider(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              label: Text('Supprimer'.tr(), style: TextStyle(color: Colors.red)),
                              onPressed: () => _deleteProspect(p.id),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
