import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/prospecto_colors.dart';
import 'enterprise_repository.dart';
import 'enterprise_snapshot.dart';
import 'enterprise_portfolio.dart';
import 'enterprise_comparison.dart';
import 'sales_visuals.dart';

class EnterpriseHome extends StatelessWidget {
  const EnterpriseHome({super.key, required this.controller});
  final EnterpriseController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final view = controller.view;
          if (controller.loading)
            return const Center(child: CircularProgressIndicator());
          if (view == null)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        controller.error ?? 'Chargement de la vue entreprise…'),
                    TextButton.icon(
                      onPressed: controller.refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          return RefreshIndicator(
            onRefresh: controller.refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: EnterpriseHomeContent(
                    view: view,
                    period: controller.period,
                    onPeriod: controller.selectPeriod,
                    onScope: controller.selectScope,
                    onProspects: (filter) => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EnterprisePortfolio(
                          controller: controller,
                          initialFilter: filter,
                        ),
                      ),
                    ),
                    onComparison: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            EnterpriseComparison(controller: controller),
                      ),
                    ),
                    onDeals: (kind) async {
                      await showEnterpriseDeals(
                        context,
                        controller.repository.orgId,
                        kind == 'lost'
                            ? 'Affaires perdues'
                            : kind == 'overdue'
                                ? 'Relances en retard'
                                : 'Contrats signés',
                        kind == 'lost'
                            ? view.totals.lost
                            : kind == 'overdue'
                                ? view.overdueFollowUps
                                : view.totals.won,
                      );
                      await controller.refresh();
                    },
                    onActivity: (kind) async {
                      if (kind == 'members') {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: const Text(
                                  'Commerciaux actifs sur la période',
                                ),
                              ),
                              body: ListView(
                                children: view.activeMembers
                                    .map(
                                      (m) => ListTile(
                                        title: Text(m.name),
                                        subtitle: Text(
                                          '${view.plans.where((p) => p.ownerUid == m.uid).length} tournées · ${view.deals.where((d) => d.ownerUid == m.uid && view.window.contains(d.closedAt) && d.stage == 'won').length} signés',
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        );
                      } else {
                        await showEnterpriseRecords(
                          context,
                          kind == 'invite'
                              ? 'Invitations en attente'
                              : kind == 'appointment'
                                  ? 'Rendez-vous'
                                  : 'Tournées de l’entreprise',
                          kind == 'invite'
                              ? view.pendingInvites
                              : kind == 'appointment'
                                  ? view.appointments
                                  : view.plans,
                          view,
                          kind: kind == 'invite'
                              ? 'invite'
                              : kind == 'appointment'
                                  ? 'appointment'
                                  : 'plan',
                          orgId: controller.repository.orgId,
                        );
                        await controller.refresh();
                      }
                    },
                  ),
                ),
              ),
            ),
          );
        },
      );
}

