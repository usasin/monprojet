import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';

/// Read-only history: uses the same member-scoped rules as the team calendar.
class MemberHistoryPanel extends StatefulWidget {
  const MemberHistoryPanel(
      {super.key, required this.orgId, required this.memberUid});
  final String orgId, memberUid;
  @override
  State<MemberHistoryPanel> createState() => _MemberHistoryPanelState();
}

class _MemberHistoryPanelState extends State<MemberHistoryPanel> {
  late Future<List<Map<String, dynamic>>> _history = _load();
  Future<List<Map<String, dynamic>>> _load() async {
    final org = FirebaseFirestore.instance
        .collection('apps')
        .doc(kAppId)
        .collection('orgs')
        .doc(widget.orgId);
    final plans = await org
        .collection('memberData')
        .doc(widget.memberUid)
        .collection('plans')
        .orderBy('date', descending: true)
        .limit(30)
        .get();
    final ids = <String>{
      for (final p in plans.docs)
        ...List<String>.from(p.data()['prospectIds'] ?? [])
    };
    final names = <String, String>{};
    // Bounded groups avoid a large burst of parallel reads for a full history.
    final all = ids.toList();
    for (var i = 0; i < all.length; i += 20) {
      final batch = all.skip(i).take(20).toList();
      final docs = await org
          .collection('prospects')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final d in docs.docs) {
        names[d.id] = (d.data()['name'] ?? 'Prospect').toString();
      }
    }
    return plans.docs
        .map((p) => {...p.data(), 'id': p.id, 'names': names})
        .toList();
  }

  @override
  void didUpdateWidget(MemberHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orgId != widget.orgId ||
        oldWidget.memberUid != widget.memberUid) _history = _load();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
          future: _history,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Text(
                  'Historique indisponible. Rouvrez la fiche pour actualiser.');
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.isEmpty)
              return const Text('Aucune tournée enregistrée.');
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tournées & comptes rendus',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Text('Les 30 dernières tournées enregistrées'),
                  ...snapshot.data!.map((plan) {
                    final rawDate = plan['date'];
                    final date = rawDate is Timestamp
                        ? DateFormat('dd/MM/yyyy').format(rawDate.toDate())
                        : plan['id'].toString();
                    final reports =
                        Map<String, dynamic>.from(plan['reports'] ?? {});
                    final names =
                        Map<String, String>.from(plan['names'] as Map);
                    final ids = List<String>.from(plan['prospectIds'] ?? []);
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('$date • ${ids.length} visites'),
                      subtitle: Text(plan['assignedBy'] != null
                          ? 'Tournée attribuée par ${plan['assignedByName'] ?? 'Responsable'}'
                          : 'Tournée personnelle'),
                      children: ids.map((id) {
                        final report =
                            Map<String, dynamic>.from(reports[id] ?? {});
                        final status = report['status']?.toString();
                        final next = report['nextVisit'];
                        return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(names[id] ?? 'Prospect archivé'),
                            subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(status == null || status == 'vide'
                                      ? 'Compte rendu à effectuer'
                                      : 'Résultat : $status'),
                                  if (report['role'] != null &&
                                      report['role'] != 'vide')
                                    Text('Contact : ${report['role']}'),
                                  if ((report['note'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Text(report['note'].toString()),
                                  if (next is Timestamp)
                                    Text(
                                        'Relance : ${DateFormat('dd/MM/yyyy HH:mm').format(next.toDate())}'),
                                ]));
                      }).toList(),
                    );
                  }),
                ]);
          });
}
