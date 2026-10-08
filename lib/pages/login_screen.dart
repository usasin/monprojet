// lib/pages/login_screen.dart
// UI 2026 — Glassmorphism premium, fond auroré animé, style aligné select_prospects_page

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

import '../widgets/localized_text.dart';
import '../widgets/apple_sign_in_button.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logo_widget.dart';
import '../providers/theme_provider.dart';
import '../providers/org_provider.dart';
import '../widgets/brand_background.dart';
import '../ui/bling.dart';
import 'home_page.dart';
import 'preparing_space_screen.dart';

import '../theme/prospecto_colors.dart';

// ════════════════════════════════════════════════════════════════
//  Palette 2026
// ════════════════════════════════════════════════════════════════
class _P {
  static const indigo = ProspectoColors.blue;
  static const violet = ProspectoColors.green;
  static const sky = ProspectoColors.blueSoft;
  static const mint = ProspectoColors.green;
  static const coral = ProspectoColors.peach;
  static const amber = ProspectoColors.peachSoft;
  static const onLight = ProspectoColors.textPrimary;
  static const onLightSub = ProspectoColors.textSecondary;
  static const onDark = Color(0xFFF0F2FF);
  static const onDarkSub = Color(0xFF9099C4);

  static LinearGradient get primary => const LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient get aurora => const LinearGradient(
    colors: [
      ProspectoColors.backgroundTop,
      ProspectoColors.blueMist,
      ProspectoColors.peachMist,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ════════════════════════════════════════════════════════════════
//  Widget
// ════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    Key? key,
    this.autoGoogle = false,
    this.autoApple = false,
    this.reason,
    this.forcePersonalWorkspace = false,
    this.auth,
  }) : super(key: key);

  final bool autoGoogle;
  final bool autoApple;
  final String? reason;
  final bool forcePersonalWorkspace;
  final FirebaseAuth? auth;

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final _auth = widget.auth ?? FirebaseAuth.instance;
  final _google = GoogleSignIn();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _obscured = true;
  bool _remember = false;
  bool _loginMode = true; // true = connexion, false = inscription
  bool _loading = false;
  String? _error;

