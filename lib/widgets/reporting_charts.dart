import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/prospecto_colors.dart';

class ReportSlice {
  const ReportSlice(this.label, this.count, this.color, {this.onTap});
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;
}

/// Visit statuses stay independent from contract outcomes and report completion.
List<ReportSlice> visitReportSlices(Iterable<String?> statuses) {
  var present = 0, absent = 0, appointment = 0, other = 0;
  for (final raw in statuses) {
    switch (raw?.trim().toLowerCase()) {
      case 'présent':
      case 'present':
        present++;
      case 'absent':
        absent++;
      case 'rdv':
        appointment++;
      default:
        other++;
    }
  }
  return [
    ReportSlice('Présent', present, ProspectoColors.blue),
    ReportSlice('Absent', absent, const Color(0xFFEF4444)),
    ReportSlice('RDV', appointment, ProspectoColors.green),
    ReportSlice('À renseigner', other, const Color(0xFF94A3B8)),
  ];
}

class ReportingDonut extends StatelessWidget {
  const ReportingDonut({
    super.key,
    required this.title,
    required this.slices,
    this.subtitle,
    this.centerValue,
    this.centerLabel = 'au total',
    this.emptyLabel = 'Aucune donnée sur cette période',
  });
  final String title, centerLabel, emptyLabel;
  final String? subtitle, centerValue;
  final List<ReportSlice> slices;
  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0, (n, slice) => n + slice.count);
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface.withValues(alpha: .78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: ProspectoColors.blue.withValues(alpha: .15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null)
              Text(subtitle!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(emptyLabel, textAlign: TextAlign.center),
              )
            else ...[
              Semantics(
                label:
                    '$title : ${slices.where((s) => s.count > 0).map((s) => '${s.label} ${s.count}').join(', ')}',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 184,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            centerSpaceRadius: 54,
                            sectionsSpace: 2,
                            pieTouchData: PieTouchData(enabled: false),
                            sections: slices.where((s) => s.count > 0).map((s) {
                              final percent = s.count / total * 100;
                              return PieChartSectionData(
                                value: s.count.toDouble(),
                                color: s.color,
                                radius: 35,
                                title:
                                    percent >= 8 ? '${percent.round()} %' : '',
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        SizedBox(
                          width: 95,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                child: Text(centerValue ?? '$total',
                                    style: theme.textTheme.headlineSmall),
                              ),
                              Text(centerLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11),
                                  textScaler: const TextScaler.linear(1)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: slices.where((s) => s.count > 0).map((s) {
                  final label = Text('${s.label} (${s.count})');
                  final avatar =
                      CircleAvatar(backgroundColor: s.color, radius: 6);
                  return s.onTap == null
                      ? Chip(avatar: avatar, label: label)
                      : ActionChip(
                          avatar: avatar, label: label, onPressed: s.onTap);
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReportingChartGrid extends StatelessWidget {
  const ReportingChartGrid({super.key, required this.charts});
  final List<Widget> charts;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 720 ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                charts.map((c) => SizedBox(width: width, child: c)).toList(),
          );
        },
      );
}
