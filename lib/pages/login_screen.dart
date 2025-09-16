// lib/pages/login_screen.dart
// ------------------------------------------------------------
// Login modernisé (fond clair/bleuté) avec "onglets" sur la même page.
// - Onglet "Déjà un compte" : Email/MDP + Se souvenir + Google + Invité (couleur différente)
// - Onglet "S'inscrire"    : Nom + Email + MDP
// - Bouton retour vers OrgModeGate
// ------------------------------------------------------------
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../logo_widget.dart';
import '../providers/theme_provider.dart';
import '../widgets/brand_background.dart';
import '../widgets/frosted_card.dart';
import '../ui/bling.dart';

import 'home_page.dart';
import 'org_mode_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn();

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();

  bool _obscured   = true;
  bool _remember   = false;

  /// true = "Déjà un compte", false = "S'inscrire"
  bool _loginMode  = true;

  late final AnimationController _logoCtrl;
  late final Animation<double> _logoT;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _logoT = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeInOutSine);

    _redirectIfLogged();
    _loadPrefs();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveFcmToken(User user) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users')
            .doc(user.uid).set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> _routeAfterAuth(User user) async {
    await _saveFcmToken(user);

    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = snap.data() ?? {};
    final orgId = data['currentOrgId'] as String?;
    final mode  = data['mode'] as String?;
    final isSolo = user.isAnonymous || (mode == 'SOLO');

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      isSolo ? HomePage.routeName : (orgId == null ? OrgModeGate.routeName : HomePage.routeName),
    );
  }

  Future<void> _redirectIfLogged() async {
    final u = _auth.currentUser;
    if (u == null) return;
    final snap = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
    final data = snap.data() ?? {};
    final orgId = data['currentOrgId'] as String?;
    final mode  = data['mode'] as String?;
    final isSolo = u.isAnonymous || (mode == 'SOLO');

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(
        context,
        isSolo ? HomePage.routeName : (orgId == null ? OrgModeGate.routeName : HomePage.routeName),
      );
    });
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _remember   = p.getBool('rememberMe') ?? false;
      if (_remember) {
        _emailCtrl.text = p.getString('email') ?? '';
        _passCtrl.text  = p.getString('password') ?? '';
      }
    });
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('rememberMe', _remember);
    if (_remember) {
      await p.setString('email', _emailCtrl.text);
      await p.setString('password', _passCtrl.text);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signIn() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('Veuillez remplir tous les champs.'.tr()); return;
    }
    try {
      if (_remember) await _savePrefs();
      final cred = await _auth.signInWithEmailAndPassword(
          email: _emailCtrl.text, password: _passCtrl.text);
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': cred.user!.email,
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _routeAfterAuth(cred.user!);
    } on FirebaseAuthException catch (e) {
      _snack(e.message?.tr() ?? e.code);
    }
  }

  Future<void> _signUp() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
      _snack('Veuillez remplir tous les champs.'.tr()); return;
    }
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text, password: _passCtrl.text);
      await FirebaseFirestore.instance.collection('users')
          .doc(cred.user!.uid).set({
        'email'    : cred.user!.email,
        'name'     : _nameCtrl.text,
        'mode'     : null,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('Inscription réussie, connectez-vous'.tr());
      setState(() => _loginMode = true);
    } on FirebaseAuthException catch (e) {
      _snack(e.message?.tr() ?? e.code);
    }
  }

  Future<void> _googleLogin() async {
    try {
      if (kIsWeb) {
        final authProvider = GoogleAuthProvider();
        final userCredential = await FirebaseAuth.instance.signInWithPopup(authProvider);
        final user = userCredential.user;
        if (user == null) throw 'Google Web Sign-In failed';
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'name' : user.displayName,
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _routeAfterAuth(user);
      } else {
        final gUser = await _google.signIn();
        if (gUser == null) return;
        final gAuth = await gUser.authentication;
        final cred = GoogleAuthProvider.credential(
            idToken: gAuth.idToken, accessToken: gAuth.accessToken);
        final result = await _auth.signInWithCredential(cred);
        await FirebaseFirestore.instance.collection('users')
            .doc(result.user!.uid).set({
          'email': result.user!.email,
          'name' : result.user!.displayName,
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _routeAfterAuth(result.user!);
      }
    } catch (e) {
      debugPrint(e.toString());
      _snack('Erreur Google Sign-In'.tr());
    }
  }

  Future<void> _guestLogin() async {
    try {
      final cred = await _auth.signInAnonymously();
      await FirebaseFirestore.instance.collection('users')
          .doc(cred.user!.uid).set({
        'name'      : 'Invité',
        'mode'      : 'SOLO',
        'soloSince' : FieldValue.serverTimestamp(),
        'createdAt' : FieldValue.serverTimestamp(),
        'currentOrgId': null,
      }, SetOptions(merge: true));
      await _routeAfterAuth(cred.user!);
    } catch (e) {
      _snack('Connexion invité impossible'.tr());
    }
  }

  Future<void> _goBack() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed(OrgModeGate.routeName);
    }
  }

  // ---------- UI helpers ----------
  Widget _langFlag(String code, String asset) {
    return PressableScale(
      onTap: () => context.setLocale(Locale(code)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0,2))],
        ),
        padding: const EdgeInsets.all(4),
        child: Image.asset(asset, width: 30, height: 22, fit: BoxFit.cover),
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    List<Color>? colors,
  }) {
    final grad = colors ?? [const Color(0xFF003283), const Color(0xFFE3DEFA)];
    return PressableScale(
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: grad),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: grad.last.withOpacity(.3), blurRadius: 12, offset: const Offset(0,6))],
        ),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _authPills() {
    final activeColor   = Colors.white.withOpacity(.20);
    final inactiveColor = Colors.white.withOpacity(.08);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _loginMode = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _loginMode ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'Déjà un compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _loginMode = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_loginMode ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    "S'inscrire",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final theme     = context.watch<ThemeProvider>().currentTheme;
    final size      = MediaQuery.of(context).size;
    final shortest  = size.shortestSide;
    final isTablet  = shortest >= 600;
    final isDesktop = size.width >= 1024;
    final maxW      = isDesktop ? 900.0 : (isTablet ? 720.0 : 560.0);

    final s  = math.sin(_logoT.value * math.pi * 2);
    final dy = s * 8;
    final rot = s * .05;
    final scale = 1.0 + (s * 0.02);
    final double titleSize = isTablet ? 44 : 38;

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: const [Color(0xFFB1CFEC), Color(0xFF003283), Color(0xFFC7AFF1)],
        blurSigma: 18,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _goBack, // ✅ retour vers la première page
              tooltip: 'Retour',
            ),
            title: const Text('Bienvenue'),
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: FrostedCard(
                    radius: 28,
                    surfaceColor: Colors.white.withOpacity(.15),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo animé style pin
                        AnimatedBuilder(
                          animation: _logoT,
                          builder: (_, __) {
                            return Column(
                              children: [
                                Transform.translate(
                                  offset: Offset(0, dy),
                                  child: Transform.rotate(
                                    angle: rot,
                                    child: Transform.scale(
                                      scale: scale,
                                      child: const LogoWidget(),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 90,
                                  height: 12,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(.15 - .05 * s.abs()),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _langFlag('fr','assets/images/france.png'),
                            const SizedBox(width: 12),
                            _langFlag('en','assets/images/united-kingdom.png'),
                          ],
                        ),

                        const SizedBox(height: 14),
                        _authPills(), // ✅ switch Déjà un compte / S'inscrire

                        const SizedBox(height: 18),
                        // Titre centré
                        ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              colors: [Color(0xD2FFFFFF), Color(0xFF003283)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(bounds);
                          },
                          child: Text(
                            _loginMode ? 'Connexion'.tr() : 'Créer un compte'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: const [Shadow(blurRadius: 8, offset: Offset(0,2), color: Colors.black38)],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Champs spécifiques (AnimatedSwitcher = "slide")
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.05, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: _loginMode
                              ? _SigninForm(
                            emailCtrl: _emailCtrl,
                            passCtrl: _passCtrl,
                            obscured: _obscured,
                            remember: _remember,
                            onToggleObscure: () => setState(() => _obscured = !_obscured),
                            onRememberChanged: (v) => setState(() => _remember = v),
                            onSubmit: _signIn,
                            onGoogle: _googleLogin,
                            onGuest: _guestLogin,
                            gradientButton: _gradientButton,
                          )
                              : _SignupForm(
                            nameCtrl: _nameCtrl,
                            emailCtrl: _emailCtrl,
                            passCtrl: _passCtrl,
                            obscured: _obscured,
                            onToggleObscure: () => setState(() => _obscured = !_obscured),
                            onSubmit: _signUp,
                            gradientButton: _gradientButton,
                          ),
                        ),

                        const SizedBox(height: 16),
                        Text('© 2025 AI-NEGO — RGPD', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- sous-widgets ----------

class _SigninForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscured;
  final bool remember;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onGuest;
  final Widget Function({required String label, required VoidCallback onPressed, IconData? icon, List<Color>? colors}) gradientButton;

  const _SigninForm({
    Key? key,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscured,
    required this.remember,
    required this.onToggleObscure,
    required this.onRememberChanged,
    required this.onSubmit,
    required this.onGoogle,
    required this.onGuest,
    required this.gradientButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Email + MDP
    return Column(
      key: const ValueKey('signin'),
      children: [
        TextField(
          controller: emailCtrl,
          textAlign: TextAlign.center, // texte centré
          decoration: const InputDecoration(
            label: Center(child: Text('Email')),
            prefixIcon: Icon(Icons.email),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passCtrl,
          obscureText: obscured,
          textAlign: TextAlign.center, // texte centré
          decoration: InputDecoration(
            label: Center(child: Text('Mot de passe')),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(obscured ? Icons.visibility : Icons.visibility_off),
              onPressed: onToggleObscure,
            ),
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Checkbox(
              value: remember,
              onChanged: (v) => onRememberChanged(v ?? false),
            ),
            const Text('Se souvenir de moi'),
          ],
        ),

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: gradientButton(
            label: 'Se connecter',
            icon: Icons.login,
            colors: const [Color(0xFF003283), Color(0xFF6DA6FF)],
            onPressed: onSubmit,
          ),
        ),

        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: Divider(color: Colors.white30)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('ou', style: TextStyle(color: Colors.white70)),
            ),
            Expanded(child: Divider(color: Colors.white30)),
          ],
        ),
        const SizedBox(height: 10),

        // Google
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: SvgPicture.asset('assets/icons/Google.svg', width: 22, height: 22, color: Colors.black),
            label: const Text('Continuer avec Google'),
            onPressed: onGoogle,
          ),
        ),

        const SizedBox(height: 8),

        // Invité (couleurs différentes)
        SizedBox(
          width: double.infinity,
          child: gradientButton(
            label: 'Continuer en invité',
            icon: Icons.person_outline,
            colors: const [Color(0xFF00A3B4), Color(0xFF84E8F0)],
            onPressed: onGuest,
          ),
        ),
      ],
    );
  }
}

class _SignupForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscured;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final Widget Function({required String label, required VoidCallback onPressed, IconData? icon, List<Color>? colors}) gradientButton;

  const _SignupForm({
    Key? key,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscured,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.gradientButton,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('signup'),
      children: [
        TextField(
          controller: nameCtrl,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            label: Center(child: Text('Nom')),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: emailCtrl,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            label: Center(child: Text('Email')),
            prefixIcon: Icon(Icons.email),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passCtrl,
          obscureText: obscured,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            label: const Center(child: Text('Mot de passe')),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(obscured ? Icons.visibility : Icons.visibility_off),
              onPressed: onToggleObscure,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: gradientButton(
            label: "S'inscrire",
            icon: Icons.person_add,
            colors: const [Color(0xFF7B61FF), Color(0xFFD2C5FF)],
            onPressed: onSubmit,
          ),
        ),
      ],
    );
  }
}