/// Data-driven presentation shared by production and layout/interaction tests.
class EnterpriseHomeContent extends StatelessWidget {
  const EnterpriseHomeContent({
    super.key,
    required this.view,
    required this.period,
    required this.onPeriod,
    required this.onScope,
    required this.onProspects,
    required this.onDeals,
    required this.onActivity,
    this.onComparison,
  });
  final EnterpriseView view;
  final VoidCallback? onComparison;
  final String period;
  final ValueChanged<String> onPeriod,
      onScope,
      onProspects,
      onDeals,
      onActivity;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final periodName = {
      'day': 'du jour',
      'week': 'de la semaine',
      'month': 'du mois',
    }[period]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          view.snapshot.managerUid == null ? 'Vue entreprise' : 'Mon équipe',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _PeriodPicker(period: period, onChanged: onPeriod),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(view.scope),
                value: view.scope,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.colorScheme.surface.withValues(alpha: .8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                items: EnterpriseController.scopeOptions(view.snapshot)
                    .entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) onScope(v);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Filtrer par équipe ou commercial',
              icon: const Icon(Icons.filter_alt_outlined),
              onPressed: () => _filters(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _PortfolioCard(view: view, period: period, onTap: onProspects),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
            final sideBySide =
                c.maxWidth >= 300 && (!largeText || c.maxWidth >= 560);
            final cards = [
              if (view.snapshot.display.showContracts)
                _SummaryDonut(
                  title: 'Contrats',
                  value: '${view.totals.won.length}',
                  label: 'signés',
                  values: [view.totals.won.length, view.totals.lost.length],
                  colors: const [ProspectoColors.green, ProspectoColors.peach],
                  legends: [
                    '${view.totals.won.length} signés',
                    '${view.totals.lost.length} perdus',
                  ],
                  onTap: () => onDeals('won'),
                  onLegend: (i) => onDeals(i == 0 ? 'won' : 'lost'),
                  footer: Column(
                    children: [
                      Text(
                        'Taux de gain : ${view.totals.winRate == null ? '—' : '${(view.totals.winRate! * 100).round()} %'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      if (view.snapshot.display.showRevenue)
                        Material(
                          color: ProspectoColors.green.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => onDeals('won'),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                view.totals.won.isNotEmpty &&
                                        view.totals.won.length ==
                                            view.totals.missingAmounts
                                    ? 'Montants non renseignés'
                                    : '${displayMoney(view.totals.signedCents)} HT signés',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (view.snapshot.display.showRevenue &&
                          view.totals.missingAmounts > 0 &&
                          view.totals.missingAmounts < view.totals.won.length)
                        Text(
                          '${view.totals.missingAmounts} sans montant',
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                ),
              if (!view.snapshot.display.showContracts)
                _Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Chiffre d’affaires',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Icon(
                        Icons.payments_outlined,
                        color: ProspectoColors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        view.totals.won.isNotEmpty &&
                                view.totals.missingAmounts ==
                                    view.totals.won.length
                            ? 'Non renseigné'
                            : displayMoney(view.totals.signedCents),
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        'HT déclaré sur la période',
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => onDeals('won'),
                        child: const Text('Voir les affaires'),
                      ),
                    ],
                  ),
                ),
              _SummaryDonut(
                title: 'Visites',
                value: '${view.completedVisits} / ${view.plannedVisits}',
                label: 'réalisées',
                values: [
                  view.completedVisits,
                  view.plannedVisits - view.completedVisits,
                ],
                colors: const [ProspectoColors.blue, Color(0xFFC9DAED)],
                legends: [
                  '${view.completedVisits} réalisées',
                  '${view.plannedVisits - view.completedVisits} restantes',
                ],
                onTap: () => onActivity('plan'),
                onLegend: (_) => onActivity('plan'),
              ),
            ];
            return sideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 10),
                      Expanded(child: cards[1]),
                    ],
                  )
                : Column(
                    children: [cards[0], const SizedBox(height: 10), cards[1]],
                  );
          },
        ),
        const SizedBox(height: 12),
        _ActivityStrip(view: view, onTap: onActivity),
        if (onComparison != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: OutlinedButton.icon(
              onPressed: onComparison,
              icon: const Icon(Icons.equalizer_outlined),
              label: Text(
                view.snapshot.managerUid == null
                    ? 'Comparer les équipes'
                    : 'Comparer mes commerciaux',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        if (view.overdueFollowUps.isNotEmpty ||
            view.pendingInvites.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'À suivre',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (view.overdueFollowUps.isNotEmpty)
            _AttentionRow(
              icon: Icons.notifications_outlined,
              text:
                  '${view.overdueFollowUps.length} relance${view.overdueFollowUps.length > 1 ? 's' : ''} en retard',
              onTap: () => onDeals('overdue'),
            ),
          if (view.pendingInvites.isNotEmpty)
            _AttentionRow(
              icon: Icons.mail_outline,
              text:
                  '${view.pendingInvites.length} invitation${view.pendingInvites.length > 1 ? 's' : ''} en attente',
              onTap: () => onActivity('invite'),
            ),
        ],
        const SizedBox(height: 10),
        Text(
          'Actualisé à ${DateFormat('HH:mm').format(view.snapshot.readAt)} · ${DateFormat('dd/MM').format(view.window.start)}–${DateFormat('dd/MM').format(view.window.end.subtract(const Duration(days: 1)))}',
          style: theme.textTheme.bodySmall,
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            'Comprendre les chiffres $periodName',
            style: const TextStyle(fontSize: 12),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Le portefeuille est le stock actuel de prospects uniques. Nouveaux = ajoutés sur la période. '
                'À qualifier = sans opportunité ou avec une affaire à qualifier. Chauds et relances sont des suivis actuels et peuvent se recouper. '
                'Le filtre d’équipe utilise le créateur du prospect et les commerciaux qui suivent ses affaires. '
                'Signés/perdus = affaires clôturées sur la période. '
                '${view.snapshot.display.showRevenue ? 'Les montants sont déclarés HT, pas encaissés. ' : ''}'
                'Une visite réalisée a un compte rendu enregistré ; une tournée réalisée a un compte rendu pour chaque étape. '
                'Un commercial actif a un accès actif et une tournée, un RDV ou une affaire actualisée sur la période. '
                'Les invitations concernent toute l’entreprise.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _filters(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .65,
            child: ListView(
              children: [
                const ListTile(
                  title: Text(
                    'Équipe / responsable / commercial',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ...EnterpriseController.scopeOptions(view.snapshot).entries.map(
                      (e) => ListTile(
                        title: Text(e.value),
                        trailing: view.scope == e.key
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          onScope(e.key);
                        },
                      ),
                    ),
              ],
            ),
          ),
        ),
      );
}

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.period, required this.onChanged});
  final String period;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .45)),
        ),
        child: Row(
          children: {'day': 'Aujourd’hui', 'week': 'Semaine', 'month': 'Mois'}
              .entries
              .map(
                (e) => Expanded(
                  child: Material(
                    color: period == e.key
                        ? ProspectoColors.blue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => onChanged(e.key),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 3,
                        ),
                        child: Text(
                          e.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: period == e.key
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.view,
    required this.period,
    required this.onTap,
  });
  final EnterpriseView view;
  final String period;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF203C56), Color(0xFF214F47)]
                : const [Color(0xFFD0EDFF), Color(0xFFC6F3E7)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .45)),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 260 &&
                MediaQuery.textScalerOf(context).scale(14) <= 20;
            final total = InkWell(
              onTap: () => onTap('all'),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Portefeuille actuel',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${view.prospects.length}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'prospects',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
            final values = <(String, String, IconData, Color)>[
              (
                'new',
                'nouveaux ${period == 'day' ? 'aujourd’hui' : period == 'month' ? 'ce mois' : 'cette semaine'}',
                Icons.person_add_alt_1_outlined,
                ProspectoColors.blue,
              ),
              (
                'qualify',
                'à qualifier',
                Icons.description_outlined,
                ProspectoColors.blue,
              ),
              (
                'hot',
                'chauds',
                Icons.local_fire_department_outlined,
                const Color(0xFFF1846F),
              ),
              ('followup', 'à relancer', Icons.schedule, ProspectoColors.green),
            ];
            Widget chips(double width) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: values
                      .map(
                        (e) => SizedBox(
                          width: (width - 8) / 2,
                          child: Material(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? e.$4.withValues(alpha: .18)
                                    : e.$1 == 'hot'
                                        ? const Color(0xFFFFEFE9)
                                        : Colors.white.withValues(alpha: .62),
                            borderRadius: BorderRadius.circular(15),
                            child: InkWell(
                              onTap: () => onTap(e.$1),
                              borderRadius: BorderRadius.circular(15),
                              child: Padding(
                                padding: const EdgeInsets.all(9),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(e.$3, size: 18, color: e.$4),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: FittedBox(
                                            alignment: Alignment.centerLeft,
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${view.prospectsFor(e.$1).length}',
                                              style: const TextStyle(
                                                fontSize: 23,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      e.$2,
                                      style:
                                          TextStyle(fontSize: wide ? 10 : 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: total),
                      Expanded(
                        flex: 6,
                        child:
                            LayoutBuilder(builder: (_, c) => chips(c.maxWidth)),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      total,
                      const SizedBox(height: 12),
                      chips(c.maxWidth),
                    ],
                  );
          },
        ),
      );
}

class _SummaryDonut extends StatelessWidget {
  const _SummaryDonut({
    required this.title,
    required this.value,
    required this.label,
    required this.values,
    required this.colors,
    required this.legends,
    required this.onTap,
    required this.onLegend,
    this.footer,
  });
  final String title, value, label;
  final List<int> values;
  final List<Color> colors;
  final List<String> legends;
  final VoidCallback onTap;
  final ValueChanged<int> onLegend;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => _Surface(
        child: LayoutBuilder(
          builder: (context, c) {
            final diameter = c.maxWidth.clamp(110.0, 180.0);
            final total = values.fold(0, (n, v) => n + v);
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: diameter + 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: onTap,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    label: '$title : ${legends.join(', ')}',
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: onTap,
                        child: SizedBox(
                          height: diameter,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  startDegreeOffset: -90,
                                  centerSpaceRadius: diameter * .28,
                                  sectionsSpace: total == 0 ? 0 : 1,
                                  pieTouchData: PieTouchData(enabled: false),
                                  sections: total == 0
                                      ? [
                                          PieChartSectionData(
                                            value: 1,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline
                                                .withValues(alpha: .3),
                                            radius: diameter * .20,
                                            showTitle: false,
                                          ),
                                        ]
                                      : [
                                          for (var i = 0;
                                              i < values.length;
                                              i++)
                                            if (values[i] > 0)
                                              PieChartSectionData(
                                                value: values[i].toDouble(),
                                                color: colors[i],
                                                radius: diameter * .20,
                                                showTitle: false,
                                              ),
                                        ],
                                ),
                                swapAnimationDuration: Duration.zero,
                              ),
                              SizedBox(
                                width: diameter * .55,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      child: Text(
                                        value,
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      label,
                                      style: const TextStyle(fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < legends.length; i++)
                        InkWell(
                          onTap: () => onLegend(i),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: colors[i],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    legends[i],
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (footer != null) ...[const SizedBox(height: 6), footer!],
                ],
              ),
            );
          },
        ),
      );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ProspectoColors.blue.withValues(alpha: .1)),
        ),
        child: child,
      );
}

