import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/developer_access_service.dart';
import '../screens/credits_paywall_page.dart';
import 'developer_console_screen.dart';
import 'enterprise_access_screen.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';

class BillingScreen extends StatefulWidget {
  static const routeName = '/billing';

  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  bool get _apple => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;
  bool _isDeveloper = false;
  String? _openingPlan;

  static const _commonEnterpriseFeatures = <String>[
    'Prospects partagés avec l’équipe',
    'Calendrier d’équipe, tournées attribuées et rendez-vous',
    'Autonomie réglable pour chaque commercial',
    'Reportings et statistiques par commercial',
    'Administrateur principal, responsable commercial et commerciaux',
    'Invitations, gestion des accès et historique d’activité',
    'Logo, nom et slogan de l’entreprise',
    'Premium sans publicité pour tous les membres',
  ];

  static const _plans = <_EnterprisePlan>[
    _EnterprisePlan(
      planCode: 'ESSENTIAL',
      name: 'Essentiel',
      price: '19,90 €',
      seats: '3 utilisateurs au total',
      memberBreakdown: '1 administrateur principal + 2 membres',
      description: 'Pour démarrer avec une petite équipe commerciale.',
      icon: Icons.groups_2_outlined,
      accent: ProspectoColors.blue,
      paymentLink: 'https://buy.stripe.com/6oU00j72W5u3gMR8QFc3m02',
    ),
    _EnterprisePlan(
      planCode: 'TEAM',
      name: 'Équipe',
      price: '39,90 €',
      seats: '10 utilisateurs au total',
      memberBreakdown: '1 administrateur principal + 9 membres',
      description: 'Pour une équipe structurée qui partage ses prospects et son activité.',
      icon: Icons.apartment_rounded,
      accent: ProspectoColors.green,
      recommended: true,
      paymentLink: 'https://buy.stripe.com/9B614nevo09J68d1odc3m01',
    ),
    _EnterprisePlan(
      planCode: 'BUSINESS',
      name: 'Business',
      price: '79,90 €',
      seats: '25 utilisateurs au total',
      memberBreakdown: '1 administrateur principal + 24 membres',
      description: 'Pour une force commerciale plus importante.',
      icon: Icons.business_center_rounded,
      accent: ProspectoColors.peach,
      paymentLink: 'https://buy.stripe.com/cNi8wP0Eyg8HeEJ4Apc3m00',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (!_apple) _loadDeveloperStatus();
  }

  Future<void> _loadDeveloperStatus() async {
    try {
      final value = await DeveloperAccessService().isDeveloper();
      if (mounted) setState(() => _isDeveloper = value);
    } catch (_) {
      // Le parcours Stripe normal reste disponible si le jeton est indisponible.
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _openPersonalPremium() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreditsPaywallPage()),
    );
  }

