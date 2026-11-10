import 'package:flutter/material.dart';

import '../services/osm_search_service.dart';

/// A less precise address must be accepted before it becomes a search centre.
Future<OSMGeoPoint?> chooseOSMLocation(
  BuildContext context,
  OSMGeocodeResult result,
) async {
  if (result.options.isEmpty) return null;
  if (!result.isFallback && result.options.length == 1) {
    return result.options.single;
  }
  return showDialog<OSMGeoPoint>(
    context: context,
    builder: (_) => OSMLocationPicker(result: result),
  );
}

class OSMLocationPicker extends StatelessWidget {
  final OSMGeocodeResult result;

  const OSMLocationPicker({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isFr = Localizations.localeOf(context).languageCode.startsWith('fr');
    return AlertDialog(
      title: Text(isFr ? 'Confirmer le lieu' : 'Confirm the location'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.isFallback
                  ? (isFr
                      ? 'L’adresse exacte est introuvable. Voici les lieux trouvés avec une adresse moins précise. Choisissez le centre de votre recherche ou annulez pour corriger la saisie.'
                      : 'The exact address was not found. These places match a less precise address. Choose your search centre or cancel to edit the address.')
                  : (isFr
                      ? 'Plusieurs lieux correspondent. Choisissez votre zone de recherche.'
                      : 'Several places match. Choose your search area.')),
              const SizedBox(height: 12),
              for (final point in result.options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(point.displayName.isEmpty
                      ? result.queryUsed
                      : point.displayName),
                  subtitle: Text(
                    '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
                  ),
                  onTap: () => Navigator.of(context).pop(point),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isFr ? 'Annuler' : 'Cancel'),
        ),
      ],
    );
  }
}
