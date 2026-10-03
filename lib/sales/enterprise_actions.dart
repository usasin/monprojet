import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../config.dart';
import '../services/org_service.dart';

class EnterpriseActions {
  static Future<bool> remove(
    BuildContext context,
    String orgId,
    String kind,
    String id, {
    String? ownerUid,
  }) async {
    final noun = kind == 'invite'
        ? 'cette invitation'
        : kind == 'prospect'
        ? 'cette fiche prospect'
        : 'cette opportunité';
    final message = kind == 'invite'
        ? 'Le lien d’invitation ne permettra plus de rejoindre l’entreprise.'
        : kind == 'prospect'
        ? 'La fiche sera retirée du répertoire. Les ventes et comptes rendus déjà enregistrés restent dans l’historique.'
        : 'L’opportunité sera retirée des résultats et du suivi de tous les membres. Son historique reste conservé.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer $noun ?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return false;
    try {
      if (kind == 'invite') {
        await OrgService(kAppId).revokeInvite(orgId, id);
      } else {
        await FirebaseFunctions.instanceFor(
          region: 'europe-west1',
        ).httpsCallable('deleteEnterpriseRecord').call({
          'appId': kAppId,
          'orgId': orgId,
          'kind': kind,
          'id': id,
          if (ownerUid != null) 'ownerUid': ownerUid,
        });
      }
      return true;
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is FirebaseFunctionsException
                  ? e.message ?? 'Suppression refusée.'
                  : 'Suppression impossible. Réessayez.',
            ),
          ),
        );
      return false;
    }
  }
}