  Future<void> _openEnterprisePlan(_EnterprisePlan plan) async {
    if (_apple) return;
    if (_openingPlan != null) return;
    if (_isDeveloper) {
      await Navigator.of(context).pushNamed(
        DeveloperConsoleScreen.routeName,
        arguments: <String, String>{'plan': plan.planCode},
      );
      return;
    }
    setState(() => _openingPlan = plan.name);
    final uri = Uri.parse(plan.paymentLink);
    try {
      var opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
      if (!opened) throw Exception('Aucun navigateur disponible.');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: plan.paymentLink));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LText(
            'Impossible d’ouvrir le paiement. Le lien sécurisé a été copié.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _openingPlan = null);
    }
  }

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
  }

  Future<void> _sendContact() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final company = _companyCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    final subject = company.isEmpty
        ? 'Demande Prospecto Entreprise – $name'
        : 'Demande Prospecto Entreprise – $company';
    final body = <String>[
      'Nom : $name',
      'E-mail : $email',
      if (company.isNotEmpty) 'Entreprise : $company',
      '',
      message,
    ].join('\n');

    // L'enregistrement Firestore est utile pour l'historique, mais il ne doit
    // jamais bloquer l'ouverture de l'e-mail (par exemple si le visiteur n'est
    // pas encore connecté ou si le réseau Firebase est momentanément absent).
    try {
      await FirebaseFirestore.instance
          .collection('apps')
          .doc(kAppId)
          .collection('contactRequests')
          .add({
        'name': name,
        'email': email,
        'company': company,
        'phone': '',
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'enterprise_billing_screen',
      });
    } catch (_) {
      // Le vrai envoi se fait via l'application e-mail ci-dessous.
    }

    try {
      final mailUri = Uri(
        scheme: 'mailto',
        path: 'contact@digitalsolutionsai.com',
        query: _encodeQueryParameters({
          'subject': subject,
          'body': body,
        }),
      );
      final opened = await launchUrl(
        mailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        await Clipboard.setData(
          ClipboardData(
            text: 'À : contact@digitalsolutionsai.com\nObjet : $subject\n\n$body',
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText(
              'Aucun logiciel e-mail n’a été trouvé : le message a été copié.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LText(
            'Votre messagerie est ouverte. Appuyez sur Envoyer pour transmettre la demande.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LText('Ouverture de l’e-mail impossible : $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: ProspectoColors.blue),
      filled: true,
      fillColor: Colors.white.withOpacity(.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_apple) {
      return BrandBackground(
        animate: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const LText('Abonnements')),
          body: SafeArea(child: AppleBillingContent(
            onOpenPremium: _openPersonalPremium,
            onEnterpriseAccess: () => Navigator.of(context).pushNamed(EnterpriseAccessScreen.routeName),
          )),
        ),
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return BrandBackground(
      gradientColors: const [
        ProspectoColors.backgroundTop,
        ProspectoColors.blueMist,
        ProspectoColors.peachMist,
      ],
      blurSigma: 14,
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 8,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.white.withOpacity(dark ? .05 : .30)),
            ),
          ),
          title: const Row(
            children: [
              _TitleIcon(),
              SizedBox(width: 10),
              Expanded(
                child: LText(
                  'Tarifs & abonnements',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LText(
                      'Choisissez votre usage',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 7),
                    LText(
                      'L’abonnement Personnel reste géré par Google Play. Les offres Entreprise sont liées à Stripe et activent automatiquement le bon nombre de places.',
                      style: TextStyle(
                        height: 1.45,
                        color: dark ? Colors.white70 : ProspectoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _PersonalPlanCard(onOpenPremium: _openPersonalPremium),
              const SizedBox(height: 18),
              const _SectionTitle(
                badge: 'ENTREPRISE',
                badgeColor: ProspectoColors.green,
                title: 'Prospecto pour les équipes',
                subtitle: 'Les trois offres comprennent les mêmes fonctions. Seul le nombre total d’utilisateurs change.',
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _plans.length; index++) ...[
                TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 420 + index * 100),
                  tween: Tween(begin: 0, end: 1),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, 18 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  ),
                  child: _PlanCard(
                    plan: _plans[index],
                    commonFeatures: _commonEnterpriseFeatures,
                    isOpening: _openingPlan == _plans[index].name,
                    developerMode: _isDeveloper,
                    onPurchase: () => _openEnterprisePlan(_plans[index]),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: ProspectoColors.green),
                        SizedBox(width: 9),
                        Expanded(
                          child: LText(
                            'Activation automatique après paiement',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const LText(
                      'Après le paiement Stripe, Prospecto génère un code d’activation unique et l’affiche sur la page de confirmation. Ce code sert une seule fois à créer l’espace entreprise.',
                      style: TextStyle(height: 1.45),
                    ),
                    const SizedBox(height: 9),
                    const LText(
                      'Les salariés ne paient rien : ils rejoignent ensuite l’entreprise avec un code d’invitation envoyé par leur administrateur.',
                      style: TextStyle(height: 1.45, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.vpn_key_rounded),
                        label: const LText('J’ai déjà mon code d’activation'),
                        style: FilledButton.styleFrom(
                          backgroundColor: ProspectoColors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _GlassPanel(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LText(
                        'Une question avant de démarrer ?',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const LText(
                        'Laissez votre demande. Votre application e-mail s’ouvrira avec le destinataire et le message déjà remplis.',
                        style: TextStyle(height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _decoration('Nom', Icons.person_outline_rounded),
                        validator: (value) => (value ?? '').trim().isEmpty ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _decoration('E-mail professionnel', Icons.mail_outline_rounded),
                        validator: (value) {
                          final email = (value ?? '').trim();
                          if (!email.contains('@')) return 'E-mail invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _companyCtrl,
                        decoration: _decoration('Entreprise', Icons.apartment_rounded),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _messageCtrl,
                        minLines: 3,
                        maxLines: 5,
                        decoration: _decoration('Votre question', Icons.chat_bubble_outline_rounded),
                        validator: (value) => (value ?? '').trim().isEmpty ? 'Message requis' : null,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _sending ? null : _sendContact,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded),
                          label: LText(_sending ? 'Préparation…' : 'Envoyer par e-mail'),
                          style: FilledButton.styleFrom(
                            backgroundColor: ProspectoColors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apple purchases use StoreKit; organizations can activate an existing workspace.
class AppleBillingContent extends StatelessWidget {
  const AppleBillingContent({super.key, required this.onOpenPremium, required this.onEnterpriseAccess});
  final VoidCallback onOpenPremium;
  final VoidCallback onEnterpriseAccess;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _GlassPanel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.workspace_premium_rounded, color: ProspectoColors.blue, size: 36),
          const SizedBox(height: 12),
          const LText('Premium personnel', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const LText('Tournées et prospects illimités, optimisation et utilisation sans publicité.'),
          const SizedBox(height: 8),
          const LText('Les offres mensuelles et annuelles sont disponibles dans l’App Store. Consultez leur prix avant de confirmer votre abonnement.'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onOpenPremium, icon: const Icon(Icons.person_outline), label: const LText('Voir les offres Premium')),
        ],
      )),
      const SizedBox(height: 16),
      _GlassPanel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LText('Votre espace d’équipe', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const LText('Accédez à l’espace mis à disposition par votre entreprise avec le code transmis par votre administrateur.'),
          const SizedBox(height: 12),
          for (final feature in _BillingScreenState._commonEnterpriseFeatures)
            _FeatureLine(feature: feature, color: ProspectoColors.green),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: onEnterpriseAccess, icon: const Icon(Icons.vpn_key_outlined), label: const LText('J’ai un code d’entreprise')),
        ],
      )),
    ],
  );
}

class _TitleIcon extends StatelessWidget {
  const _TitleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ProspectoColors.blue, ProspectoColors.green],
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 19),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String badge;
  final Color badgeColor;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: LText(
              badge,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          LText(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          LText(subtitle, style: const TextStyle(height: 1.4, color: ProspectoColors.textSecondary)),
        ],
      ),
    );
  }
}

class _PersonalPlanCard extends StatelessWidget {
  final VoidCallback onOpenPremium;

  const _PersonalPlanCard({required this.onOpenPremium});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ProspectoColors.blue.withOpacity(.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: ProspectoColors.blue,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlanBadge(
                      label: 'PERSONNEL',
                      color: ProspectoColors.blue,
                    ),
                    SizedBox(height: 7),
                    LText(
                      'Premium personnel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    LText(
                      'Pour un seul utilisateur',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ProspectoColors.blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LText(
                  '3,99 €',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                LText(
                  '/ mois',
                  style: TextStyle(
                    fontSize: 12,
                    color: ProspectoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          const LText(
            'Abonnement Android conservé et géré par Google Play.',
            style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final feature in const [
            'Tournées et prospects illimités',
            'Optimisation et historique',
            'Utilisation sans publicité',
            'Restauration de l’achat depuis Google Play',
          ])
            _FeatureLine(feature: feature, color: ProspectoColors.blue),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onOpenPremium,
              style: OutlinedButton.styleFrom(
                foregroundColor: ProspectoColors.blue,
                side: BorderSide(
                  color: ProspectoColors.blue.withOpacity(.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded),
                  SizedBox(width: 8),
                  Flexible(
                    child: LText(
                      'Voir l’abonnement Google Play',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF17202D).withOpacity(.78) : Colors.white.withOpacity(.68),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(dark ? .10 : .78)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.055),
                blurRadius: 20,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _EnterprisePlan plan;
  final List<String> commonFeatures;
  final VoidCallback onPurchase;
  final bool isOpening;
  final bool developerMode;

  const _PlanCard({
    required this.plan,
    required this.commonFeatures,
    required this.onPurchase,
    required this.isOpening,
    required this.developerMode,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: plan.accent.withOpacity(.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(plan.icon, color: plan.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LText(
                          plan.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (plan.recommended)
                          const _PlanBadge(
                            label: 'RECOMMANDÉ',
                            color: ProspectoColors.green,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    LText(
                      plan.seats,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: plan.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LText(
                  plan.price,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const LText(
                  '/ mois',
                  style: TextStyle(
                    fontSize: 12,
                    color: ProspectoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          LText(
            plan.memberBreakdown,
            style: TextStyle(
              color: plan.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          LText(plan.description, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          for (final feature in commonFeatures)
            _FeatureLine(feature: feature, color: plan.accent),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: plan.accent.withOpacity(.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.sync_rounded, size: 18, color: plan.accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: LText(
                    'Abonnement mensuel Stripe • activation automatique',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isOpening ? null : onPurchase,
              style: FilledButton.styleFrom(
                backgroundColor: plan.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isOpening)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.open_in_new_rounded),
                  const SizedBox(width: 8),
                  Flexible(
                    child: LText(
                      isOpening
                          ? 'Ouverture du paiement…'
                          : (developerMode
                              ? 'Tester cette offre'
                              : 'Choisir cette offre'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  final String feature;
  final Color color;

  const _FeatureLine({required this.feature, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: LText(feature)),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PlanBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: LText(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _EnterprisePlan {
  final String planCode;
  final String name;
  final String price;
  final String seats;
  final String memberBreakdown;
  final String description;
  final IconData icon;
  final Color accent;
  final bool recommended;
  final String paymentLink;

  const _EnterprisePlan({
    required this.planCode,
    required this.name,
    required this.price,
    required this.seats,
    required this.memberBreakdown,
    required this.description,
    required this.icon,
    required this.accent,
    required this.paymentLink,
    this.recommended = false,
  });
}
