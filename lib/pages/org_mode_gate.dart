import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';
import '../services/org_service.dart';
import '../widgets/brand_background.dart';
import '../widgets/frosted_card.dart';

import 'org_create_screen.dart';
import 'org_join_screen.dart';
import 'login_screen.dart'; // Mode Solo
import 'home_page.dart';   // auto-redirection si déjà en org

class OrgModeGate extends StatefulWidget {
  static const routeName = '/org_gate';
  const OrgModeGate({Key? key}) : super(key: key);

  @override
  State<OrgModeGate> createState() => _OrgModeGateState();
}

class _OrgModeGateState extends State<OrgModeGate> {
  bool _busy = false;

  Future<void> _continueIfAlreadyInOrg() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data  = userDoc.data() ?? {};
      final orgId = (data['currentOrgId'] ?? data['orgId']) as String?;
      if (orgId != null && orgId.isNotEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(HomePage.routeName);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _continueIfAlreadyInOrg();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    return BrandBackground(
      gradientColors: const [Color(0xFFB1CFEC), Color(0xFF003283), Color(0xFFC7AFF1)],
      blurSigma: 18,
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false, // pas de flèche retour
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Choisir le mode'),
          centerTitle: true,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_busy)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 980 : 760),
                  child: FrostedCard(
                    radius: 28,
                    surfaceColor: Colors.white.withOpacity(.15),
                    padding: EdgeInsets.all(isWide ? 28 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo + titre
                        Column(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              width: isWide ? 120 : 96,
                              height: isWide ? 120 : 96,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 12),
                            ShaderMask(
                              shaderCallback: (Rect b) => const LinearGradient(
                                colors: [Color(0xD2FFFFFF), Color(0xFF003283)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(b),
                              child: Text(
                                'Bienvenue sur Prospecto',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isWide ? 40 : 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(blurRadius: 8, offset: Offset(0, 2), color: Colors.black38)
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Pour équipes et indépendants — choisissez votre parcours :',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(.95)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Choix (stack de cartes, anti-overflow)
                        Column(
                          children: [
                            // Entreprise
                            _BigActionCard(
                              icon: Icons.apartment_rounded,
                              title: 'Je suis une entreprise',
                              subtitle: 'Créer un espace et inviter vos salariés',
                              gradient: const [Color(0xFF003283), Color(0xFF6DA6FF)],
                              onTap: () => Navigator.of(context).pushNamed(OrgCreateScreen.routeName),
                            ),
                            const SizedBox(height: 12),

                            // Code d’activation
                            _BigActionCard(
                              icon: Icons.key_rounded,
                              title: 'J’ai un code d’activation',
                              subtitle: 'Rejoindre mon entreprise',
                              gradient: const [Color(0xFF7B61FF), Color(0xFFD2C5FF)],
                              onTap: () => Navigator.of(context).pushNamed(OrgJoinScreen.routeName),
                              trailingBuilder: (context, compact) => compact
                                  ? IconButton(
                                tooltip: 'Pas reçu le code ?',
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  showDragHandle: true,
                                  isScrollControlled: true,
                                  builder: (_) => const _ActivationHelpSheet(),
                                ),
                                icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
                              )
                                  : TextButton.icon(
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  showDragHandle: true,
                                  isScrollControlled: true,
                                  builder: (_) => const _ActivationHelpSheet(),
                                ),
                                icon: const Icon(Icons.help_outline_rounded),
                                label: const Text('Pas reçu le code ?'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Solo
                            _BigActionCard(
                              icon: Icons.person_rounded,
                              title: 'Mode Solo',
                              subtitle: 'Se connecter ou continuer en invité',
                              gradient: const [Color(0xFF00A3B4), Color(0xFF84E8F0)],
                              onTap: () => Navigator.of(context).pushNamed(LoginScreen.routeName),
                            ),
                          ],
                        ),

                        const SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Vous pourrez changer de mode à tout moment depuis Réglages > Organisation.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white.withOpacity(.95)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Widgets =====
class _BigActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool compact)? trailingBuilder;

  const _BigActionCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.trailingBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 360;           // très petit écran
        final showTrailing = trailingBuilder != null && c.maxWidth >= 320;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: Colors.white.withOpacity(.10),
              border: Border.all(color: cs.outlineVariant.withOpacity(.8)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                // Pastille gradient + icône (✔ sans Positioned)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: gradient),
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),

                // Textes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(.95)),
                      ),
                    ],
                  ),
                ),

                // Trailing compact si espace suffisant
                if (showTrailing) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: Colors.white),
                        child: trailingBuilder!(context, compact),
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(.95)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ===== “Pas reçu le code ?” =====
class _ActivationHelpSheet extends StatefulWidget {
  const _ActivationHelpSheet({Key? key}) : super(key: key);

  @override
  State<_ActivationHelpSheet> createState() => _ActivationHelpSheetState();
}

class _ActivationHelpSheetState extends State<_ActivationHelpSheet> {
  bool _sending = false;
  final _codeCtrl = TextEditingController();

  Future<void> _requestResend() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _sending = true);
    try {
      await OrgService(kAppId).requestResend(code: code);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande envoyée. Vérifiez votre boîte mail et vos spams.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de demander un renvoi : $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pas reçu le code ?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 8),
          const Text('Entrez le code partagé par votre entreprise pour demander un renvoi.'),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            decoration: const InputDecoration(
              labelText: 'Code d’activation',
              hintText: 'ex : 7Q2M6C',
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _sending ? null : _requestResend,
                  icon: const Icon(Icons.mail_outlined),
                  label: const Text('Demander un renvoi'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sending ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Fermer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Astuce : regardez aussi dans “Courrier indésirable”.'),
        ],
      ),
    );
  }
}
