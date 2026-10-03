import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/prospect.dart';
import '../pages/prospect_form_page.dart';
import '../pages/select_prospects_page.dart';
import 'sales_editor.dart';
import 'sales_model.dart';
import 'sales_service.dart';

class SalesPortfolio extends StatefulWidget {
  const SalesPortfolio({super.key, required this.orgId});
  final String orgId;
  @override
  State<SalesPortfolio> createState() => _SalesPortfolioState();
}

class _SalesPortfolioState extends State<SalesPortfolio> {
  late final SalesService _service;
  final _search = TextEditingController();
  final _rows = <Prospect>[];
  QueryDocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _busy = false, _complete = false;
  String _filter = 'all';
  String? _error;
  Prospect? _selected;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _service = SalesService(widget.orgId);
    _more();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _more({bool all = false}) async {
    if (_busy || _complete) return;
    setState(() => _busy = true);
    try {
      do {
        Query<Map<String, dynamic>> q =
            _service.org.collection('prospects').orderBy('name').limit(100);
        if (_cursor != null) q = q.startAfterDocument(_cursor!);
        final snap = await q.get(const GetOptions(source: Source.server));
        if (!mounted) return;
        _rows.addAll(
          snap.docs.map((d) => Prospect.fromFirestore(d.data(), d.id)),
        );
        _complete = snap.docs.length < 100;
        if (snap.docs.isNotEmpty) _cursor = snap.docs.last;
      } while (all && !_complete);
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Portefeuille indisponible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _find() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {});
      if (_search.text.isNotEmpty) _more(all: true);
    });
  }

  Future<void> _open(Prospect p) async {
    if (MediaQuery.sizeOf(context).width >= 900) {
      setState(() => _selected = p);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Fiche prospect')),
          body: ProspectSalesDetail(orgId: widget.orgId, prospect: p),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(
    BuildContext context,
  ) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service
            .deals(FirebaseAuth.instance.currentUser!.uid)
            .snapshots(includeMetadataChanges: true),
        builder: (context, snap) {
          final deals = (snap.data?.docs ?? [])
              .where((d) => d.data()['deletedAt'] == null)
              .map(
                (d) => SalesDeal.fromMap(
                  d.id,
                  FirebaseAuth.instance.currentUser!.uid,
                  'Moi',
                  d.data(),
                ),
              )
              .toList();
          final ids = deals
              .where(
                (d) => _filter == 'hot'
                    ? d.open && d.interest == 'hot'
                    : _filter == 'followup'
                        ? d.open &&
                            d.nextAction == 'followup' &&
                            d.nextActionAt != null
                        : _filter == 'won'
                            ? d.stage == 'won'
                            : true,
              )
              .map((d) => d.prospectId)
              .toSet();
          final term = _search.text.trim().toLowerCase();
          final visible = _rows
              .where(
                (p) =>
                    (_filter == 'all' || ids.contains(p.id)) &&
                    ('${p.name} ${p.address} ${p.category}'
                        .toLowerCase()
                        .contains(
                          term,
                        )),
              )
              .toList();
          final content = Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => _find(),
                        decoration: const InputDecoration(
                          hintText: 'Nom, ville, activité',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Ajouter un prospect',
                      icon: const Icon(Icons.person_add_alt),
                      onPressed: () async {
                        await Navigator.pushNamed(
                          context,
                          ProspectFormPage.routeName,
                        );
                        if (mounted) {
                          setState(() {
                            _rows.clear();
                            _cursor = null;
                            _complete = false;
                          });
                          _more(all: term.isNotEmpty || _filter != 'all');
                        }
                      },
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: {
                    'all': 'Tous',
                    'hot': 'Chauds',
                    'followup': 'À relancer',
                    'won': 'Signés',
                  }
                      .entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: _filter == e.key,
                            onSelected: snap.hasError || !snap.hasData
                                ? null
                                : (_) {
                                    setState(() => _filter = e.key);
                                    if (e.key != 'all') _more(all: true);
                                  },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (snap.hasError)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Suivi commercial indisponible. Les filtres de vente ne sont pas utilisables.',
                  ),
                ),
              if (_error != null)
                TextButton(
                  onPressed: () =>
                      _more(all: term.isNotEmpty || _filter != 'all'),
                  child: Text(_error!),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _filter != 'all' && (snap.hasError || !snap.hasData)
                        ? 'Filtre commercial indisponible'
                        : '${visible.length} prospects${_complete ? '' : ' · liste en cours de chargement'}${snap.data?.metadata.isFromCache == true ? ' · suivi en cache' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: _filter != 'all' && snap.hasError
                    ? const Center(
                        child: Text(
                          'Filtre commercial inaccessible. Choisissez Tous ou réessayez avec une connexion.',
                        ),
                      )
                    : _filter != 'all' && !snap.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : visible.isEmpty && !_busy
                            ? const Center(
                                child: Text('Aucun prospect correspondant.'))
                            : ListView.builder(
                                itemCount: visible.length + (_complete ? 0 : 1),
                                itemBuilder: (context, i) {
                                  if (i == visible.length)
                                    return TextButton(
                                      onPressed: _busy ? null : () => _more(),
                                      child: const Text(
                                        'Charger 100 prospects supplémentaires',
                                      ),
                                    );
                                  final p = visible[i];
                                  final opportunities = deals
                                      .where((d) => d.prospectId == p.id)
                                      .toList();
                                  return ListTile(
                                    selected: _selected?.id == p.id,
                                    title: Text(
                                      p.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${p.address}\n${opportunities.length} opportunité(s)',
                                      maxLines: 3,
                                    ),
                                    isThreeLine: true,
                                    leading: Icon(
                                      opportunities.any((d) => d.stage == 'won')
                                          ? Icons.verified_outlined
                                          : opportunities.any(
                                              (d) =>
                                                  d.open && d.interest == 'hot',
                                            )
                                              ? Icons
                                                  .local_fire_department_outlined
                                              : Icons.business_outlined,
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _open(p),
                                  );
                                },
                              ),
              ),
            ],
          );
          if (MediaQuery.sizeOf(context).width < 900) return content;
          return Row(
            children: [
              Expanded(flex: 4, child: content),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 5,
                child: _selected == null
                    ? const Center(child: Text('Sélectionnez un prospect'))
                    : ProspectSalesDetail(
                        key: ValueKey(_selected!.id),
                        orgId: widget.orgId,
                        prospect: _selected!,
                      ),
              ),
            ],
          );
        },
      );
}