class _ActivityStrip extends StatelessWidget {
  const _ActivityStrip({required this.view, required this.onTap});
  final EnterpriseView view;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => _Surface(
        child: LayoutBuilder(
          builder: (context, c) {
            final rows = <(String, String, String, IconData, Color)>[
              (
                'plan',
                '${view.completedTours} / ${view.plans.length}',
                'Tournées réalisées',
                Icons.route_outlined,
                ProspectoColors.blue,
              ),
              (
                'appointment',
                '${view.appointments.length}',
                'RDV',
                Icons.event_outlined,
                const Color(0xFFF1846F),
              ),
              (
                'members',
                '${view.activeMembers.length} / ${view.selectedMembers.where((m) => m.active).length}',
                'Commerciaux actifs',
                Icons.groups_outlined,
                ProspectoColors.green,
              ),
            ];
            final narrow = c.maxWidth < 290 ||
                MediaQuery.textScalerOf(context).scale(14) > 20;
            Widget cell((String, String, String, IconData, Color) r) => InkWell(
                  onTap: () => onTap(r.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        Icon(r.$4, color: r.$5, size: 23),
                        Text(
                          r.$2,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          r.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
            return narrow
                ? Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: rows
                        .map(
                          (r) => SizedBox(
                              width: (c.maxWidth - 4) / 2, child: cell(r)),
                        )
                        .toList(),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        rows.map((r) => Expanded(child: cell(r))).toList(),
                  );
          },
        ),
      );
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: ProspectoColors.peach.withValues(alpha: .2),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFFF1846F)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(text, style: const TextStyle(fontSize: 14))),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ),
      );
}
