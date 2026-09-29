import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/org_provider.dart';
import '../services/developer_access_service.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';
import '../widgets/localized_text.dart';
import 'home_page.dart';
import 'org_create_screen.dart';
import 'preparing_space_screen.dart';

class DeveloperConsoleScreen extends StatefulWidget {
  static const routeName = '/developer_console';

  const DeveloperConsoleScreen({super.key});

  @override
  State<DeveloperConsoleScreen> createState() =>
      _DeveloperConsoleScreenState();
}

class _DeveloperConsoleScreenState extends State<DeveloperConsoleScreen> {
  final _service = DeveloperAccessService();
  final _companyNameController =
      TextEditingController(text: 'Entreprise test Prospecto');

  bool _checking = true;
  bool _isDeveloper = false;
  bool _busy = false;
  String _selectedPlan = 'TEAM';
  DeveloperActivationCode? _activation;
  bool _routeArgumentsApplied = false;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgumentsApplied) return;
    _routeArgumentsApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final requestedPlan = args['plan']?.toString().toUpperCase();
      if (DeveloperAccessService.plans.any((plan) => plan.code == requestedPlan)) {
        _selectedPlan = requestedPlan!;
      }
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAccess() async {
    try {
      final allowed = await _service.isDeveloper(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _isDeveloper = allowed;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDeveloper = false;
        _checking = false;
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LText(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _generateCode() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final activation =
          await _service.createActivationCode(_selectedPlan);
      if (!mounted) return;
      setState(() => _activation = activation);
      await Clipboard.setData(ClipboardData(text: activation.code));
      _showMessage('Code de test créé et copié.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openOrganizationCreation() async {
    final activation = _activation;
    if (activation == null) {
      _showMessage('Créez d’abord un code de test.');
      return;
    }
    await Navigator.of(context).pushNamed(
      OrgCreateScreen.routeName,
      arguments: <String, String>{
        'activationCode': activation.code,
        'companyName': _companyNameController.text.trim(),
      },
    );
  }

  Future<void> _changePlan() async {
    final user = FirebaseAuth.instance.currentUser;
    final org = context.read<OrgProvider>();
    final orgId = org.orgId;
    if (_busy || user == null || orgId == null) return;
    setState(() => _busy = true);
    try {
      final result = await _service.setOrganizationPlan(
        orgId: orgId,
        plan: _selectedPlan,
      );
      await org.refresh(user.uid);
      _showMessage(
        'Forfait de test ${result.label} activé (${result.maxSeats} places).',
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchToTeam() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_busy || user == null) return;
    setState(() => _busy = true);
    try {
      await PreparingSpaceScreen.open(
        context,
        action: () => context.read<OrgProvider>().switchToTeam(user.uid),
        successRoute: DeveloperConsoleScreen.routeName,
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetOrganization() async {
    final user = FirebaseAuth.instance.currentUser;
    final org = context.read<OrgProvider>();
    final orgId = org.orgId;
    if (_busy || user == null || orgId == null) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const LText('Réinitialiser l’entreprise de test ?'),
            content: const LText(
              'Toutes les données de cette entreprise de test seront supprimées. '
              'Les données de votre espace personnel resteront intactes.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: LText('Annuler'.tr()),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const LText('Réinitialiser'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.deleteOrganization(orgId);
      await org.loadFromUser(user.uid, preferSavedWorkspace: false);
      if (!mounted) return;
      await PreparingSpaceScreen.open(
        context,
        action: () async {},
        successRoute: HomePage.routeName,
      );
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    final user = FirebaseAuth.instance.currentUser;

    return BrandBackground(
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const LText(
            'Console développeur',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: SafeArea(
          child: _checking
              ? const Center(child: CircularProgressIndicator())
              : user == null || user.isAnonymous
                  ? const _DeveloperMessage(
                      icon: Icons.login_rounded,
                      title: 'Connexion requise',
                      message:
                          'Connectez le compte développeur avant d’ouvrir cette console.',
                    )
                  : !_isDeveloper
                      ? const _DeveloperMessage(
                          icon: Icons.lock_rounded,
                          title: 'Accès refusé',
                          message:
                              'Ce compte ne possède pas la revendication sécurisée prospectoDeveloper.',
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          children: [
                            const _DeveloperHeader(),
                            const SizedBox(height: 14),
                            const _InfoCard(
                              icon: Icons.workspace_premium_rounded,
                              title: 'Premium personnel développeur',
                              message:
                                  'Toutes les limites Premium et les publicités sont désactivées pour ce compte développeur.',
                              color: ProspectoColors.blue,
                            ),
                            const SizedBox(height: 14),
                            _PlanSelector(
                              selectedPlan: _selectedPlan,
                              onChanged: _busy
                                  ? null
                                  : (value) =>
                                      setState(() => _selectedPlan = value),
                            ),
                            const SizedBox(height: 14),
                            if (!org.teamAvailable) ...[
                              _CreateTestCompanyCard(
                                controller: _companyNameController,
                                activation: _activation,
                                busy: _busy,
                                onGenerate: _generateCode,
                                onOpenCreation: _openOrganizationCreation,
                              ),
                            ] else if (!org.isTeam) ...[
                              _InfoCard(
                                icon: Icons.swap_horiz_rounded,
                                title: 'Espace entreprise disponible',
                                message:
                                    'Ouvrez d’abord votre espace entreprise pour modifier son forfait de test.',
                                color: ProspectoColors.green,
                              ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: _busy ? null : _switchToTeam,
                                child: const LText('Ouvrir l’espace entreprise'),
                              ),
                            ] else ...[
                              _CurrentTestCompanyCard(
                                org: org,
                                busy: _busy,
                                onChangePlan: _changePlan,
                                onReset: _resetOrganization,
                              ),
                            ],
                          ],
                        ),
        ),
      ),
    );
  }
}

class _DeveloperHeader extends StatelessWidget {
  const _DeveloperHeader();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.developer_mode_rounded,
                  color: ProspectoColors.green, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: LText(
                  'Environnement de test sécurisé',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          LText(
            'Créez une entreprise de test et passez librement entre Essentiel, Équipe et Business sans paiement Stripe.',
            style: TextStyle(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PlanSelector extends StatelessWidget {
  const _PlanSelector({required this.selectedPlan, required this.onChanged});

  final String selectedPlan;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LText(
            'Forfait à tester',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final plan in DeveloperAccessService.plans) ...[
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: plan.code,
              groupValue: selectedPlan,
              onChanged:
                  onChanged == null ? null : (value) => onChanged!(value!),
              title: LText(
                plan.label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: LText('${plan.maxSeats} utilisateurs au total'),
              activeColor: ProspectoColors.green,
            ),
            if (plan != DeveloperAccessService.plans.last)
              const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _CreateTestCompanyCard extends StatelessWidget {
  const _CreateTestCompanyCard({
    required this.controller,
    required this.activation,
    required this.busy,
    required this.onGenerate,
    required this.onOpenCreation,
  });

  final TextEditingController controller;
  final DeveloperActivationCode? activation;
  final bool busy;
  final VoidCallback onGenerate;
  final VoidCallback onOpenCreation;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LText(
            'Créer une entreprise de test',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Nom de l’entreprise de test',
              prefixIcon: const Icon(Icons.apartment_rounded),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : onGenerate,
            style: FilledButton.styleFrom(
              backgroundColor: ProspectoColors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.vpn_key_rounded),
                ],
                const SizedBox(width: 8),
                const Flexible(
                  child: LText(
                    'Générer un code développeur',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          if (activation != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ProspectoColors.blue.withOpacity(.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ProspectoColors.blue.withOpacity(.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LText(
                    '${activation!.planLabel} • ${activation!.maxSeats} places',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    activation!.code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onOpenCreation,
                    child: const LText('Continuer vers la création'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentTestCompanyCard extends StatelessWidget {
  const _CurrentTestCompanyCard({
    required this.org,
    required this.busy,
    required this.onChangePlan,
    required this.onReset,
  });

  final OrgProvider org;
  final bool busy;
  final VoidCallback onChangePlan;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                org.developerTest
                    ? Icons.science_rounded
                    : Icons.business_rounded,
                color: org.developerTest
                    ? ProspectoColors.green
                    : ProspectoColors.peach,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: LText(
                  org.orgName ?? 'Entreprise',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LText(
            org.developerTest
                ? 'Forfait actuel : ${(org.plan ?? 'TEST').toUpperCase()} • ${org.maxSeats ?? 0} places'
                : 'Cette entreprise est réelle. La console développeur ne modifiera pas son abonnement.',
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy || !org.developerTest ? null : onChangePlan,
            style: FilledButton.styleFrom(
              backgroundColor: ProspectoColors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const LText('Appliquer le forfait sélectionné'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy || !org.developerTest ? null : onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const LText('Supprimer l’entreprise de test'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LText(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                LText(message, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperMessage extends StatelessWidget {
  const _DeveloperMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: ProspectoColors.peach),
              const SizedBox(height: 12),
              LText(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              LText(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.45)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}
