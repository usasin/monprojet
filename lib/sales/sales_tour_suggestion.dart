import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../pages/select_prospects_page.dart';
import 'sales_model.dart';
import 'sales_service.dart';

class SalesTourSuggestion extends StatefulWidget {
  const SalesTourSuggestion({super.key, required this.orgId});
  final String orgId;
  @override
  State<SalesTourSuggestion> createState() => _SalesTourSuggestionState();
}

class _SalesTourSuggestionState extends State<SalesTourSuggestion> {
  late final Future<List<SalesDeal>> _future;
  final _selected = <String>{};
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    _future = SalesService(widget.orgId).load([
      {'uid': FirebaseAuth.instance.currentUser!.uid, 'name': 'Moi'},
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Préparer une tournée prioritaire')),
        body: FutureBuilder<List<SalesDeal>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError)
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Suivi commercial indisponible. Réessayez avec une connexion.',
                  ),
                ),
              );
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            final now = DateTime.now();
            final rows = snap.data!
                .where((d) => d.open && (d.overdue(now) || d.interest == 'hot'))
                .toList();
            rows.sort((a, b) {
              final priority = (a.overdue(now) ? 0 : 1).compareTo(
                b.overdue(now) ? 0 : 1,
              );
              if (priority != 0) return priority;
              return (a.nextActionAt ?? DateTime(2100)).compareTo(
                b.nextActionAt ?? DateTime(2100),
              );
            });
            final unique = <String, SalesDeal>{};
            for (final d in rows) {
              unique.putIfAbsent(d.prospectId, () => d);
            }
            if (!_initialized) {
              _selected.addAll(unique.keys.take(8));
              _initialized = true;
            }
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Échéances dépassées en premier, puis affaires chaudes. Une visite par prospect. Vérifiez qu’une visite est adaptée à la prochaine action ; vous pouvez décocher chaque suggestion.',
                  ),
                ),
                Expanded(
                  child: unique.isEmpty
                      ? const Center(
                          child:
                              Text('Aucune priorité commerciale enregistrée.'),
                        )
                      : ListView(
                          children: unique.values
                              .map(
                                (d) => CheckboxListTile(
                                  title: Text(d.prospectName),
                                  subtitle: Text(
                                    d.overdue(now)
                                        ? 'Échéance dépassée · ${salesActions[d.nextAction]}'
                                        : 'Affaire chaude · ${salesStages[d.stage]}',
                                  ),
                                  value: _selected.contains(d.prospectId),
                                  onChanged: (v) => setState(() {
                                    if (v == true && _selected.length < 50)
                                      _selected.add(d.prospectId);
                                    else
                                      _selected.remove(d.prospectId);
                                  }),
                                ),
                              )
                              .toList(),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: now,
                                firstDate:
                                    DateTime(now.year, now.month, now.day),
                                lastDate: DateTime(now.year + 2),
                              );
                              if (date == null || !context.mounted) return;
                              await Navigator.pushNamed(
                                context,
                                SelectProspectsPage.routeName,
                                arguments: {
                                  'seedIds': _selected.toList(),
                                  'dateMs': date.millisecondsSinceEpoch,
                                },
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                      icon: const Icon(Icons.route_outlined),
                      label:
                          Text('Préparer avec ${_selected.length} prospects'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
