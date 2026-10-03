import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../config.dart';
import '../widgets/brand_background.dart';
import 'enterprise_display.dart';
import 'sales_visuals.dart';

class EnterpriseSettingsPage extends StatefulWidget {
  const EnterpriseSettingsPage({
    super.key,
    required this.orgId,
    required this.settings,
  });
  final String orgId;
  final EnterpriseDisplaySettings settings;
  @override
  State<EnterpriseSettingsPage> createState() => _EnterpriseSettingsPageState();
}

class _EnterpriseSettingsPageState extends State<EnterpriseSettingsPage> {
  late bool contracts = widget.settings.showContracts,
      revenue = widget.settings.showRevenue;
  bool saving = false;
  String? error;
  Future<void> save() async {
    if (!contracts && !revenue) {
      setState(() => error = 'Choisissez au moins un indicateur.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('updateEnterpriseDisplaySettings').call({
        'appId': kAppId,
        'orgId': widget.orgId,
        'showContracts': contracts,
        'showRevenue': revenue,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is FirebaseFunctionsException
              ? e.message
              : 'Enregistrement impossible.',
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => BrandBackground(
    animate: false,
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Indicateurs de l’entreprise'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const VisualHero(
            title: 'Vos résultats, votre choix',
            subtitle: 'Un affichage commun à toutes les équipes.',
            icon: Icons.tune,
          ),
          const SizedBox(height: 16),
          VisualSection(
            title: 'Indicateurs à afficher',
            icon: Icons.insights_outlined,
            child: Column(
              children: [
                CheckboxListTile(
                  value: contracts,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => contracts = v!),
                  title: const Text('Contrats signés'),
                  subtitle: const Text('Nombre de signatures et taux de gain'),
                ),
                CheckboxListTile(
                  value: revenue,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => revenue = v!),
                  title: const Text('Chiffre d’affaires'),
                  subtitle: const Text('Montants HT déclarés des affaires'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (!revenue)
            const Text(
              'Les montants seront masqués dans l’accueil, les fiches, les résultats et les comparaisons. Les montants déjà enregistrés sont conservés.',
            ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: const Icon(Icons.check),
            label: Text(
              saving ? 'Enregistrement…' : 'Enregistrer pour l’entreprise',
            ),
          ),
        ],
      ),
    ),
  );
}
