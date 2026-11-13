import 'package:flutter/material.dart';
import 'prospect_info_chip.dart';

/// Keeps search feedback actionable without a large explanatory card.
class OSMSearchFeedback extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  const OSMSearchFeedback({
    super.key,
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode.startsWith('fr');
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ProspectInfoChip(
          key: const Key('search-feedback-chip'),
          label: isError
              ? (isFr ? 'Recherche à réessayer' : 'Search needs retry')
              : (isFr ? 'Aucun résultat' : 'No results'),
          details: message,
          icon: isError ? Icons.error_outline_rounded
              : Icons.info_outline_rounded,
          tone: isError ? ProspectInfoTone.error : ProspectInfoTone.caution,
          actionLabel: onRetry == null ? null : (isFr ? 'Réessayer' : 'Try again'),
          onAction: onRetry,
        ),
      ),
    );
  }
}
