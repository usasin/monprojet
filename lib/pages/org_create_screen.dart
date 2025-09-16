// lib/pages/org_create_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../services/org_service.dart';
import 'billing_screen.dart';

class OrgCreateScreen extends StatefulWidget {
  static const routeName = '/org_create';
  const OrgCreateScreen({Key? key}) : super(key: key);

  @override
  State<OrgCreateScreen> createState() => _OrgCreateScreenState();
}

class _OrgCreateScreenState extends State<OrgCreateScreen> {
  // Étape 1 : code d’activation
  final _codeCtrl = TextEditingController();
  bool _checking = false;
  bool _codeOk = false;
  String? _plan; // affiché si code OK

  // Auth intégrée (Étape 2)
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  bool _obscured   = true;
  bool _loginMode  = true;
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn();

  // Étape 3 : création org
  final _orgNameCtrl  = TextEditingController();

  // Renvoi code
  final _receiptEmail = TextEditingController();
  final _orderCtrl    = TextEditingController();

  bool _busy = false;
  String? _orgId;
  String? _orgName;

  User? get _user => FirebaseAuth.instance.currentUser;
  bool get _needsAuth {
    final u = _user;
    if (u == null) return true;
    if (u.isAnonymous) return true;
    return false;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _orgNameCtrl.dispose();
    _receiptEmail.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // -------- Étape 1 : pré-vérif licence --------
  Future<void> _checkCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      _snack('Saisissez votre code d’activation.'); return;
    }
    setState(() { _checking = true; _codeOk = false; _plan = null; });
    try {
      final plan = await OrgService(kAppId).precheckActivationCode(code);
      setState(() { _codeOk = true; _plan = plan; });
      _snack('Code valide — plan $plan');
    } catch (e) {
      _snack('Code invalide : $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  // -------- Étape 2 : Auth intégrée --------
  Future<void> _afterAuth(User user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'name' : user.displayName,
      'mode' : null, // pas SOLO
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) setState(() {});
  }

  Future<void> _signInEmail() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('Remplissez e-mail et mot de passe.'); return;
    }
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await _afterAuth(cred.user!);
    } on FirebaseAuthException catch (e) { _snack(e.message ?? e.code); }
  }

  Future<void> _signUpEmail() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('Nom, e-mail et mot de passe sont requis.'); return;
    }
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name': _nameCtrl.text.trim(),
        'email': cred.user!.email,
        'createdAt': FieldValue.serverTimestamp(),
        'mode': null,
      }, SetOptions(merge: true));
      await _afterAuth(cred.user!);
    } on FirebaseAuthException catch (e) { _snack(e.message ?? e.code); }
  }

  Future<void> _googleLogin() async {
    try {
      User? user;
      if (kIsWeb) {
        final prov = GoogleAuthProvider();
        user = (await FirebaseAuth.instance.signInWithPopup(prov)).user;
      } else {
        final gUser = await _google.signIn();
        if (gUser == null) return;
        final gAuth = await gUser.authentication;
        final cred = GoogleAuthProvider.credential(
            idToken: gAuth.idToken, accessToken: gAuth.accessToken);
        user = (await _auth.signInWithCredential(cred)).user;
      }
      if (user == null) throw 'Google annulé';
      await _afterAuth(user);
    } catch (e) {
      _snack('Erreur Google : $e');
    }
  }

  // -------- Étape 3 : Création --------
  Future<void> _createOrgWithActivation() async {
    final name = _orgNameCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();

    if (!_codeOk) { _snack('Validez d’abord votre code.'); return; }
    if (_needsAuth) { _snack('Connectez-vous.'); return; }
    if (name.isEmpty) { _snack('Saisissez le nom de l’entreprise.'); return; }

    final u = _user!;
    setState(() => _busy = true);
    try {
      final res = await OrgService(kAppId).createOrgWithActivation(
        ownerUid: u.uid,
        ownerEmail: u.email ?? '',
        name: name,
        activationCode: code,
      );

      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'orgId'          : res['orgId'],
        'orgName'        : res['orgName'],
        'role'           : res['role'],
        'currentOrgId'   : res['orgId'],
        'currentOrgName' : res['orgName'],
        'currentRole'    : res['role'],
        'orgIds'         : FieldValue.arrayUnion([res['orgId']]),
        'mode'           : null,
      }, SetOptions(merge: true));

      setState(() { _orgId = res['orgId']; _orgName = res['orgName']; });
      _snack('Organisation activée et créée ✅');
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestActivationResend() async {
    final email = _receiptEmail.text.trim();
    final order = _orderCtrl.text.trim();
    if (email.isEmpty && order.isEmpty) {
      _snack('Indiquez au moins un champ (email ou n° de commande).'); return;
    }
    setState(() => _busy = true);
    try {
      final u = FirebaseAuth.instance.currentUser;
      await OrgService(kAppId).requestActivationResend(
        email: email.isEmpty ? null : email,
        orderId: order.isEmpty ? null : order,
        requesterUid: u?.uid,
        requesterEmail: u?.email,
      );
      _snack('Demande envoyée. Surveillez votre boîte mail (et SPAMS).');
    } catch (e) {
      _snack('Impossible d’envoyer la demande : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // -------- UI --------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un espace entreprise'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_busy || _checking) const LinearProgressIndicator(minHeight: 2),

                // Étape 1 : Code d’activation (obligatoire)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('1) Code d’activation',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        const Text('Entrez le code reçu après paiement.'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Code (ex : X7Q2M6)',
                            prefixIcon: const Icon(Icons.vpn_key_rounded),
                            suffixIcon: _codeOk
                                ? const Icon(Icons.verified_rounded, color: Colors.green)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _checking ? null : _checkCode,
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Continuer'),
                        ),
                        if (_codeOk && _plan != null) ...[
                          const SizedBox(height: 6),
                          Text('Code valide — plan : $_plan',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Étape 2 : Auth (affichée SEULEMENT si code OK)
                if (_codeOk) _EnterpriseAuthCard(
                  enabled: _needsAuth,
                  loginMode: _loginMode,
                  emailCtrl: _emailCtrl,
                  passCtrl: _passCtrl,
                  nameCtrl: _nameCtrl,
                  obscured: _obscured,
                  onToggleObscure: () => setState(() => _obscured = !_obscured),
                  onToggleMode: () => setState(() => _loginMode = !_loginMode),
                  onSignIn: _signInEmail,
                  onSignUp: _signUpEmail,
                  onGoogle: _googleLogin,
                ),

                // Étape 3 : Détails org (nom) + créer (seulement si code OK)
                if (_codeOk) ...[
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('3) Créer l’espace',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 6),
                          const Text('Nom de votre entreprise :'),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _orgNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nom de l’entreprise',
                              prefixIcon: Icon(Icons.apartment_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _busy ? null : _createOrgWithActivation,
                            icon: const Icon(Icons.factory_rounded),
                            label: const Text('Créer l’espace'),
                          ),
                          if (_orgId != null) ...[
                            const SizedBox(height: 8),
                            Text('Créé : $_orgName ($_orgId)',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Liens : Tarifs / Renvoyer code
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Besoin d’un code ?',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        const Text('Souscrivez un abonnement ou demandez un renvoi.'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pushNamed(BillingScreen.routeName),
                          icon: const Icon(Icons.credit_card_rounded),
                          label: const Text('Voir les tarifs'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _receiptEmail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail utilisé lors du paiement (optionnel)',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _orderCtrl,
                          decoration: const InputDecoration(
                            labelText: 'N° de commande (optionnel)',
                            prefixIcon: Icon(Icons.receipt_long_rounded),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _busy ? null : _requestActivationResend,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Demander le renvoi du code'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Auth Entreprise intégrée (désactivée si déjà connecté)
class _EnterpriseAuthCard extends StatelessWidget {
  final bool enabled; // si false et déjà connecté, on n’affiche que “Déjà connecté”
  final bool loginMode;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final TextEditingController nameCtrl;
  final bool obscured;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleMode;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final VoidCallback onGoogle;

  const _EnterpriseAuthCard({
    Key? key,
    required this.enabled,
    required this.loginMode,
    required this.emailCtrl,
    required this.passCtrl,
    required this.nameCtrl,
    required this.obscured,
    required this.onToggleObscure,
    required this.onToggleMode,
    required this.onSignIn,
    required this.onSignUp,
    required this.onGoogle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = FirebaseAuth.instance.currentUser;
    if (!enabled && u != null && !u.isAnonymous) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded),
              const SizedBox(width: 8),
              Expanded(child: Text('Connecté : ${u.email ?? u.uid}')),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('2) Se connecter (Entreprise)',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Connexion dédiée “Entreprise” (pas de mode invité).'),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onToggleMode,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: loginMode ? cs.primary.withOpacity(.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Déjà un compte', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: onToggleMode,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !loginMode ? cs.primary.withOpacity(.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text("S'inscrire", style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            if (!loginMode)
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
            if (!loginMode) const SizedBox(height: 10),

            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: passCtrl,
              obscureText: obscured,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(obscured ? Icons.visibility : Icons.visibility_off),
                  onPressed: onToggleObscure,
                ),
              ),
            ),
            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: loginMode ? onSignIn : onSignUp,
              icon: Icon(loginMode ? Icons.login_rounded : Icons.person_add_rounded),
              label: Text(loginMode ? 'Se connecter' : "S'inscrire"),
            ),
            const SizedBox(height: 10),

            Row(
              children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('ou'),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: onGoogle,
              icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: const Text('Continuer avec Google'),
            ),
          ],
        ),
      ),
    );
  }
}
