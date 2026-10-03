import 'package:flutter/material.dart';
import '../widgets/brand_background.dart';
import '../theme/prospecto_colors.dart';
import 'enterprise_repository.dart';
import 'enterprise_snapshot.dart';
import 'sales_model.dart';
import 'sales_visuals.dart';

class EnterpriseComparison extends StatefulWidget {
  const EnterpriseComparison({super.key, required this.controller});
  final EnterpriseController controller;
  @override
  State<EnterpriseComparison> createState() => _EnterpriseComparisonState();
}

class _EnterpriseComparisonState extends State<EnterpriseComparison> {
  bool reps = false;
  @override
  Widget build(BuildContext context) => BrandBackground(
    animate: false,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Comparaison'),
        backgroundColor: Colors.transparent,
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final v = widget.controller.view;
          if (v == null)
            return const Center(child: CircularProgressIndicator());
          final team = v.snapshot.managerUid != null;
          final groups = <String, Set<String>>{};
          for (final m in v.selectedMembers) {
            final name = reps || team
                ? m.name
                : v.snapshot.members.any(
                    (n) => n.uid == m.managerUid && n.role == 'MANAGER',
                  )
                ? v.nameFor(m.managerUid)
                : 'Sans responsable';
            final key = reps || team ? m.uid : m.managerUid;
            groups.putIfAbsent('$key\u0000$name', () => <String>{}).add(m.uid);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              VisualHero(
                title: team
                    ? 'Mon équipe en perspective'
                    : 'Comparer les équipes',
                subtitle:
                    '${{'day': 'Aujourd’hui', 'week': 'Cette semaine', 'month': 'Ce mois'}[widget.controller.period]} · ${EnterpriseController.scopeOptions(v.snapshot)[v.scope]}',
                icon: Icons.equalizer_outlined,
              ),
              const SizedBox(height: 12),
              if (!team)
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Équipes'),
                      selected: !reps,
                      onSelected: (_) => setState(() => reps = false),
                    ),
                    ChoiceChip(
                      label: const Text('Commerciaux'),
                      selected: reps,
                      onSelected: (_) => setState(() => reps = true),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              if (groups.isEmpty)
                const Text('Aucune équipe à comparer sur ce périmètre.'),
              ...groups.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ComparisonCard(
                    name: e.key.split('\u0000').last,
                    uids: e.value,
                    view: v,
                  ),
                ),
              ),
              const Text(
                'Les volumes sont comparés sur la même période. Les taux utilisent leurs propres dénominateurs ; des équipes de tailles différentes ne sont pas classées artificiellement.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class ComparisonCard extends StatelessWidget {
  const ComparisonCard({
    super.key,
    required this.name,
    required this.uids,
    required this.view,
  });
  final String name;
  final Set<String> uids;
  final EnterpriseView view;
  @override
  Widget build(BuildContext context) {
    final deals = view.deals.where((d) => uids.contains(d.ownerUid)).toList();
    final total = SalesTotals(deals, view.window, view.now);
    final plans = view.plans.where((p) => uids.contains(p.ownerUid));
    final done = plans.fold(0, (n, p) => n + p.completedVisits);
    final visits = plans.fold(0, (n, p) => n + p.prospectIds.length);
    final linked = deals.map((d) => d.prospectId).toSet();
    final prospects = view.prospects
        .where(
          (p) => uids.contains(p.createdBy) || linked.contains(p.prospect.id),
        )
        .length;
    return VisualSection(
      title: name,
      icon: Icons.groups_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              SalesBadge('$prospects prospects'),
              SalesBadge('${uids.length} commerciaux'),
              SalesBadge(
                '${total.hot.length} affaires chaudes',
                color: const Color(0xFFF1846F),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: visits == 0 ? 0 : done / visits,
                        strokeWidth: 7,
                        color: ProspectoColors.blue,
                        backgroundColor: ProspectoColors.blue.withValues(
                          alpha: .15,
                        ),
                      ),
                    ),
                    Text(
                      visits == 0 ? '—' : '${(done / visits * 100).round()} %',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$done / $visits visites',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'réalisées sur la période',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (view.snapshot.display.showContracts)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                SalesBadge(
                  '${total.won.length} signés',
                  color: ProspectoColors.green,
                ),
                SalesBadge(
                  '${total.lost.length} perdus',
                  color: const Color(0xFFF1846F),
                ),
                SalesBadge(
                  total.winRate == null
                      ? 'Gain : —'
                      : 'Gain : ${(total.winRate! * 100).round()} %',
                ),
              ],
            ),
          if (view.snapshot.display.showRevenue) ...[
            const SizedBox(height: 10),
            Text(
              total.won.length == total.missingAmounts && total.won.isNotEmpty
                  ? 'Montants non renseignés'
                  : '${displayMoney(total.signedCents)} HT déclarés',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            if (total.missingAmounts > 0 &&
                total.missingAmounts < total.won.length)
              Text(
                '${total.missingAmounts} sans montant · total partiel',
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }
}
