import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../models/prospect.dart';
import 'sales_model.dart';
import 'sales_service.dart';
import 'sales_visuals.dart';
import 'enterprise_actions.dart';
import '../widgets/brand_background.dart';
import '../providers/org_provider.dart';
import 'package:provider/provider.dart';

class SalesEditor extends StatefulWidget {
  const SalesEditor({
    super.key,
    required this.orgId,
    required this.prospect,
    this.deal,
    this.readOnly = false,
  });
  final String orgId;
  final Prospect prospect;
  final SalesDeal? deal;
  final bool readOnly;
  @override
  State<SalesEditor> createState() => _SalesEditorState();
}

class _SalesEditorState extends State<SalesEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _amount = TextEditingController(),
      _offer = TextEditingController();
  final _reference = TextEditingController(),
      _note = TextEditingController(),
      _lost = TextEditingController(),
      _correction = TextEditingController();
  late final SalesService _service;
  late String _id, _draftId;
  String _stage = 'qualify', _interest = 'warm', _action = '';
  DateTime? _due, _signed;
  int _expected = 0;
  bool _saving = false, _loading = true, _dirty = false;
  String? _error;
  bool _conflict = false;
  SalesDeal? _baseDeal;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _service = SalesService(widget.orgId);
    _id = widget.deal?.id ?? _service.newId();
    _draftId = widget.deal?.id ?? 'new:${widget.prospect.id}';
    final d = widget.deal;
    _baseDeal = d;
    _title.text = d?.title ?? 'Projet ${widget.prospect.name}';
    _amount.text = d?.amountCents == null
        ? ''
        : (d!.amountCents! / 100).toStringAsFixed(2);
    _offer.text = d?.offer ?? '';
    _reference.text = d?.contractReference ?? '';
    _note.text = d?.note ?? '';
    _lost.text = d?.lostReason ?? '';
    _stage = d?.stage ?? 'qualify';
    _interest = d?.interest ?? 'warm';
    _action = d?.nextAction ?? '';
    _due = d?.nextActionAt;
    _signed = d?.signedAt;
    _expected = d?.revision ?? 0;
    _restore();
  }

  Future<void> _restore() async {
    try {
      if (!widget.readOnly) {
        final draft = await _service.draft(_draftId);
        if (draft != null && mounted) {
          _id = '${draft['opportunityId'] ?? _id}';
          _expected = (draft['expectedRevision'] as num?)?.toInt() ?? _expected;
          _title.text = '${draft['title'] ?? _title.text}';
          _amount.text = '${draft['amountText'] ?? _amount.text}';
          _offer.text = '${draft['offer'] ?? ''}';
          _reference.text = '${draft['contractReference'] ?? ''}';
          _note.text = '${draft['note'] ?? ''}';
          _lost.text = '${draft['lostReason'] ?? ''}';
          _correction.text = '${draft['correctionReason'] ?? ''}';
          _stage = '${draft['stage'] ?? _stage}';
          _interest = '${draft['interest'] ?? _interest}';
          _action = '${draft['nextAction'] ?? _action}';
          _due = salesDate(draft['nextActionAtMs']);
          _signed = salesDate(draft['signedAtMs']);
          _dirty = true;
        }
      }
    } catch (_) {
      _error = 'Impossible de lire le brouillon local.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> _draftValues() => {
    'opportunityId': _id,
    'prospectId': widget.prospect.id,
    'expectedRevision': _expected,
    'title': _title.text,
    'amountText': _amount.text,
    'offer': _offer.text,
    'contractReference': _reference.text,
    'note': _note.text,
    'lostReason': _lost.text,
    'correctionReason': _correction.text,
    'stage': _stage,
    'interest': _interest,
    'nextAction': _action,
    'nextActionAtMs': _due?.millisecondsSinceEpoch,
    'signedAtMs': _signed?.millisecondsSinceEpoch,
  };
  void _changed() {
    if (_loading || widget.readOnly) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 400), () async {
      try {
        await _service.saveDraft(_draftId, _draftValues());
      } catch (_) {
        if (mounted)
          setState(
            () => _error =
                'Brouillon local non enregistré. Gardez cet écran ouvert et réessayez.',
          );
      }
    });
    setState(() {});
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due ?? now),
    );
    if (time == null || !mounted) return;
    _due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    _changed();
  }

  Future<void> _pickSigned() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _signed ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (date != null && mounted) {
      _signed = date;
      _changed();
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_stage == 'won' && _signed == null) {
      setState(() => _error = 'Choisissez la date de signature.');
      return;
    }
    if (_action.isNotEmpty &&
        _due == null &&
        _stage != 'won' &&
        _stage != 'lost') {
      setState(() => _error = 'Choisissez l’échéance de la prochaine action.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _conflict = false;
    });
    _timer?.cancel();
    try {
      await _service.saveDraft(_draftId, _draftValues());
      final values = _draftValues()
        ..remove('amountText')
        ..remove('opportunityId');
      values['amountCents'] = parseSalesAmount(_amount.text);
      if (_stage == 'won' || _stage == 'lost') {
        values['nextAction'] = '';
        values['nextActionAtMs'] = null;
      }
      await _service.save(_id, values);
      await _service.clearDraft(_draftId);
      _dirty = false;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _conflict = e is FirebaseFunctionsException && e.code == 'aborted';
      if (mounted)
        setState(
          () => _error = e is FirebaseFunctionsException
              ? (e.message ?? 'Enregistrement refusé.')
              : 'Enregistrement impossible. Votre brouillon est conservé ; vérifiez la connexion.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reloadCurrent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Charger la version enregistrée ?'),
        content: const Text(
          'Le brouillon local sera remplacé. Copiez vos modifications si vous souhaitez les conserver.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Conserver mon brouillon'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Charger'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _timer?.cancel();
    setState(() => _saving = true);
    try {
      final d = await _service.currentDeal(_id);
      if (d == null) throw StateError('Opportunité introuvable');
      await _service.clearDraft(_draftId);
      if (!mounted) return;
      setState(() {
        _baseDeal = d;
        _expected = d.revision;
        _title.text = d.title;
        _amount.text = d.amountCents == null
            ? ''
            : (d.amountCents! / 100).toStringAsFixed(2);
        _offer.text = d.offer;
        _reference.text = d.contractReference;
        _note.text = d.note;
        _lost.text = d.lostReason;
        _correction.clear();
        _stage = d.stage;
        _interest = d.interest;
        _action = d.nextAction;
        _due = d.nextActionAt;
        _signed = d.signedAt;
        _dirty = false;
        _conflict = false;
        _error = null;
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _error =
              'Version enregistrée inaccessible. Le brouillon est conservé.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [
      _title,
      _amount,
      _offer,
      _reference,
      _note,
      _lost,
      _correction,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    bool money = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          style: const TextStyle(fontSize: 15),
          controller: c,
          readOnly: widget.readOnly || _saving,
          maxLines: lines,
          keyboardType: money
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: .9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (_) => _changed(),
          validator: (v) {
            if (required && (v ?? '').trim().isEmpty)
              return 'Champ obligatoire';
            if (money) {
              try {
                parseSalesAmount(v ?? '');
              } catch (e) {
                return 'Montant positif, 2 décimales maximum';
              }
            }
            return null;
          },
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final d = _baseDeal;
    final org = context.watch<OrgProvider>();
    final revenue = widget.orgId.isEmpty || org.displaySettings.showRevenue;
    if (widget.readOnly && d != null) {
      return BrandBackground(
        animate: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Opportunité'),
            backgroundColor: Colors.transparent,
            actions: [
              if (org.isOwner && org.orgId == widget.orgId)
                IconButton(
                  tooltip: 'Supprimer l’opportunité',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await EnterpriseActions.remove(
                          context,
                          widget.orgId,
                          'opportunity',
                          d.id,
                          ownerUid: d.ownerUid,
                        ) &&
                        context.mounted)
                      Navigator.pop(context, true);
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OpportunityDetailContent(deal: d, showRevenue: revenue),
              const SizedBox(height: 14),
              VisualSection(
                title: 'Historique',
                icon: Icons.history,
                child: _History(service: _service, deal: d),
              ),
            ],
          ),
        ),
      );
    }
    return WillPopScope(
      onWillPop: () async {
        if (_saving) return false;
        _timer?.cancel();
        if (_dirty && !widget.readOnly) {
          try {
            await _service.saveDraft(_draftId, _draftValues());
          } catch (_) {
            if (mounted)
              setState(
                () =>
                    _error = 'Impossible de conserver le brouillon. Réessayez.',
              );
            return false;
          }
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.readOnly ? 'Opportunité' : 'Suivi commercial'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    VisualHero(
                      title: widget.prospect.name,
                      subtitle: d?.ownerName ?? 'Votre suivi commercial',
                      icon: Icons.business_center_outlined,
                      badges: [
                        SalesBadge(
                          salesStages[_stage]!,
                          color: stageColor(_stage),
                        ),
                        SalesBadge(salesInterests[_interest]!),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_dirty && !widget.readOnly)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Brouillon local · non comptabilisé dans les résultats',
                        ),
                      ),
                    _field(_title, 'Nom de l’opportunité', required: true),
                    DropdownButtonFormField<String>(
                      value: _stage,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Avancement',
                        border: OutlineInputBorder(),
                      ),
                      items: salesStages.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: widget.readOnly || _saving
                          ? null
                          : (v) {
                              if (v != null) {
                                _stage = v;
                                _changed();
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: salesInterests.entries
                          .map(
                            (e) => ChoiceChip(
                              label: Text(e.value),
                              selected: _interest == e.key,
                              onSelected: widget.readOnly || _saving
                                  ? null
                                  : (_) {
                                      _interest = e.key;
                                      _changed();
                                    },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    if (revenue)
                      _field(
                        _amount,
                        'Montant HT estimé ou signé (€) · facultatif',
                        money: true,
                      ),
                    _field(
                      _offer,
                      'Offre / contrat',
                      required: _stage == 'won',
                    ),
                    if (_stage == 'won') ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.verified_outlined),
                        title: Text(
                          _signed == null
                              ? 'Date de signature obligatoire'
                              : DateFormat('dd/MM/yyyy').format(_signed!),
                        ),
                        trailing: const Icon(Icons.edit_calendar),
                        onTap: widget.readOnly || _saving ? null : _pickSigned,
                      ),
                      _field(_reference, 'Référence du contrat · facultative'),
                    ],
                    if (_stage == 'lost')
                      _field(_lost, 'Motif de perte', required: true, lines: 2),
                    if (_stage != 'won' && _stage != 'lost') ...[
                      DropdownButtonFormField<String>(
                        value: _action,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Prochaine action',
                          border: OutlineInputBorder(),
                        ),
                        items: salesActions.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: widget.readOnly || _saving
                            ? null
                            : (v) {
                                if (v != null) {
                                  _action = v;
                                  if (v.isEmpty) _due = null;
                                  _changed();
                                }
                              },
                      ),
                      if (_action.isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule),
                          title: Text(
                            _due == null
                                ? 'Choisir l’échéance'
                                : DateFormat('dd/MM/yyyy HH:mm').format(_due!),
                          ),
                          onTap: widget.readOnly || _saving ? null : _pickDue,
                        ),
                      const SizedBox(height: 12),
                    ],
                    _field(_note, 'Note', lines: 3),
                    if (d != null && !d.open)
                      _field(
                        _correction,
                        'Motif si correction d’une affaire clôturée',
                        lines: 2,
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_conflict)
                      TextButton.icon(
                        onPressed: _saving ? null : _reloadCurrent,
                        icon: const Icon(Icons.sync),
                        label: const Text('Charger la version enregistrée'),
                      ),
                    if (d != null) _History(service: _service, deal: d),
                  ],
                ),
              ),
        bottomNavigationBar: widget.readOnly
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    onPressed: _saving || _loading ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving
                          ? 'Enregistrement…'
                          : _stage == 'won'
                          ? 'Enregistrer le contrat signé'
                          : 'Enregistrer le suivi',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _History extends StatefulWidget {
  const _History({required this.service, required this.deal});
  final SalesService service;
  final SalesDeal deal;
  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  int _limit = 10;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Historique des modifications'),
    children: [
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.service
            .deals(widget.deal.ownerUid)
            .doc(widget.deal.id)
            .collection('history')
            .orderBy('revision', descending: true)
            .limit(_limit)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError)
            return const ListTile(title: Text('Historique indisponible.'));
          if (!snap.hasData) return const LinearProgressIndicator();
          return Column(
            children: [
              ...snap.data!.docs.map((doc) {
                final e = doc.data();
                final after = Map<String, dynamic>.from(
                  e['after'] as Map? ?? {},
                );
                final at = salesDate(e['at']);
                return ListTile(
                  title: Text(
                    '${salesStages[after['stage']] ?? after['stage']} · révision ${e['revision']}',
                  ),
                  subtitle: Text(
                    '${at == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(at)}${(e['correctionReason'] ?? '').toString().isEmpty ? '' : '\n${e['correctionReason']}'}',
                  ),
                );
              }),
              if (snap.data!.docs.length == _limit)
                TextButton(
                  onPressed: () => setState(() => _limit += 20),
                  child: const Text('Voir plus'),
                ),
            ],
          );
        },
      ),
    ],
  );
}

