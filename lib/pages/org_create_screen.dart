// lib/pages/org_create_screen.dart
// UI 2026 — Glassmorphism, fond auroré animé — logique métier inchangée

import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/org_service.dart';
import '../services/workspace_scope.dart';
import '../providers/org_provider.dart';
import '../widgets/brand_background.dart';
import '../widgets/user_identity_card.dart';
import '../services/account_session_service.dart';
import 'billing_screen.dart';
import 'home_page.dart';
import 'preparing_space_screen.dart';

import '../theme/prospecto_colors.dart';
class _P {
  static const indigo     = ProspectoColors.blue;
  static const violet     = ProspectoColors.green;
  static const mint       = ProspectoColors.green;
  static const coral      = ProspectoColors.peach;
  static const amber      = ProspectoColors.peachSoft;
  static const onLight    = ProspectoColors.textPrimary;
  static const onLightSub = ProspectoColors.textSecondary;
  static const onDark     = Color(0xFFF0F2FF);
  static const onDarkSub  = Color(0xFF9099C4);
  static LinearGradient get primary => const LinearGradient(
    colors: [indigo, violet], begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static LinearGradient get aurora => const LinearGradient(
    colors: [ProspectoColors.backgroundTop, ProspectoColors.blueMist, ProspectoColors.peachMist],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

class OrgCreateScreen extends StatefulWidget {
  static const routeName = '/org_create';
  const OrgCreateScreen({Key? key}) : super(key: key);

  @override
  State<OrgCreateScreen> createState() => _OrgCreateScreenState();
}

class _OrgCreateScreenState extends State<OrgCreateScreen> {
  final _codeCtrl      = TextEditingController();
  bool _checking = false, _codeOk = false;
  ActivationPlan? _plan;

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  bool _obscured   = true, _loginMode = true;
  final _auth   = FirebaseAuth.instance;
  final _google = GoogleSignIn();

  final _orgNameCtrl  = TextEditingController();
  final _receiptEmail = TextEditingController();

  bool _busy = false;
  bool _routeArgumentsApplied = false;
  String? _orgId, _orgName;

  User? get _user => FirebaseAuth.instance.currentUser;
  bool get _needsAuth {
    final u = _user;
    if (u == null) return true;
    if (u.isAnonymous) return true;
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeArgumentsApplied) return;
    _routeArgumentsApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final activationCode = args['activationCode']?.toString().trim() ?? '';
      final companyName = args['companyName']?.toString().trim() ?? '';
      if (activationCode.isNotEmpty) _codeCtrl.text = activationCode;
      if (companyName.isNotEmpty) _orgNameCtrl.text = companyName;
      if (activationCode.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkCode();
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _emailCtrl, _passCtrl, _nameCtrl,
      _orgNameCtrl, _receiptEmail]) c.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: LText(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));

  Future<void> _checkCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) { _snack("Saisissez votre code d'activation."); return; }
    setState(() { _checking = true; _codeOk = false; _plan = null; });
    try {
      final plan = await OrgService(kAppId).precheckActivationCode(code);
      setState(() { _codeOk = true; _plan = plan; });
      _snack('Code valide — ${plan.label}, jusqu’à ${plan.maxSeats} utilisateurs.');
    } catch (e) {
      _snack('Code invalide : $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _afterAuth(User user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email, 'name': user.displayName,
      'mode': null, 'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) setState(() {});
  }

  Future<void> _signInEmail() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('Remplissez e-mail et mot de passe.'); return;
    }
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _passCtrl.text);
      await _afterAuth(cred.user!);
    } on FirebaseAuthException catch (e) { _snack(e.message ?? e.code); }
  }

  Future<void> _signUpEmail() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('Nom, e-mail et mot de passe sont requis.'); return;
    }
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(), password: _passCtrl.text);
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'name': _nameCtrl.text.trim(), 'email': cred.user!.email,
        'createdAt': FieldValue.serverTimestamp(), 'mode': null,
      }, SetOptions(merge: true));
      await _afterAuth(cred.user!);
    } on FirebaseAuthException catch (e) { _snack(e.message ?? e.code); }
  }

  Future<void> _changeAccount() async {
    await AccountSessionService.signOut(forceAccountPicker: true);
    if (!mounted) return;
    context.read<OrgProvider>().clear();
    setState(() {
      _emailCtrl.clear();
      _passCtrl.clear();
    });
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
    } catch (e) { _snack('Erreur Google : $e'); }
  }

  Future<void> _createOrgWithActivation() async {
    final name = _orgNameCtrl.text.trim();
    final code = _codeCtrl.text.trim().toUpperCase();
    if (!_codeOk) { _snack("Validez d'abord votre code."); return; }
    if (_needsAuth) { _snack('Connectez-vous.'); return; }
    if (name.isEmpty) { _snack("Saisissez le nom de l'entreprise."); return; }
    final u = _user!;
    setState(() => _busy = true);
    try {
      final res = await OrgService(kAppId).createOrgWithActivation(
        name: name,
        activationCode: code,
      );
      // La Cloud Function enregistre l’organisation et l’espace actif
      // de façon atomique. Le mobile recharge ensuite l’état serveur.
      WorkspaceScope.invalidate();
      if (!mounted) return;
      await PreparingSpaceScreen.open(
        context,
        action: () async {
          final provider = context.read<OrgProvider>();
          await provider.loadFromUser(u.uid, preferSavedWorkspace: false);
          provider.setAccessMessage(
            'Espace ${res['orgName']} créé et activé.',
          );
        },
        successRoute: HomePage.routeName,
      );
    } catch (e) { _snack('Erreur : $e'); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _requestActivationResend() async {
    final email = _receiptEmail.text.trim();
    if (email.isEmpty) {
      _snack('Saisissez l’adresse e-mail utilisée lors du paiement.');
      return;
    }
    setState(() => _busy = true);
    try {
      await OrgService(kAppId).requestActivationResend(email: email);
      _snack(
        'Si un code actif correspond à cette adresse, un e-mail de récupération vient d’être demandé. Vous pouvez également utiliser le code transmis par votre entreprise.',
      );
    } catch (e) {
      _snack("Impossible d'envoyer la demande : $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: _P.indigo),
    filled: true, fillColor: Colors.white.withOpacity(0.60),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _P.indigo.withOpacity(0.18))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.35))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _P.indigo, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    labelStyle: const TextStyle(fontSize: 13, color: _P.onLightSub),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BrandBackground(
      gradientColors: _P.aurora.colors,
      blurSigma: 14,
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.white.withOpacity(isDark ? 0.05 : 0.28)),
            ),
          ),
          titleSpacing: 8,
          title: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LText(
                'Créer un espace entreprise',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 17,
                  color: isDark ? _P.onDark : _P.onLight,
                ),
              ),
            ),
          ]),
          centerTitle: false,
        ),
        body: SafeArea(
          top: true,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_busy || _checking)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(minHeight: 3, color: _P.indigo),
                      ),
                    if (_busy || _checking) const SizedBox(height: 8),

                    if (!_needsAuth) ...[
                      UserIdentityCard(
                        compact: true,
                        onChangeAccount: _changeAccount,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Étape 1 : Code d'activation
                    _StepCard(
                      step: 1, icon: Icons.vpn_key_rounded,
                      title: "Code d'activation",
                      subtitle: 'Entrez le code reçu après paiement.',
                      isDark: isDark,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        TextField(
                          controller: _codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _dec('Code (ex : X7Q2M6)', Icons.vpn_key_rounded).copyWith(
                            suffixIcon: _codeOk
                                ? const Icon(Icons.verified_rounded, color: _P.mint)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _GradientButton(
                          label: 'Continuer',
                          icon: Icons.check_circle_outline_rounded,
                          onTap: _checking ? null : _checkCode,
                        ),
                        if (_codeOk && _plan != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _P.mint.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _P.mint.withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.check_circle_rounded, color: _P.mint, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LText(
                                  'Code valide — ${_plan!.label} · ${_plan!.maxSeats} utilisateurs max.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: _P.mint),
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // ── Étape 2 : Auth (seulement si code OK)
                    if (_codeOk) _EnterpriseAuthCard(
                      enabled: _needsAuth,
                      loginMode: _loginMode,
                      emailCtrl: _emailCtrl,
                      passCtrl: _passCtrl,
                      nameCtrl: _nameCtrl,
                      obscured: _obscured,
                      isDark: isDark,
                      dec: _dec,
                      onToggleObscure: () => setState(() => _obscured = !_obscured),
                      onToggleMode: () => setState(() => _loginMode = !_loginMode),
                      onSignIn: _signInEmail,
                      onSignUp: _signUpEmail,
                      onGoogle: _googleLogin,
                    ),

                    // ── Étape 3 : Créer org (seulement si code OK)
                    if (_codeOk) ...[
                      const SizedBox(height: 12),
                      _StepCard(
                        step: 3, icon: Icons.factory_rounded,
                        title: "Créer l'espace",
                        subtitle: 'Nom de votre entreprise :',
                        isDark: isDark,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          TextField(
                            controller: _orgNameCtrl,
                            decoration: _dec("Nom de l'entreprise", Icons.apartment_rounded),
                          ),
                          const SizedBox(height: 14),
                          _GradientButton(
                            label: "Créer l'espace",
                            icon: Icons.factory_rounded,
                            onTap: _busy ? null : _createOrgWithActivation,
                          ),
                          if (_orgId != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: _P.mint.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _P.mint.withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.check_circle_rounded, color: _P.mint, size: 18),
                                const SizedBox(width: 8),
                                Expanded(child: LText('Créé : $_orgName ($_orgId)',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: _P.mint),
                                    overflow: TextOverflow.ellipsis)),
                              ]),
                            ),
                          ],
                        ]),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // ── Besoin d'un code
                    _StepCard(
                      step: 0, icon: Icons.credit_card_rounded,
                      title: "Besoin d'un code ?",
                      subtitle: 'Souscrivez un abonnement ou demandez un renvoi.',
                      isDark: isDark,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pushNamed(BillingScreen.routeName),
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              border: Border.all(color: _P.indigo.withOpacity(0.35)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.credit_card_rounded, color: _P.indigo, size: 18),
                              SizedBox(width: 8),
                              LText('Voir les tarifs', style: TextStyle(color: _P.indigo,
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: _receiptEmail,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _dec('E-mail utilisé lors du paiement', Icons.mail_outline_rounded)),
                        const SizedBox(height: 14),
                        _GradientButton(
                          label: 'Demander le renvoi du code',
                          icon: Icons.send_rounded,
                          onTap: _busy ? null : _requestActivationResend,
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title, subtitle;
  final bool isDark;
  final Widget child;
  const _StepCard({required this.step, required this.icon, required this.title,
    required this.subtitle, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.75)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (step > 0) Container(
                width: 26, height: 26,
                decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: LText('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
              ) else Container(
                width: 26, height: 26,
                decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 18, color: _P.indigo),
              const SizedBox(width: 8),
              Expanded(child: LText(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                  color: isDark ? _P.onDark : _P.onLight))),
            ]),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: LText(subtitle, style: TextStyle(fontSize: 13,
                  color: isDark ? _P.onDarkSub : _P.onLightSub)),
            ),
            const SizedBox(height: 16),
            child,
          ]),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _GradientButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: enabled ? _P.primary : const LinearGradient(colors: [Color(0xFF9099C4), Color(0xFF9099C4)]),
            borderRadius: BorderRadius.circular(13),
            boxShadow: enabled ? [BoxShadow(color: _P.indigo.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(child: LText(label, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
          ]),
        ),
      ),
    );
  }
}

