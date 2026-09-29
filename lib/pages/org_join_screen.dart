// lib/pages/org_join_screen.dart
// UI 2026 — Glassmorphism, fond auroré animé

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
import 'home_page.dart';
import 'preparing_space_screen.dart';

import '../theme/prospecto_colors.dart';
class _P {
  static const indigo     = ProspectoColors.blue;
  static const violet     = ProspectoColors.green;
  static const mint       = ProspectoColors.green;
  static const coral      = ProspectoColors.peach;
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

class OrgJoinScreen extends StatefulWidget {
  static const routeName = '/org_join';
  const OrgJoinScreen({Key? key}) : super(key: key);

  @override
  State<OrgJoinScreen> createState() => _OrgJoinScreenState();
}

class _OrgJoinScreenState extends State<OrgJoinScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _codeCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) _emailCtrl.text = user!.email!;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool get _needsAuthentication {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

  Future<User?> _authenticateForEnterprise() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null && !current.isAnonymous) return current;

    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    var loginMode = true;
    var obscured = true;
    var busy = false;
    String? error;

    final user = await showModalBottomSheet<User>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit({bool google = false}) async {
            if (busy) return;
            setSheetState(() {
              busy = true;
              error = null;
            });
            try {
              User? signedUser;
              if (google) {
                if (kIsWeb) {
                  signedUser = (await FirebaseAuth.instance
                          .signInWithPopup(GoogleAuthProvider()))
                      .user;
                } else {
                  final account = await GoogleSignIn().signIn();
                  if (account == null) {
                    setSheetState(() => busy = false);
                    return;
                  }
                  final auth = await account.authentication;
                  final credential = GoogleAuthProvider.credential(
                    accessToken: auth.accessToken,
                    idToken: auth.idToken,
                  );
                  signedUser = (await FirebaseAuth.instance
                          .signInWithCredential(credential))
                      .user;
                }
              } else if (loginMode) {
                if (emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) {
                  throw 'Saisissez votre e-mail et votre mot de passe.';
                }
                signedUser = (await FirebaseAuth.instance
                        .signInWithEmailAndPassword(
                          email: emailCtrl.text.trim(),
                          password: passCtrl.text,
                        ))
                    .user;
              } else {
                if (nameCtrl.text.trim().isEmpty ||
                    emailCtrl.text.trim().isEmpty ||
                    passCtrl.text.isEmpty) {
                  throw 'Nom, e-mail et mot de passe sont requis.';
                }
                final credential = await FirebaseAuth.instance
                    .createUserWithEmailAndPassword(
                  email: emailCtrl.text.trim(),
                  password: passCtrl.text,
                );
                signedUser = credential.user;
                await signedUser?.updateDisplayName(nameCtrl.text.trim());
              }

              if (signedUser == null) throw 'Connexion annulée.';
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(signedUser.uid)
                  .set({
                'email': signedUser.email,
                'name': signedUser.displayName ?? nameCtrl.text.trim(),
                'lastLoginAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop(signedUser);
              }
            } on FirebaseAuthException catch (e) {
              setSheetState(() {
                error = e.message ?? e.code;
                busy = false;
              });
            } catch (e) {
              setSheetState(() {
                error = e.toString();
                busy = false;
              });
            }
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                20 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LText(
                    'Connexion entreprise',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const LText(
                    'Connectez-vous avant de rejoindre votre organisation.',
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: LText('Connexion')),
                      ButtonSegment(value: false, label: LText('Créer un compte')),
                    ],
                    selected: {loginMode},
                    onSelectionChanged: busy
                        ? null
                        : (value) => setSheetState(() => loginMode = value.first),
                  ),
                  const SizedBox(height: 14),
                  if (!loginMode) ...[
                    TextField(
                      controller: nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Nom complet'.tr(),
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'E-mail'.tr(),
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscured,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe'.tr(),
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setSheetState(() => obscured = !obscured),
                        icon: Icon(obscured
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    LText(error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: busy ? null : () => submit(),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: LText(loginMode ? 'Se connecter' : 'Créer mon compte'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => submit(google: true),
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                    label: const LText('Continuer avec Google'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    return user;
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LText('Saisissez un code valide.')),
      );
      return;
    }

    var user = FirebaseAuth.instance.currentUser;
    if (_needsAuthentication) {
      user = await _authenticateForEnterprise();
      if (user == null || !mounted) return;
      _emailCtrl.text = user.email ?? _emailCtrl.text;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      if (user == null || user.isAnonymous) throw 'Vous devez être connecté.';

      final res = await OrgService(kAppId).acceptInvite(code: code);

      // La Cloud Function enregistre l’organisation et l’espace actif
      // de façon atomique. Le mobile recharge ensuite l’état serveur.
      WorkspaceScope.invalidate();
      if (!mounted) return;
      await PreparingSpaceScreen.open(
        context,
        action: () async {
          final provider = context.read<OrgProvider>();
          await provider.loadFromUser(user!.uid, preferSavedWorkspace: false);
          provider.setAccessMessage(
            'Bienvenue chez ${res['orgName']} — ${_roleLabel(res['role'])}.',
          );
        },
        successRoute: HomePage.routeName,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: LText(e.toString()),
        backgroundColor: _P.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _roleLabel(String? role) {
    switch (role?.toUpperCase()) {
      case 'OWNER':
        return 'Administrateur principal';
      case 'MANAGER':
        return 'Responsable commercial';
      default:
        return 'Commercial';
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
              child: const Icon(Icons.business_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LText(
                'Rejoindre une entreprise',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Glass card form
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.75)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 24, offset: const Offset(0, 8))],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Icon pill
                                Center(
                                  child: Container(
                                    width: 64, height: 64,
                                    decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(18)),
                                    child: const Icon(Icons.key_rounded, color: Colors.white, size: 32),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LText('Entrez le code transmis par votre responsable :',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                                        color: isDark ? _P.onDark : _P.onLight)),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _codeCtrl,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: _dec("Code d’invitation", Icons.key_rounded),
                                  validator: (v) => (v == null || v.trim().length < 6) ? 'Saisissez un code valide' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailCtrl,
                                  readOnly: true,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _dec(
                                    'E-mail du compte',
                                    Icons.alternate_email_rounded,
                                  ).copyWith(
                                    helperText:
                                        'L’invitation sera vérifiée avec l’adresse de votre compte.'.tr(),
                                  ),
                                  validator: (v) => (v == null || !v.contains('@'))
                                      ? 'Connectez-vous avec une adresse e-mail valide'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                // Bouton rejoindre
                                GestureDetector(
                                  onTap: _busy ? null : _join,
                                  child: AnimatedOpacity(
                                    opacity: _busy ? 0.6 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: _P.primary,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [BoxShadow(color: _P.indigo.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
                                      ),
                                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        _busy
                                            ? const SizedBox(width: 20, height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 10),
                                        const LText('Rejoindre',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                      ]),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Aide code
                                TextButton.icon(
                                  onPressed: _busy ? null : () async {
                                    if (!mounted) return;
                                    showModalBottomSheet(
                                      context: context,
                                      showDragHandle: true,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => const _CodeHelpSheet(),
                                    );
                                  },
                                  icon: Icon(Icons.help_outline_rounded, color: _P.indigo.withOpacity(0.7), size: 18),
                                  label: LText('Où trouver le code ?',
                                      style: TextStyle(color: _P.indigo.withOpacity(0.7), fontWeight: FontWeight.w600)),
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
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet aide code
class _CodeHelpSheet extends StatelessWidget {
  const _CodeHelpSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 8,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LText('Pas reçu le code ?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _P.onLight)),
              const SizedBox(height: 8),
              LText(
                  'Le propriétaire ou un manager doit créer l’invitation dans '
                  'Prospecto > Paramètres > Organisation > Membres, puis vous '
                  'transmettre le code affiché.',
                  style: TextStyle(color: _P.onLightSub, fontSize: 13, height: 1.5)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_P.indigo, _P.violet],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: _P.indigo.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const LText('Compris',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
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
