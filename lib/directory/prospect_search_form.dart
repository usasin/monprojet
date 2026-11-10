import 'package:flutter/material.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/prospect_info_chip.dart';
import 'directory_service.dart';

List<String> prospectActivityTokens(String value) => value
    .split(RegExp(r'[,;|]'))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

String toggleProspectActivity(String value, String activity) {
  final target = DirectoryCategories.normalize(activity);
  final parts = prospectActivityTokens(value);
  final selected =
      parts.any((part) => DirectoryCategories.normalize(part) == target);
  final output = parts
      .where((part) => DirectoryCategories.normalize(part) != target)
      .toList();
  if (!selected) output.add(activity);
  return output.join(', ');
}

/// The form prepares a query. Only the primary search button fetches businesses.
class ProspectSearchForm extends StatelessWidget {
  final TextEditingController addressController, activityController;
  final List<String> quickActivities, installedTerritories;
  final String? selectedTerritory, selectedLocation;
  final bool isFrench, busy, locating, offlineSupported;
  final bool ownDirectory;
  final int radiusIndex;
  final bool showZone, showTargeting;
  final ValueChanged<int> onRadiusChanged;
  final ValueChanged<String> onActivityToggle;
  final VoidCallback onChooseAddress,
      onUsePosition,
      onManageTerritories,
      onSearch,
      onOptimize;
  const ProspectSearchForm(
      {super.key,
      required this.addressController,
      required this.activityController,
      required this.quickActivities,
      required this.installedTerritories,
      this.selectedTerritory,
      this.selectedLocation,
      this.showZone = true,
      this.showTargeting = true,
      this.isFrench = true,
      this.ownDirectory = false,
      required this.busy,
      required this.locating,
      required this.offlineSupported,
      required this.radiusIndex,
      required this.onRadiusChanged,
      required this.onActivityToggle,
      required this.onChooseAddress,
      required this.onUsePosition,
      required this.onManageTerritories,
      required this.onSearch,
      required this.onOptimize});
  String _t(String fr, String en) => isFrench ? fr : en;

  @override
  Widget build(BuildContext context) {
    final disabled = busy || locating;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(16));
    return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showZone) ...[
          TextField(
              key: const Key('prospect-search-address'),
              controller: addressController,
              enabled: !disabled,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onChooseAddress(),
              decoration: InputDecoration(
                  border: border,
                  labelText: _t('Adresse, ville ou code postal',
                      'Address, town or postcode'),
                  hintText: _t('Ex. 10 rue de Rivoli, Paris ou 75001',
                      'e.g. 10 rue de Rivoli, Paris or 75001'),
                  prefixIcon: const Icon(Icons.search_rounded))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(
                key: const Key('choose-search-address'),
                onPressed: disabled ? null : onChooseAddress,
                icon: const Icon(Icons.pin_drop_outlined),
                label:
                    Text(_t('Choisir cette adresse', 'Choose this address'))),
            OutlinedButton.icon(
                key: const Key('use-search-position'),
                onPressed: disabled ? null : onUsePosition,
                icon: const Icon(Icons.my_location_rounded),
                label: Text(_t('Ma position', 'My location'))),
          ]),
          if (locating)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Expanded(
                      child:
                          Text(_t('Recherche du lieu…', 'Finding location…'))),
                ])),
          if (selectedLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ProspectInfoChip(
                key: const Key('selected-search-location-chip'),
                label: '✓ $selectedLocation',
                icon: Icons.check_circle_rounded,
                tone: ProspectInfoTone.installed,
                details: selectedLocation!,
              ),
            ),
          ],
          if (showTargeting) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Icon(Icons.storefront_outlined, size: 18, color: ProspectoColors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(_t('Activités', 'Business types'),
                  style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(_t('Facultatif', 'Optional'),
                  style: TextStyle(fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          _CompactActivityPicker(
            key: const Key('compact-activity-picker'),
            activityController: activityController,
            quickActivities: quickActivities,
            ownDirectory: ownDirectory,
            isFrench: isFrench,
            disabled: disabled,
            onActivityToggle: onActivityToggle,
          ),
          const SizedBox(height: 16),
          Text(_t('Rayon', 'Radius'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 5, children: [
            for (var i = 0; i < 5; i++)
              ChoiceChip(
                  label:
                      Text(const ['500 m', '1 km', '2 km', '5 km', '10 km'][i]),
                  selected: radiusIndex == i,
                  onSelected: disabled ? null : (_) => onRadiusChanged(i)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  key: const Key('run-prospect-search'),
                  onPressed: disabled ? null : onSearch,
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(_t('Rechercher les professionnels',
                          'Find businesses'))))),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: disabled ? null : onOptimize,
                  icon: const Icon(Icons.route_outlined, size: 18),
                  label: Text(
                      _t('Optimiser ma sélection', 'Optimize my selection')))),
          ],
        ]));
  }
}