// Auth Entreprise
class _EnterpriseAuthCard extends StatelessWidget {
  final bool enabled, loginMode, obscured, isDark;
  final TextEditingController emailCtrl, passCtrl, nameCtrl;
  final InputDecoration Function(String, IconData) dec;
  final VoidCallback onToggleObscure, onToggleMode, onSignIn, onSignUp, onGoogle;

  const _EnterpriseAuthCard({
    required this.enabled, required this.loginMode, required this.obscured,
    required this.isDark, required this.emailCtrl, required this.passCtrl,
    required this.nameCtrl, required this.dec, required this.onToggleObscure,
    required this.onToggleMode, required this.onSignIn, required this.onSignUp,
    required this.onGoogle,
  });

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (!enabled && u != null && !u.isAnonymous) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _P.mint.withOpacity(0.4)),
            ),
            child: Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _P.mint.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.verified_user_rounded, color: _P.mint, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: LText('Connecté : ${u.email ?? u.uid}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? _P.onDark : _P.onLight),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.75)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Header étape 2
            Row(children: [
              Container(width: 26, height: 26,
                  decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: const LText('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
              const SizedBox(width: 10),
              const Icon(Icons.login_rounded, size: 18, color: _P.indigo),
              const SizedBox(width: 8),
              Expanded(child: LText('Se connecter (Entreprise)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                      color: isDark ? _P.onDark : _P.onLight))),
            ]),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 36),
              child: LText('Connexion dédiée "Entreprise" (pas de mode invité).',
                  style: TextStyle(fontSize: 13, color: _P.onLightSub)),
            ),
            const SizedBox(height: 16),

            // Toggle login/signup
            Container(
              decoration: BoxDecoration(
                color: _P.indigo.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: onToggleMode,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: loginMode ? _P.primary : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: LText('Déjà un compte', style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: loginMode ? Colors.white : (isDark ? _P.onDarkSub : _P.onLightSub)))),
                  ),
                )),
                Expanded(child: GestureDetector(
                  onTap: onToggleMode,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: !loginMode ? _P.primary : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: LText("S'inscrire", style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: !loginMode ? Colors.white : (isDark ? _P.onDarkSub : _P.onLightSub)))),
                  ),
                )),
              ]),
            ),
            const SizedBox(height: 14),

            if (!loginMode) ...[
              TextField(controller: nameCtrl, decoration: dec('Nom', Icons.person_rounded)),
              const SizedBox(height: 10),
            ],
            TextField(controller: emailCtrl, decoration: dec('E-mail', Icons.email_rounded),
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            TextField(
              controller: passCtrl,
              obscureText: obscured,
              decoration: dec('Mot de passe', Icons.lock_rounded).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(obscured ? Icons.visibility : Icons.visibility_off, color: _P.onLightSub),
                  onPressed: onToggleObscure,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _GradientButton(
              label: loginMode ? 'Se connecter' : "S'inscrire",
              icon: loginMode ? Icons.login_rounded : Icons.person_add_rounded,
              onTap: loginMode ? onSignIn : onSignUp,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.4))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: LText('ou', style: TextStyle(fontSize: 13, color: isDark ? _P.onDarkSub : _P.onLightSub)),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.4))),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onGoogle,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _P.indigo.withOpacity(0.2)),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.g_mobiledata_rounded, size: 28, color: _P.indigo),
                  SizedBox(width: 8),
                  Flexible(
                    child: LText(
                      'Continuer avec Google',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _P.onLight,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
