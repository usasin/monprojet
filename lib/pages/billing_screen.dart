import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart'; // kAppId

class BillingScreen extends StatefulWidget {
  static const routeName = '/billing';
  const BillingScreen({Key? key}) : super(key: key);

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  bool yearly = true; // toggle Annuel/Mensuel

  // ---------- Contact form ----------
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendContact() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance
          .collection('apps')
          .doc(kAppId)
          .collection('contactRequests')
          .add({
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'company': _companyCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'billing_screen',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci ! Nous vous recontactons très vite.')),
      );
      _formKey.currentState!.reset();
      _nameCtrl.clear();
      _emailCtrl.clear();
      _companyCtrl.clear();
      _phoneCtrl.clear();
      _messageCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Envoi impossible : $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Plans (prix par utilisateur par mois)
    final plans = [
      _Plan(
        name: 'Solo',
        desc: '1 utilisateur • prospection & carte',
        monthlyPrice: 24,
        yearlyPriceMonthlyEq: 19, // affiché comme /mois (facturé 189€/an)
        badge: 'Indépendant',
        features: const [
          'Carto & itinéraires',
          'Prospects illimités',
          'Suivi d’activités',
          'Export CSV',
          'Support e-mail',
        ],
      ),
      _Plan(
        name: 'Équipe',
        desc: 'Min. 3 utilisateurs • gestion d’équipe',
        monthlyPrice: 39,
        yearlyPriceMonthlyEq: 35,
        highlighted: true,
        badge: 'Recommandé',
        features: const [
          'Invitations illimitées',
          'Territoires & tournées',
          'Reporting équipe',
          'Rôles & permissions',
          'Support prioritaire',
        ],
      ),
      _Plan(
        name: 'Pro',
        desc: 'Min. 5 utilisateurs • avancé',
        monthlyPrice: 59,
        yearlyPriceMonthlyEq: 49,
        features: const [
          'Objectifs & tableaux de bord',
          'Notes vocales & pièces jointes',
          'Automations (webhooks/API)',
          'SLA support 24–48h',
          'Export BI',
        ],
      ),
      _Plan.enterprise(),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            elevation: 0,
            backgroundColor: cs.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeaderGradient(),
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 12),
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // ✅ Evite l’overflow quand l’appbar se compacte
                  const Flexible(
                    child: Text(
                      'Tarifs & Abonnements',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Toggle Annuel / Mensuel
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: _Segment(
                        label: 'Mensuel',
                        selected: !yearly,
                        onTap: () => setState(() => yearly = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Segment(
                        label: 'Annuel (-15%)',
                        selected: yearly,
                        onTap: () => setState(() => yearly = true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Plans
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverList.builder(
              itemCount: plans.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlanCard(
                  plan: plans[i],
                  yearly: yearly,
                  onSelect: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Paiement à brancher (Stripe/Store). '
                              'Après achat, vous recevez un e-mail avec votre CODE D’ACTIVATION.',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Bandeau info
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Après achat, vous recevez un e-mail avec votre CODE D’ACTIVATION '
                        'pour créer l’espace Entreprise. Les abonnements sont par utilisateur.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

          // Formulaire de contact
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _ContactCard(
                formKey: _formKey,
                nameCtrl: _nameCtrl,
                emailCtrl: _emailCtrl,
                companyCtrl: _companyCtrl,
                phoneCtrl: _phoneCtrl,
                messageCtrl: _messageCtrl,
                sending: _sending,
                onSubmit: _sendContact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Widgets ----------

class _HeaderGradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF003283), Color(0xFF4F6CD6), Color(0xFFC7AFF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 28,
            right: -20,
            child: Opacity(
              opacity: .15,
              child: Icon(Icons.my_location_rounded, size: 160, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Text(
              'Des tarifs simples, pensés pour la prospection terrain.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44,
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: selected
              ? [BoxShadow(color: cs.primary.withOpacity(.3), blurRadius: 12, offset: const Offset(0,6))]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? cs.onPrimary : cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _Plan {
  final String name;
  final String desc;
  final int? monthlyPrice; // €/utilisateur/mois
  final int? yearlyPriceMonthlyEq; // €/utilisateur/mois (facturé/an)
  final List<String> features;
  final bool highlighted;
  final String? badge;
  final bool isEnterprise;

  const _Plan({
    required this.name,
    required this.desc,
    required this.monthlyPrice,
    required this.yearlyPriceMonthlyEq,
    required this.features,
    this.highlighted = false,
    this.badge,
  })  : isEnterprise = false;

  const _Plan.enterprise()
      : name = 'Entreprise',
        desc = 'Multi-équipes • SSO • SLA',
        monthlyPrice = null,
        yearlyPriceMonthlyEq = null,
        features = const [
          'Onboarding & migration',
          'SLA & support dédié',
          'SSO (SAML/Google) • Exports BI',
        ],
        highlighted = false,
        badge = 'Sur devis',
        isEnterprise = true;
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool yearly;
  final VoidCallback onSelect;
  const _PlanCard({required this.plan, required this.yearly, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final priceText = () {
      if (plan.isEnterprise) return 'Sur devis';
      if (yearly) {
        final p = plan.yearlyPriceMonthlyEq!;
        // Exemple: 19 €/utilisateur/mois facturé annuellement
        return '$p € / utilisateur / mois · annuel';
      } else {
        final p = plan.monthlyPrice!;
        return '$p € / utilisateur / mois';
      }
    }();

    return Card(
      elevation: plan.highlighted ? 8 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // ✅ Evite l’overflow si le nom du plan est long
                Expanded(
                  child: Text(
                    plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (plan.badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: plan.highlighted ? cs.primary : cs.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      plan.badge!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: plan.highlighted ? cs.onPrimary : cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(plan.desc),
            const SizedBox(height: 10),
            Text(
              priceText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...plan.features.map(
                  (f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (plan.isEnterprise)
              OutlinedButton.icon(
                onPressed: onSelect,
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Demander un devis'),
              )
            else
              FilledButton(
                onPressed: onSelect,
                child: const Text('Choisir ce plan'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController companyCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController messageCtrl;
  final bool sending;
  final VoidCallback onSubmit;

  const _ContactCard({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.companyCtrl,
    required this.phoneCtrl,
    required this.messageCtrl,
    required this.sending,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Parler à un humain 👋', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Laissez-nous vos coordonnées, on vous répond dans la journée.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Votre nom',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (v) => (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: companyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Entreprise (optionnel)',
                  prefixIcon: Icon(Icons.apartment_rounded),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (optionnel)',
                  prefixIcon: Icon(Icons.call_rounded),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: messageCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Votre message',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Message requis' : null,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: sending ? null : onSubmit,
                icon: const Icon(Icons.send_rounded),
                label: Text(sending ? 'Envoi…' : 'Envoyer'),
              ),
              const SizedBox(height: 6),
              Text(
                'RGPD : vos données servent uniquement à vous recontacter pour ce sujet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
