import 'package:flutter/material.dart';

/// Discreet, accessible disclosure for optional help and data-source notices.
/// Only presentation changes here: business logic stays in the caller.
enum ProspectInfoTone { neutral, online, installed, caution, error }

class ProspectInfoChip extends StatelessWidget {
  final String label;
  final String details;
  final IconData icon;
  final ProspectInfoTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ProspectInfoChip({
    super.key,
    required this.label,
    required this.details,
    this.icon = Icons.info_outline_rounded,
    this.tone = ProspectInfoTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final foreground = switch (tone) {
      ProspectInfoTone.online => const Color(0xFF17678E),
      ProspectInfoTone.installed => const Color(0xFF167455),
      ProspectInfoTone.caution => const Color(0xFFC48627),
      ProspectInfoTone.error => scheme.error,
      ProspectInfoTone.neutral => scheme.onSurfaceVariant,
    };
    final background = foreground.withValues(alpha: isDark ? .20 : .10);

    return Semantics(
      button: true,
      label: label,
      hint: Localizations.localeOf(context).languageCode.startsWith('fr')
          ? 'Touchez pour lire les détails'
          : 'Tap for details',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showDetails(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: (MediaQuery.sizeOf(context).width - 110)
                        .clamp(80.0, 260.0).toDouble()),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark ? scheme.onSurface : foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right_rounded, size: 15, color: foreground),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.fromLTRB(
              22, 4, 22, 24 + MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(details, style: Theme.of(sheetContext).textTheme.bodyMedium),
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      onAction!();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(actionLabel!),
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      );
}

/// Converts engine diagnostics into useful, non-technical user information.
/// These messages never alter how sources are queried or merged.
String prospectSearchSourceExplanation(String diagnostic,
    {required bool isFrench}) {
  final text = diagnostic.toLowerCase();
  if (text.contains('indisponible') || text.contains('partiels') ||
      text.contains('partielles') || text.contains('failed')) {
    return isFrench
        ? 'Certaines données n’ont pas pu être récupérées. La liste affichée peut être incomplète. Vous pouvez relancer la recherche plus tard ou essayer un autre rayon.'
        : 'Some sources did not respond. The list may be incomplete. Try again later or use another search radius.';
  }
  if (text.contains('extrait local') || text.contains('couverture partielle')) {
    return isFrench
        ? 'Les données téléchargées couvrent seulement une partie de cette zone. Prospecto complète automatiquement avec les données disponibles en ligne. Certains professionnels peuvent manquer.'
        : 'Downloaded data covers only part of this area. Prospecto automatically adds available online results. Some businesses may be missing.';
  }
  if (text.contains('entièrement couverte') || text.contains('entierement couverte')) {
    return isFrench
        ? 'Les données téléchargées indiquent couvrir la zone choisie. Le nombre de professionnels reflète les informations présentes dans ce pack.'
        : 'Downloaded data indicates coverage for this area. Results depend on the contents of that pack.';
  }
  return isFrench
      ? 'Prospecto recherche les professionnels disponibles autour du lieu choisi. Sans données locales complètes, les résultats viennent aussi d’Internet et peuvent ne pas inclure toutes les entreprises.'
      : 'Prospecto finds available businesses around your chosen location. Without complete downloaded data, it also searches online; not every business may be listed.';
}
