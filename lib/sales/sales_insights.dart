import '../widgets/reporting_charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../theme/prospecto_colors.dart';
import '../models/prospect.dart';
import '../providers/org_provider.dart';
import '../services/org_service.dart';
import 'sales_editor.dart';
import 'sales_model.dart';
import 'sales_service.dart';

class SalesInsights extends StatefulWidget {
  const SalesInsights({super.key, this.summary = false});
  final bool summary;
  @override
  State<SalesInsights> createState() => _SalesInsightsState();
}

class _SalesInsightsState extends State<SalesInsights> {
  String _period = 'week', _member = 'all';
  String? _scope;
  Future<List<SalesDeal>>? _future;
  List<Map<String, String>> _members = [];
  DateTime? _readAt;
  void _refresh(String orgId) {
    _readAt = null;
    _future = SalesService(orgId).load(_members).then((v) {
      _readAt = DateTime.now();
      return v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (!org.isTeam) {
      return _results(context, org, uid, [
        {'uid': uid, 'name': 'Moi', 'manager': ''},
      ], const {});
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: OrgService(
        kAppId,
      ).allMembers((org.isTeam ? org.orgId! : ''), role: org.role, uid: uid),
      builder: (context, members) {
        if (members.hasError)
          return const SalesError('Équipe inaccessible. Réessayez.');
        if (!members.hasData)
          return const Center(child: CircularProgressIndicator());
        final next = members.data!.docs
            .where((d) => d.data()['role'] == 'REP')
            .map(
              (d) => {
                'uid': d.id,
                'name': memberDisplay(d.data()),
                'manager': (d.data()['managerUid'] ?? '').toString(),
              },
            )
            .toList();
        if (next.isEmpty)
          return widget.summary
              ? const SizedBox.shrink()
              : const SalesError(
                  'Aucun commercial rattaché. Les équipes sont attribuées par votre administrateur.',
                );
        final names = {
          for (final d in members.data!.docs.where(
            (d) => d.data()['role'] == 'MANAGER',
          ))
            d.id: memberDisplay(d.data()),
        };
        return _results(context, org, uid, next, names);
      },
    );
  }

  Widget _results(
    BuildContext context,
    OrgProvider org,
    String uid,
    List<Map<String, String>> next,
    Map<String, String> managerNames,
  ) {
    final signature =
        '${org.orgId}:${org.role}:$uid:${next.map((m) => '${m['uid']}:${m['name']}:${m['manager']}').join('|')}';
    if (_scope != signature) {
      _scope = signature;
      _members = next;
      _member = 'all';
      _refresh((org.isTeam ? org.orgId! : ''));
    }
    return FutureBuilder<List<SalesDeal>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Résultats indisponibles. Réessayez.'),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _refresh((org.isTeam ? org.orgId! : ''))),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final now = DateTime.now();
        final window = SalesWindow.forPeriod(now, _period);
        final all = snap.data!
            .where((d) => _member == 'all' || d.ownerUid == _member)
            .toList();
        final totals = SalesTotals(all, window, now);
        final children = <Widget>[
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.summary
                      ? 'Priorités commerciales'
                      : 'Résultats commerciaux',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: () =>
                    setState(() => _refresh((org.isTeam ? org.orgId! : ''))),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (!widget.summary) ...[
            Wrap(
              spacing: 8,
              children:
                  {'day': 'Aujourd’hui', 'week': 'Semaine', 'month': 'Mois'}
                      .entries
                      .map(
                        (e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _period == e.key,
                          onSelected: (_) => setState(() => _period = e.key),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '${DateFormat('dd/MM/yyyy').format(window.start)} → ${DateFormat('dd/MM/yyyy').format(window.end.subtract(const Duration(days: 1)))} · ${org.isOwner ? 'Entreprise' : org.canManageTeam ? 'Mon équipe' : 'Moi'}',
            ),
            if (org.canManageTeam)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: DropdownButtonFormField<String>(
                  value: _member,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Commercial',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Tous les commerciaux du périmètre'),
                    ),
                    ..._members.map(
                      (m) => DropdownMenuItem(
                        value: m['uid'],
                        child: Text(
                          m['name']!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _member = v);
                  },
                ),
              ),
          ],
          if (widget.summary)
            Text(
              'Suivi actuel · signés cette semaine',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          SalesMetricGrid(
            items: [
              SalesMetric(
                'Chaudes',
                '${totals.hot.length}',
                Icons.local_fire_department_outlined,
                () => _list(context, 'Opportunités chaudes', totals.hot),
              ),
              SalesMetric(
                'À traiter',
                '${totals.overdue.length}',
                Icons.schedule,
                () => _list(context, 'À traiter', totals.overdue),
              ),
              if (org.displaySettings.showContracts)
                SalesMetric(
                  'Signés',
                  '${totals.won.length}',
                  Icons.verified_outlined,
                  () => _list(context, 'Signés', totals.won),
                ),
              if (org.displaySettings.showContracts)
                SalesMetric(
                  'Taux de gain',
                  totals.winRate == null
                      ? '—'
                      : '${(totals.winRate! * 100).toStringAsFixed(0)} %',
                  Icons.trending_up,
                  () => _list(context, 'Affaires clôturées', [
                    ...totals.won,
                    ...totals.lost,
                  ]),
                ),
            ],
          ),
          ReportingChartGrid(
            charts: [
              if (org.displaySettings.showContracts)
                ReportingDonut(
                  title: 'Contrats signés / perdus',
                  subtitle:
                      widget.summary ? 'Cette semaine' : 'Période sélectionnée',
                  centerValue: totals.winRate == null
                      ? null
                      : '${(totals.winRate! * 100).round()} %',
                  centerLabel: 'taux de gain',
                  emptyLabel: 'Aucune affaire clôturée sur cette période',
                  slices: [
                    ReportSlice(
                      'Signés',
                      totals.won.length,
                      ProspectoColors.green,
                      onTap: () =>
                          _list(context, 'Contrats signés', totals.won),
                    ),
                    ReportSlice(
                      'Perdus',
                      totals.lost.length,
                      const Color(0xFFEF4444),
                      onTap: () =>
                          _list(context, 'Affaires perdues', totals.lost),
                    ),
                  ],
                ),
              if (!widget.summary)
                ReportingDonut(
                  title: 'Avancement des opportunités',
                  subtitle: 'État actuel · toutes dates',
                  centerLabel: 'affaires',
                  slices: [
                    for (final entry in salesStages.entries)
                      ReportSlice(
                        entry.value,
                        all.where((d) => d.stage == entry.key).length,
                        const {
                          'qualify': Color(0xFF94A3B8),
                          'qualified': ProspectoColors.blue,
                          'proposal': Color(0xFF818CF8),
                          'negotiation': Color(0xFFF59E0B),
                          'won': ProspectoColors.green,
                          'lost': Color(0xFFEF4444),
                        }[entry.key]!,
                        onTap: () => _list(
                          context,
                          entry.value,
                          all.where((d) => d.stage == entry.key).toList(),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (!widget.summary && org.displaySettings.showRevenue)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      totals.won.isNotEmpty &&
                              totals.won.length == totals.missingAmounts
                          ? 'Montants non renseignés'
                          : 'Signé HT : ${money(totals.signedCents)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('En cours : ${money(totals.openCents)}'),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Comprendre les chiffres'),
                      children: [
                        Text(
                          '${totals.missingAmounts} contrat(s) sans montant. '
                          'Taux de gain = signés ÷ (signés + perdus) sur la période. '
                          'Les affaires ouvertes sont exclues. Les montants sont déclarés, pas encaissés. '
                          'L’avancement montre l’état actuel de toutes les affaires. '
                          'Les corrections restent dans l’historique.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'À traiter en priorité',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ..._priorities(totals).take(widget.summary ? 4 : 10).map(
                (p) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(p.$1),
                    subtitle: Text('${p.$2.prospectName} · ${p.$2.ownerName}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await openSalesDeal(
                        context,
                        (org.isTeam ? org.orgId! : ''),
                        p.$2,
                        readOnly: org.canManageTeam,
                      );
                      if (mounted)
                        setState(
                          () => _refresh((org.isTeam ? org.orgId! : '')),
                        );
                    },
                  ),
                ),
              ),
          if (_priorities(totals).isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Aucune alerte dans le suivi enregistré.'),
            ),
          if (!widget.summary && org.canManageTeam) ...[
            const SizedBox(height: 16),
            Text(
              'Résultats par commercial',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ..._members
                .where((m) => _member == 'all' || _member == m['uid'])
                .map((
              m,
            ) {
              final t = SalesTotals(
                all.where((d) => d.ownerUid == m['uid']),
                window,
                now,
              );
              return ListTile(
                title: Text(m['name']!),
                subtitle: Text(
                  '${_resultSummary(t, org)}${org.isOwner ? '\nÉquipe : ${managerNames[m['manager']] ?? 'Sans responsable'}' : ''}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _list(
                  context,
                  m['name']!,
                  all.where((d) => d.ownerUid == m['uid']).toList(),
                ),
              );
            }),
            if (org.isOwner)
              ExpansionTile(
                title: const Text('Résultats par responsable'),
                children: [
                  ...managerNames.entries.map((e) {
                    final ids = _members
                        .where((m) => m['manager'] == e.key)
                        .map((m) => m['uid'])
                        .toSet();
                    final t = SalesTotals(
                      all.where((d) => ids.contains(d.ownerUid)),
                      window,
                      now,
                    );
                    return ListTile(
                      title: Text(e.value),
                      subtitle: Text(
                        '${_resultSummary(t, org)} · ${t.overdue.length} actions en retard',
                      ),
                      onTap: () => _list(
                        context,
                        'Équipe ${e.value}',
                        all.where((d) => ids.contains(d.ownerUid)).toList(),
                      ),
                    );
                  }),
                ],
              ),
          ],
          if (_readAt != null)
            Text(
              'Actualisé à ${DateFormat('HH:mm').format(_readAt!)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ];
        return widget.summary
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              )
            : ListView(padding: const EdgeInsets.all(16), children: children);
      },
    );
  }

  List<(String, SalesDeal)> _priorities(SalesTotals t) {
    final map = <String, (String, SalesDeal)>{};
    for (final d in t.overdue) {
      map['${d.ownerUid}:${d.id}'] = (
        'Échéance dépassée : ${salesActions[d.nextAction]}',
        d,
      );
    }
    for (final d in t.unsigned) {
      map.putIfAbsent(
        '${d.ownerUid}:${d.id}',
        () => ('Affaire chaude sans prochaine action', d),
      );
    }
    for (final d in t.stagnant) {
      map.putIfAbsent(
        '${d.ownerUid}:${d.id}',
        () => ('Sans mise à jour depuis 14 jours', d),
      );
    }
    return map.values.toList();
  }

  Future<void> _list(
    BuildContext context,
    String title,
    List<SalesDeal> deals,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: deals.isEmpty
              ? const Center(child: Text('Aucune opportunité.'))
              : ListView.builder(
                  itemCount: deals.length,
                  itemBuilder: (ctx, i) {
                    final d = deals[i];
                    return ListTile(
                      title: Text('${d.prospectName} · ${d.title}'),
                      subtitle: Text(
                        '${d.ownerName} · ${salesStages[d.stage]}${context.read<OrgProvider>().displaySettings.showRevenue && d.amountCents != null ? ' · ${money(d.amountCents!)}' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openSalesDeal(
                        ctx,
                        (context.read<OrgProvider>().isTeam
                            ? context.read<OrgProvider>().orgId!
                            : ''),
                        d,
                        readOnly: context.read<OrgProvider>().canManageTeam,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
    if (mounted)
      setState(
        () => _refresh(
          (this.context.read<OrgProvider>().isTeam
              ? this.context.read<OrgProvider>().orgId!
              : ''),
        ),
      );
  }
}

String memberDisplay(Map<String, dynamic> d) {
  final full = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();
  return full.isNotEmpty
      ? full
      : '${d['displayName'] ?? d['email'] ?? 'Commercial'}';
}

String money(int cents) => NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
      decimalDigits: 2,
    ).format(cents / 100);
Future<bool?> openSalesDeal(
  BuildContext context,
  String orgId,
  SalesDeal d, {
  required bool readOnly,
}) async {
  return await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => SalesEditor(
        orgId: orgId,
        prospect: Prospect(
          id: d.prospectId,
          name: d.prospectName,
          address: '',
          category: '',
          lat: 0,
          lng: 0,
        ),
        deal: d,
        readOnly: readOnly,
      ),
    ),
  );
}

class SalesMetric {
  const SalesMetric(this.label, this.value, this.icon, this.onTap);
  final String label, value;
  final IconData icon;
  final VoidCallback onTap;
}

class SalesMetricGrid extends StatelessWidget {
  const SalesMetricGrid({super.key, required this.items});
  final List<SalesMetric> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth >= 700 ? 4 : 2;
          final w = (c.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (m) => SizedBox(
                    width: w,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: m.onTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: (m.icon == Icons.verified_outlined
                                          ? ProspectoColors.green
                                          : m.icon ==
                                                  Icons
                                                      .local_fire_department_outlined
                                              ? ProspectoColors.peach
                                              : ProspectoColors.blue)
                                      .withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  m.icon,
                                  size: 20,
                                  color: m.icon == Icons.verified_outlined
                                      ? ProspectoColors.green
                                      : ProspectoColors.blue,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                m.value,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(m.label,
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
}

class SalesError extends StatelessWidget {
  const SalesError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
      );
}

String _resultSummary(SalesTotals totals, OrgProvider org) => [
      if (org.displaySettings.showContracts) '${totals.won.length} signés',
      if (org.displaySettings.showRevenue)
        totals.won.isNotEmpty && totals.missingAmounts == totals.won.length
            ? 'Montants non renseignés'
            : money(totals.signedCents),
      if (org.displaySettings.showContracts)
        totals.winRate == null
            ? 'Gain : —'
            : 'Gain : ${(totals.winRate! * 100).round()} %',
    ].join(' · ');