/// A compact, progressive selector. Keeps the existing comma-separated query
/// contract and never launches a search when a chip is selected.
class _CompactActivityPicker extends StatefulWidget {
  final TextEditingController activityController;
  final List<String> quickActivities;
  final bool ownDirectory, isFrench, disabled;
  final ValueChanged<String> onActivityToggle;

  const _CompactActivityPicker({
    super.key,
    required this.activityController,
    required this.quickActivities,
    required this.ownDirectory,
    required this.isFrench,
    required this.disabled,
    required this.onActivityToggle,
  });

  @override
  State<_CompactActivityPicker> createState() => _CompactActivityPickerState();
}

class _CompactActivityPickerState extends State<_CompactActivityPicker> {
  bool _showAll = false;
  bool _showCustom = false;

  String _t(String fr, String en) => widget.isFrench ? fr : en;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = widget.quickActivities;
    final visible = _showAll ? all : all.take(4).toList();
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(14));
    final color = theme.colorScheme.primary;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.activityController,
      builder: (context, value, _) {
        final tokens = prospectActivityTokens(value.text);
        final selected = tokens.map(DirectoryCategories.normalize).toSet();
        final visibleKeys = visible.map(DirectoryCategories.normalize).toSet();
        final hiddenSelected = tokens.where((token) =>
            !visibleKeys.contains(DirectoryCategories.normalize(token))).toList();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: .16)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.tune_rounded, color: color, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tokens.isEmpty
                      ? _t('Toutes les activités', 'All business types')
                      : _t('${selected.length} sélectionnée(s)',
                          '${selected.length} selected'),
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (tokens.isNotEmpty)
                TextButton(
                  key: const Key('clear-activities'),
                  onPressed: widget.disabled ? null : widget.activityController.clear,
                  child: Text(_t('Effacer', 'Clear')),
                ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 4, children: [
              for (final activity in visible)
                FilterChip(
                  key: ValueKey('activity-${DirectoryCategories.normalize(activity)}'),
                  selected: selected.contains(DirectoryCategories.normalize(activity)),
                  showCheckmark: true,
                  visualDensity: VisualDensity.compact,
                  label: Text(activity.isEmpty
                      ? activity
                      : '${activity[0].toUpperCase()}${activity.substring(1)}'),
                  onSelected: widget.disabled
                      ? null
                      : (_) => widget.onActivityToggle(activity),
                ),
            ]),
            if (hiddenSelected.isNotEmpty) ...[
              const SizedBox(height: 7),

              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final token in hiddenSelected)
                  InputChip(
                    key: ValueKey('selected-${DirectoryCategories.normalize(token)}'),
                    label: Text(token),
                    visualDensity: VisualDensity.compact,
                    onDeleted: widget.disabled
                        ? null
                        : () => widget.onActivityToggle(token),
                  ),
              ]),
            ],
            const SizedBox(height: 3),
            Wrap(spacing: 2, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
              if (all.length > 4)
                TextButton.icon(
                  key: const Key('show-all-activities'),
                  onPressed: widget.disabled
                      ? null
                      : () => setState(() => _showAll = !_showAll),
                  icon: Icon(_showAll ? Icons.expand_less : Icons.expand_more, size: 19),
                  label: Text(_showAll
                      ? _t('Voir moins', 'Show less')
                      : _t('Voir les ${all.length} activités', 'See all ${all.length} activities')),
                ),
              TextButton.icon(
                key: const Key('show-custom-activities'),
                onPressed: widget.disabled
                    ? null
                    : () => setState(() => _showCustom = !_showCustom),
                icon: Icon(_showCustom ? Icons.keyboard_arrow_up : Icons.add, size: 19),
                label: Text(_showCustom
                    ? _t('Masquer la saisie', 'Hide text input')
                    : _t('Activité précise', 'Custom activity')),
              ),
            ]),
            if (_showCustom) ...[
              ProspectInfoChip(
                label: _t('Conseil', 'Tip'),
                icon: Icons.lightbulb_outline_rounded,
                details: _t('Séparez plusieurs activités par une virgule. Laissez le champ vide pour chercher tous les professionnels.',
                    'Separate multiple activities with commas. Leave blank to search all businesses.'),
              ),
              const SizedBox(height: 5),
              TextField(
                key: const Key('prospect-search-activities'),
                controller: widget.activityController,
                enabled: !widget.disabled,
                minLines: 1,
                maxLines: 2,
                decoration: InputDecoration(
                  isDense: true,
                  border: border,
                  prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                  labelText: widget.ownDirectory
                      ? _t('Activités ou codes NAF', 'Activities or NAF codes')
                      : _t('Activités ou mots-clés', 'Activities or keywords'),
                  hintText: _t('Ex. grossiste textile, industrie',
                      'e.g. textile wholesaler, industry'),

                ),
              ),
            ],
          ]),
        );
      },
    );
  }
}
