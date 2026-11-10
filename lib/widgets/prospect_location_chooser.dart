import 'package:flutter/material.dart';
import '../services/prospect_location_service.dart';

Future<ProspectSearchLocation?> chooseProspectLocation(
    BuildContext context, List<ProspectSearchLocation> options,
    {bool isFrench = true}) {
  return showModalBottomSheet<ProspectSearchLocation>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .75),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isFrench ? 'Choisissez votre lieu' : 'Choose your location',
                    style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(isFrench
                    ? 'Ce lieu sera le centre de votre recherche. Vous choisissez ensuite les activités et le rayon.'
                    : 'This place will be your search centre. You then choose activities and distance.'),
                const SizedBox(height: 12),
                Flexible(
                    child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final option = options[index];
                          return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(option.preciseAddress
                                  ? Icons.home_work_outlined
                                  : Icons.place_outlined),
                              title: Text(option.label),
                              subtitle: Text(option.preciseAddress
                                  ? (isFrench
                                      ? 'Adresse précise'
                                      : 'Street address')
                                  : (isFrench
                                      ? 'Centre de rue ou de commune · rayon à choisir'
                                      : 'Street or town centre · choose a radius')),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(sheet, option));
                        })),
                const SizedBox(height: 8),
                Text(
                    isFrench
                        ? 'Adresses : IGN / Base Adresse Nationale'
                        : 'Addresses: IGN / Base Adresse Nationale',
                    style: Theme.of(sheet).textTheme.bodySmall),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => Navigator.pop(sheet),
                        child: Text(isFrench ? 'Annuler' : 'Cancel'))),
              ])),
    ),
  );
}