  late final AnimationController _logoCtrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();
  late final Animation<double> _logoT = CurvedAnimation(
    parent: _logoCtrl,
    curve: Curves.easeInOutSine,
  );

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    if (widget.autoGoogle) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _signInGoogle());
    } else if (widget.autoApple && appleSignInAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _signInApple());
    }
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('saved_email');
    if (saved != null && saved.isNotEmpty) {
      setState(() {
        _emailCtrl.text = saved;
        _remember = true;
      });
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _setError(String? msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _loading = false;
    });
  }

  Future<void> _afterAuth(UserCredential cred) async {
    final user = cred.user;
    if (user == null) return;
    if (_remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', user.email ?? '');
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'name': user.displayName,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
    if (!mounted) return;
    await PreparingSpaceScreen.open(
      context,
      action: () async {
        final orgProvider = context.read<OrgProvider>();
        if (widget.forcePersonalWorkspace) {
          await orgProvider.switchToPersonal(user.uid);
        } else {
          await orgProvider.loadFromUser(user.uid, preferTeam: true);
        }
      },
      successRoute: HomePage.routeName,
    );
  }

  Future<void> _signInEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await _afterAuth(cred);
    } on FirebaseAuthException catch (e) {
      _setError(_authError(e.code));
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _registerEmail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await cred.user?.updateDisplayName(_nameCtrl.text.trim());
      await _afterAuth(cred);
    } on FirebaseAuthException catch (e) {
      _setError(_authError(e.code));
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _signInGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await _google.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return;
      }
      final auth = await account.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await _afterAuth(await _auth.signInWithCredential(cred));
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> _signInApple() async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      await _afterAuth(await _auth.signInWithProvider(provider));
    } on FirebaseAuthException catch (e) {
      if (const {
        'canceled',
        'user-cancelled',
        'web-context-cancelled',
      }.contains(e.code)) {
        _setError(null);
      } else {
        _setError(_authError(e.code));
      }
    } catch (_) {
      _setError('La connexion Apple n’a pas abouti. Réessayez.');
    }
  }

  Future<void> _signInGuest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _afterAuth(await _auth.signInAnonymously());
    } catch (e) {
      _setError(e.toString());
    }
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte avec cet email.';
      case 'wrong-password':
        return 'Mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Email déjà utilisé.';
      case 'weak-password':
        return 'Mot de passe trop faible (6 caractères min).';
      case 'invalid-email':
        return 'Adresse email invalide.';
      default:
        return 'Erreur : $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final maxW = size.width >= 1024
        ? 900.0
        : (size.shortestSide >= 600 ? 600.0 : 460.0);

    // Logo anim
    final t = _logoT.value * 2 * math.pi;
    final s = math.sin(t);

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: _P.aurora.colors,
        blurSigma: 16,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Logo animé
                      AnimatedBuilder(
                        animation: _logoT,
                        builder: (_, __) => Column(
                          children: [
                            Transform.translate(
                              offset: Offset(0, s * 6),
                              child: Transform.rotate(
                                angle: s * .04,
                                child: Transform.scale(
                                  scale: 1 + s * .015,
                                  child: const LogoWidget(),
                                ),
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(
                                  .12 - .04 * s.abs(),
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Titre
                      Center(
                        child: ShaderMask(
                          shaderCallback: (r) => _P.primary.createShader(r),
                          child: LText(
                            'Prospecto',
                            style: TextStyle(
                              fontSize: size.shortestSide >= 600 ? 38 : 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: LText(
                          widget.reason ?? 'Bienvenue 👋',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? _P.onDarkSub : _P.onLightSub,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Onglets
                      _TabToggle(
                        loginMode: _loginMode,
                        isDark: isDark,
                        onToggle: (v) => setState(() {
                          _loginMode = v;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 16),

                      // ── Form card
                      _FormCard(
                        isDark: isDark,
                        children: [
                          if (!_loginMode) ...[
                            _GlassField(
                              controller: _nameCtrl,
                              label: 'Prénom & Nom',
                              icon: Icons.person_rounded,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _GlassField(
                            controller: _emailCtrl,
                            label: 'Email',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _GlassField(
                            controller: _passCtrl,
                            label: 'Mot de passe',
                            icon: Icons.lock_rounded,
                            obscured: _obscured,
                            onToggleObscure: () =>
                                setState(() => _obscured = !_obscured),
                          ),
                          const SizedBox(height: 8),
                          // Se souvenir
                          GestureDetector(
                            onTap: () => setState(() => _remember = !_remember),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    gradient: _remember ? _P.primary : null,
                                    color: _remember
                                        ? null
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _remember
                                          ? Colors.transparent
                                          : _P.onLightSub.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _remember
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                LText(
                                  'Se souvenir de moi',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? _P.onDarkSub
                                        : _P.onLightSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Erreur
                          if (_error != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: _P.coral.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _P.coral.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: _P.coral,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LText(
                                      _error!,
                                      style: const TextStyle(
                                        color: _P.coral,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Bouton principal
                          _GradientButton(
                            label: _loginMode
                                ? 'Se connecter'.tr()
                                : 'S\'inscrire'.tr(),
                            icon: _loginMode
                                ? Icons.login_rounded
                                : Icons.person_add_rounded,
                            loading: _loading,
                            onTap: _loading
                                ? null
                                : (_loginMode ? _signInEmail : _registerEmail),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Séparateur
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: LText(
                              'ou',
                              style: TextStyle(
                                color: isDark ? _P.onDarkSub : _P.onLightSub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── Social buttons
                      if (appleSignInAvailable) ...[
                        AppleSignInButton(
                          onPressed: _loading ? null : _signInApple,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (!kIsWeb) ...[
                        _SocialButton(
                          label: 'Continuer avec Google'.tr(),
                          icon: 'assets/icons/Google.svg',
                          isDark: isDark,
                          onTap: _loading ? null : _signInGoogle,
                        ),
                        const SizedBox(height: 10),
                      ],
                      _SocialButton(
                        label: 'Continuer en invité'.tr(),
                        icon: null,
                        materialIcon: Icons.person_outline_rounded,
                        isDark: isDark,
                        onTap: _loading ? null : _signInGuest,
                      ),

                      const SizedBox(height: 24),
                      Center(
                        child: LText(
                          '© 2026 Digital Solutions AI  •  Confidentialité & RGPD',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? _P.onDarkSub : _P.onLightSub,
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
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Widgets
// ════════════════════════════════════════════════════════════════

class _TabToggle extends StatelessWidget {
  final bool loginMode, isDark;
  final ValueChanged<bool> onToggle;
  const _TabToggle({
    required this.loginMode,
    required this.isDark,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.13)
                  : Colors.white.withOpacity(0.75),
            ),
          ),
          child: Row(
            children: [
              _Tab(
                label: 'Déjà un compte',
                active: loginMode,
                isDark: isDark,
                onTap: () => onToggle(true),
              ),
              _Tab(
                label: 'S\'inscrire',
                active: !loginMode,
                isDark: isDark,
                onTap: () => onToggle(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active, isDark;
  final VoidCallback onTap;
  const _Tab({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: active ? _P.primary : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _P.indigo.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: LText(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: active
                    ? Colors.white
                    : (isDark ? _P.onDarkSub : _P.onLightSub),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _FormCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.13)
                  : Colors.white.withOpacity(0.75),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool? obscured;
  final VoidCallback? onToggleObscure;
  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscured,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscured ?? false,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.white.withOpacity(0.70),
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: _P.onLightSub),
        prefixIcon: Icon(icon, color: _P.indigo, size: 20),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscured!
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: _P.onLightSub,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _P.indigo.withOpacity(0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _P.indigo, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  const _GradientButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap != null ? 1.0 : 0.55,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: _P.primary,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _P.indigo.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                LText(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String? icon;
  final IconData? materialIcon;
  final bool isDark;
  final VoidCallback? onTap;
  const _SocialButton({
    required this.label,
    this.icon,
    this.materialIcon,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.70),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.80),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  SvgPicture.asset(icon!, width: 22, height: 22)
                else if (materialIcon != null)
                  Icon(materialIcon, color: _P.indigo, size: 22),
                const SizedBox(width: 10),
                LText(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? _P.onDark : _P.onLight,
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

// ════════════════════════════════════════════════════════════════
//  Helper global — requis par AccessControl.requireLogin()
// ════════════════════════════════════════════════════════════════
Future<void> showLoginBottomSheet(
  BuildContext context, {
  String? reason,
}) async {
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LText('Se connecter', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            LText(
              reason ??
                  (appleSignInAvailable
                      ? 'Connecte-toi pour continuer (Apple, Google ou email).'
                      : 'Connecte-toi pour continuer (Google ou email).'),
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (appleSignInAvailable) ...[
              AppleSignInButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LoginScreen(autoApple: true, reason: reason),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LoginScreen(autoGoogle: true, reason: reason),
                    ),
                  );
                },
                icon: const Icon(Icons.login),
                label: const LText('Continuer avec Google'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LoginScreen(autoGoogle: false, reason: reason),
                    ),
                  );
                },
                child: const LText('Utiliser email'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const LText('Plus tard'),
            ),
          ],
        ),
      );
    },
  );
}