/// Read-only business summary, without disabled form controls.
class OpportunityDetailContent extends StatelessWidget {
  const OpportunityDetailContent({
    super.key,
    required this.deal,
    this.showRevenue = true,
  });
  final SalesDeal deal;
  final bool showRevenue;
  @override
  Widget build(BuildContext context) {
    final d = deal;
    final stages = ['qualify', 'qualified', 'proposal', 'negotiation', 'won'];
    final step = stages.indexOf(d.stage);
    Widget line(IconData icon, String title, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: stageColor(d.stage)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VisualHero(
          title: d.prospectName,
          subtitle: d.title,
          icon: Icons.business_center_outlined,
          badges: [
            SalesBadge(
              salesStages[d.stage] ?? d.stage,
              color: stageColor(d.stage),
            ),
            if (d.open) SalesBadge(salesInterests[d.interest] ?? d.interest),
          ],
        ),
        const SizedBox(height: 14),
        VisualSection(
          title: 'Avancement',
          icon: Icons.trending_up,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (step >= 0) ...[
                LinearProgressIndicator(
                  value: (step + 1) / stages.length,
                  color: stageColor(d.stage),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 12),
              ],
              line(Icons.person_outline, 'Commercial', d.ownerName),
              if (d.signedAt != null)
                line(
                  Icons.verified_outlined,
                  'Signé le',
                  DateFormat('dd MMM yyyy', 'fr_FR').format(d.signedAt!),
                ),
              if (d.lostReason.isNotEmpty)
                line(Icons.info_outline, 'Motif de perte', d.lostReason),
            ],
          ),
        ),
        if (showRevenue) ...[
          const SizedBox(height: 14),
          VisualSection(
            title: 'Montant HT',
            icon: Icons.payments_outlined,
            child: Text(
              d.amountCents == null
                  ? 'Non renseigné'
                  : displayMoney(d.amountCents!),
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
            ),
          ),
        ],
        if (d.offer.isNotEmpty || d.contractReference.isNotEmpty) ...[
          const SizedBox(height: 14),
          VisualSection(
            title: 'Offre et contrat',
            icon: Icons.description_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (d.offer.isNotEmpty)
                  Text(d.offer, style: const TextStyle(fontSize: 14)),
                if (d.contractReference.isNotEmpty)
                  Text(
                    'Référence : ${d.contractReference}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
        if (d.open && d.nextActionAt != null) ...[
          const SizedBox(height: 14),
          VisualSection(
            title: 'Prochaine action',
            icon: Icons.schedule,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salesActions[d.nextAction] ?? 'Action',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat(
                    'dd MMM yyyy · HH:mm',
                    'fr_FR',
                  ).format(d.nextActionAt!),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
        if (d.note.isNotEmpty) ...[
          const SizedBox(height: 14),
          VisualSection(
            title: 'Notes',
            icon: Icons.notes,
            child: Text(d.note, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ],
    );
  }
}