class ProspectSalesDetail extends StatelessWidget {
  const ProspectSalesDetail({
    super.key,
    required this.orgId,
    required this.prospect,
  });
  final String orgId;
  final Prospect prospect;
  Future<void> _edit(BuildContext context, SalesDeal? deal) async {
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) =>
            SalesEditor(orgId: orgId, prospect: prospect, deal: deal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = SalesService(orgId);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service
          .deals(uid)
          .where('prospectId', isEqualTo: prospect.id)
          .snapshots(),
      builder: (context, snap) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(prospect.name, style: Theme.of(context).textTheme.titleLarge),
          Text(prospect.address),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((prospect.phone ?? '').isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () =>
                      launchUrl(Uri(scheme: 'tel', path: prospect.phone)),
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('Appeler'),
                ),
              if ((prospect.email ?? '').isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () =>
                      launchUrl(Uri(scheme: 'mailto', path: prospect.email)),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('E-mail'),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 2),
                  );
                  if (date != null && context.mounted)
                    await Navigator.pushNamed(
                      context,
                      SelectProspectsPage.routeName,
                      arguments: {
                        'seedIds': [prospect.id],
                        'dateMs': date.millisecondsSinceEpoch,
                      },
                    );
                },
                icon: const Icon(Icons.route_outlined),
                label: const Text('Ajouter à une tournée'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle opportunité'),
          ),
          const SizedBox(height: 16),
          Text(
            'Mes opportunités',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (snap.hasError)
            const Text(
              'Impossible de charger le suivi. Actualisez votre connexion.',
            ),
          if (!snap.hasData) const LinearProgressIndicator(),
          ...?(snap.data?.docs.where((d) => d.data()['deletedAt'] == null).map((
            doc,
          ) {
            final d = SalesDeal.fromMap(doc.id, uid, 'Moi', doc.data());
            return Card(
              child: ListTile(
                title: Text(d.title),
                subtitle: Text(
                  '${salesStages[d.stage]} · ${salesInterests[d.interest]}${d.nextActionAt == null ? '' : '\n${salesActions[d.nextAction]} · ${DateFormat('dd/MM HH:mm').format(d.nextActionAt!)}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _edit(context, d),
              ),
            );
          })),
          if (snap.hasData &&
              snap.data!.docs
                  .where((d) => d.data()['deletedAt'] == null)
                  .isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Aucune opportunité. Créez un projet à suivre pour ce prospect.',
              ),
            ),
          if ((prospect.note ?? '').isNotEmpty)
            ExpansionTile(
              title: const Text('Note du répertoire'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(prospect.note!),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
