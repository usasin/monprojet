import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../pages/map_page.dart';
import '../pages/reporting_page.dart';
import '../pages/select_prospects_page.dart';
import '../theme/prospecto_colors.dart';
import '../models/route_metrics.dart';

class SoloToday extends StatelessWidget {
  const SoloToday({super.key});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('plans')
          .doc(DateFormat('yyyy-MM-dd').format(now))
          .snapshots(),
      builder: (context, snap) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('EEEE d MMMM', 'fr_FR').format(now),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (snap.hasError)
            const Text('Activité indisponible. Réessayez avec une connexion.')
          else if (!snap.hasData)
            const LinearProgressIndicator()
          else
            _ActivityNumbers(
                metrics: RouteMetrics.fromPlans([snap.data?.data() ?? {}])),
        ]),
      )),
    );
  }
}

class _ActivityNumbers extends StatelessWidget {
  const _ActivityNumbers({required this.metrics});
  final RouteMetrics metrics;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${metrics.completed} / ${metrics.planned} visites',
            style: Theme.of(context).textTheme.headlineSmall),
        if (metrics.planned > 0) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: metrics.completionRate, color: ProspectoColors.green),
        ] else
          const Text('Aucune tournée prévue'),
      ]);
}

/// A tour is a dated plan. A prospect remains in the separate portfolio.
class SoloTours extends StatelessWidget {
  const SoloTours({super.key, this.firestore, this.userUid});
  final FirebaseFirestore? firestore;
  final String? userUid;
  @override
  Widget build(
    BuildContext context,
  ) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: (firestore ?? FirebaseFirestore.instance)
            .collection('users')
            .doc(userUid ?? FirebaseAuth.instance.currentUser!.uid)
            .collection('plans')
            .orderBy(FieldPath.documentId, descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError)
            return const Center(
              child:
                  Text('Tournées indisponibles. Réessayez avec une connexion.'),
            );
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final tours = snap.data!.docs
              .where(
                (d) =>
                    (d.data()['prospectIds'] as List? ?? []).isNotEmpty &&
                    DateTime.tryParse(d.id) != null,
              )
              .toList();
          if (tours.isEmpty)
            return const Center(
                child: Text('Créez votre première tournée avec +'));
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: tours.length,
            itemBuilder: (context, i) {
              final d = tours[i];
              final date = DateTime.parse(d.id);
              final ids = List<String>.from(d.data()['prospectIds'] ?? []);
              return Card(
                child: ExpansionTile(
                  leading: const Icon(
                    Icons.route_outlined,
                    color: ProspectoColors.green,
                  ),
                  title: Text(
                      DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(date)),
                  subtitle: Text('${ids.length} visites'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Carte'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => MapPage(initialDate: date),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Compte rendu'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    ReportingPage(initialDate: date),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: const Text('Modifier'),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              SelectProspectsPage.routeName,
                              arguments: {
                                'seedIds': ids,
                                'dateMs': date.millisecondsSinceEpoch,
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
}
