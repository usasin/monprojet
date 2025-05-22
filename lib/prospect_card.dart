// Utilise-le où tu veux (dans ProspectsFinishedPage, liste, etc.)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/prospect.dart';

class ProspectCard extends StatelessWidget {
  final Prospect p;
  const ProspectCard(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget _line(IconData icn, String txt) => Padding(
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
            /* ---------- En-tête ---------- */
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(p.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),

            /* ---------- Adresse ---------- */
            Text(p.address, style: Theme.of(context).textTheme.bodyMedium),
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

            /* ---------- Détails reporting ---------- */
            if (p.phone != null && p.phone!.isNotEmpty)
              _line(Icons.phone, p.phone!),
            if (p.email != null && p.email!.isNotEmpty)
              _line(Icons.email, p.email!),
            if (p.prochaineVisite != null)
              _line(Icons.calendar_month,
                  DateFormat.yMMMd('fr_FR').format(p.prochaineVisite!)),
            if (p.finishedAt != null)
              _line(Icons.flag,
                  'Terminé le ${DateFormat.yMMMd('fr_FR').add_Hm().format(p.finishedAt!)}'),
          ],
        ),
      ),
    );
  }
}
