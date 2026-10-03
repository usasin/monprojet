import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/prospecto_colors.dart';
import 'sales_model.dart';

class VisualSection extends StatelessWidget {
  const VisualSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: ProspectoColors.blue.withValues(alpha: .13)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: ProspectoColors.blue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class VisualHero extends StatelessWidget {
  const VisualHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.business_outlined,
    this.badges = const [],
  });
  final String title, subtitle;
  final IconData icon;
  final List<Widget> badges;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        colors: Theme.of(context).brightness == Brightness.dark
            ? const [Color(0xFF203C56), Color(0xFF214F47)]
            : const [Color(0xFFD0EDFF), Color(0xFFC6F3E7)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: Colors.white.withValues(alpha: .5),
          child: Icon(icon, color: ProspectoColors.blue, size: 27),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 13)),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: badges),
        ],
      ],
    ),
  );
}

class SalesBadge extends StatelessWidget {
  const SalesBadge(this.label, {super.key, this.color = ProspectoColors.blue});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

Color stageColor(String stage) => stage == 'won'
    ? ProspectoColors.green
    : stage == 'lost'
    ? const Color(0xFFF1846F)
    : ProspectoColors.blue;
String displayMoney(int cents) => NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: cents % 100 == 0 ? 0 : 2,
).format(cents / 100);

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({
    super.key,
    required this.deal,
    required this.onTap,
    this.showRevenue = true,
  });
  final SalesDeal deal;
  final VoidCallback onTap;
  final bool showRevenue;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    deal.stage == 'won'
                        ? Icons.verified_outlined
                        : Icons.business_center_outlined,
                    color: stageColor(deal.stage),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      deal.title.isEmpty ? deal.prospectName : deal.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  SalesBadge(
                    salesStages[deal.stage] ?? deal.stage,
                    color: stageColor(deal.stage),
                  ),
                  if (deal.open)
                    SalesBadge(salesInterests[deal.interest] ?? deal.interest),
                ],
              ),
              const SizedBox(height: 8),
              Text(deal.ownerName, style: const TextStyle(fontSize: 12)),
              if (showRevenue && deal.amountCents != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${displayMoney(deal.amountCents!)} HT',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (deal.open && deal.nextActionAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${salesActions[deal.nextAction] ?? 'Action'} · ${DateFormat('dd/MM HH:mm').format(deal.nextActionAt!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
