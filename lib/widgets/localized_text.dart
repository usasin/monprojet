import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

/// Translates Prospecto labels while leaving company names, prospect names and
/// other dynamic values unchanged when no translation exists.
String prospectoTranslate(BuildContext context, String value) {
  if (!context.locale.languageCode.toLowerCase().startsWith('en')) {
    return value;
  }

  final exact = value.tr();
  if (exact != value) return exact;

  return _translateDynamicEnglish(value);
}

String _translateDynamicEnglish(String value) {
  final patterns = <(RegExp, String Function(Match))>[
    (
      RegExp(r'^Bonjour\s+(.+)$', caseSensitive: false),
      (m) => 'Hello ${m.group(1)}',
    ),
    (
      RegExp(r'^(\d+)/(\d+) visites sont reportées aujourd’hui\.$', caseSensitive: false),
      (m) => '${m.group(1)}/${m.group(2)} visits have been reported today.',
    ),
    (
      RegExp(r'^(\d+)/(\d+) visites prévues sont déjà reportées aujourd’hui\.$', caseSensitive: false),
      (m) => '${m.group(1)}/${m.group(2)} planned visits have already been reported today.',
    ),
    (
      RegExp(r'^Rayon\s*:\s*(.+)$', caseSensitive: false),
      (m) => 'Radius: ${m.group(1)}',
    ),
    (
      RegExp(r'^Priorité\s*:\s*(.+)$', caseSensitive: false),
      (m) => 'Priority: ${m.group(1)}',
    ),
    (
      RegExp(r'^Priorité\s+(.+)$', caseSensitive: false),
      (m) => 'Priority ${m.group(1)}',
    ),
    (
      RegExp(r'^Durée de visite\s*:\s*(.+)$', caseSensitive: false),
      (m) => 'Visit duration: ${m.group(1)}',
    ),
    (
      RegExp(r'^Durée de visite par défaut\s*:\s*(.+)$', caseSensitive: false),
      (m) => 'Default visit duration: ${m.group(1)}',
    ),
    (
      RegExp(r'^Nombre maximum de visites\s*:\s*(.+)$', caseSensitive: false),
      (m) => 'Maximum number of visits: ${m.group(1)}',
    ),
    (
      RegExp(r'^Connecté\s*:\s*(.+)$', caseSensitive: false),
      (m) => 'Signed in: ${m.group(1)}',
    ),
    (
      RegExp(r'^Créé\s*:\s*(.+)$', caseSensitive: false),
      (m) => 'Created: ${m.group(1)}',
    ),
    (
      RegExp(r'^Terminés\s*[—-]\s*(.+)$', caseSensitive: false),
      (m) => 'Completed — ${m.group(1)}',
    ),
    (
      RegExp(r'^Fichiers du\s+(.+)$', caseSensitive: false),
      (m) => 'Files for ${m.group(1)}',
    ),
    (
      RegExp(r'^Aucun prospect pour le\s+(.+)\.$', caseSensitive: false),
      (m) => 'No prospects for ${m.group(1)}.',
    ),
    (
      RegExp(r'^Sem\. du\s+(.+)$', caseSensitive: false),
      (m) => 'Week of ${m.group(1)}',
    ),
    (
      RegExp(r'^(\d+)\s+planifiés?$', caseSensitive: false),
      (m) => '${m.group(1)} scheduled',
    ),
    (
      RegExp(r'^(\d+)\s+arrêts?$', caseSensitive: false),
      (m) => '${m.group(1)} ${m.group(1) == '1' ? 'stop' : 'stops'}',
    ),
    (
      RegExp(r'^(\d+)\s+visites?(.*)$', caseSensitive: false),
      (m) => '${m.group(1)} ${m.group(1) == '1' ? 'visit' : 'visits'}${m.group(2) ?? ''}',
    ),
    (
      RegExp(r'^(\d+)\s+prospects?(.*)$', caseSensitive: false),
      (m) => '${m.group(1)} ${m.group(1) == '1' ? 'prospect' : 'prospects'}${m.group(2) ?? ''}',
    ),
    (
      RegExp(r'^(\d+)\s+relance\(s\) programmée\(s\)$', caseSensitive: false),
      (m) => '${m.group(1)} scheduled follow-up${m.group(1) == '1' ? '' : 's'}',
    ),
    (
      RegExp(r'^Présents gérants\s*:\s*(\d+)\s*·\s*Clôtures\s*:\s*(\d+)$', caseSensitive: false),
      (m) => 'Managers present: ${m.group(1)} · Closures: ${m.group(2)}',
    ),
    (
      RegExp(r'^Note utilisateur\s*:\s*(.+)$', caseSensitive: false),
      (m) => 'User score: ${m.group(1)}',
    ),
    (
      RegExp(r'^Prospects\s*\((.+)\)$', caseSensitive: false),
      (m) => 'Prospects (${m.group(1)})',
    ),
    (
      RegExp(r'^Code valide\s*[—-]\s*(.+)\s*·\s*(\d+) utilisateurs max\.$', caseSensitive: false),
      (m) => 'Valid code — ${m.group(1)} · up to ${m.group(2)} users.',
    ),
    (
      RegExp(r'^Chargement impossible\s*:\s*(.+)$', caseSensitive: false),
      (m) => 'Unable to load: ${m.group(1)}',
    ),
    (
      RegExp(r'^Forfait\s+(.+)\s+inclus$', caseSensitive: false),
      (m) => '${m.group(1)} plan included',
    ),
    (
      RegExp(r'^Le plan du\s+(.+)\s+a été mis à jour avec succès\.$', caseSensitive: false),
      (m) => 'The plan for ${m.group(1)} was updated successfully.',
    ),
    (
      RegExp(r'^(.+) ne pourra plus accéder aux données de l’entreprise\..*$', caseSensitive: false),
      (m) => '${m.group(1)} will no longer be able to access company data. Prospects created for the company will remain there.',
    ),
    (
      RegExp(r'^(.+) deviendra administrateur principal\..*$', caseSensitive: false),
      (m) => '${m.group(1)} will become the primary administrator. You will become an administrator.',
    ),
  ];

  for (final entry in patterns) {
    final match = entry.$1.firstMatch(value);
    if (match != null) return entry.$2(match);
  }
  return value;
}

/// Drop-in text widget used by Prospecto so visible labels can be translated
/// without changing the existing layout, animations or typography.
class LText extends StatelessWidget {
  const LText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final ui.TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      prospectoTranslate(context, data),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null
          ? null
          : prospectoTranslate(context, semanticsLabel!),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}
