// lib/pages/login_screen.dart
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logo_widget.dart';
import '../providers/theme_provider.dart';
import 'home_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn();

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();

  bool _obscured   = true;
  bool _remember   = false;
  bool _loginMode  = true; // true = login, false = signup

  @override
  void initState() {
    super.initState();
    _redirectIfLogged();
    _loadPrefs();
  }

  Future _redirectIfLogged() async {
    if (_auth.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, HomePage.routeName);
      });
    }
  }

  Future _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _remember = p.getBool('rememberMe') ?? false;
      if (_remember) {
        _emailCtrl.text = p.getString('email') ?? '';
        _passCtrl.text  = p.getString('password') ?? '';
      }
    });
  }

  Future _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('rememberMe', _remember);
    if (_remember) {
      await p.setString('email', _emailCtrl.text);
      await p.setString('password', _passCtrl.text);
    }
  }

  // ---------- AUTH EMAIL ----------
  Future _signIn() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showSnack('Veuillez remplir tous les champs.'.tr());
      return;
    }
    try {
      if (_remember) await _savePrefs();
      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await _upsertUserDoc(cred.user!, name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim());
      await _postLogin(cred.user!);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message?.tr() ?? e.code);
    }
  }

  Future _signUp() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty || _nameCtrl.text.isEmpty) {
      _showSnack('Veuillez remplir tous les champs.'.tr());
      return;
    }
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await cred.user!.updateDisplayName(_nameCtrl.text.trim());
      await _upsertUserDoc(cred.user!, name: _nameCtrl.text.trim());
      _showSnack('Inscription réussie, connectez-vous'.tr());
      setState(() => _loginMode = true);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message?.tr() ?? e.code);
    }
  }

  // ---------- AUTH GOOGLE ----------
  Future _googleLogin() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final res = await _auth.signInWithPopup(provider);
        final user = res.user;
        if (user == null) throw 'Google Web Sign-In: no user';
        await _upsertUserDoc(user);
        await _postLogin(user);
      } else {
        final gUser = await _google.signIn();
        if (gUser == null) return;
        final gAuth = await gUser.authentication;
        final cred = GoogleAuthProvider.credential(
          idToken: gAuth.idToken,
          accessToken: gAuth.accessToken,
        );
        final res = await _auth.signInWithCredential(cred);
        await _upsertUserDoc(res.user!);
        await _postLogin(res.user!);
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      _showSnack('Erreur Google Sign-In'.tr());
    }
  }

  // ---------- AUTH APPLE (iOS only) ----------
  Future _appleLogin() async {
    if (!Platform.isIOS) {
      _showSnack('Apple Sign-In disponible sur iOS uniquement.'.tr());
      return;
    }
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );

      final oauth = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: rawNonce,
      );

      final res = await _auth.signInWithCredential(oauth);
      final user = res.user!;
      // Récupérer le nom la 1ère fois (Apple ne le renvoie qu’une fois)
      final fullName = (apple.givenName != null || apple.familyName != null)
          ? '${apple.givenName ?? ''} ${apple.familyName ?? ''}'.trim()
          : user.displayName;

      if (fullName != null && fullName.isNotEmpty) {
        await user.updateDisplayName(fullName);
      }
      await _upsertUserDoc(user, name: fullName, email: user.email ?? apple.email);
      await _postLogin(user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return; // utilisateur a annulé
      debugPrint('Apple Sign-In auth error: $e');
      _showSnack('Erreur Apple Sign-In'.tr());
    } catch (e) {
      debugPrint('Apple Sign-In error: $e');
      _showSnack('Erreur Apple Sign-In'.tr());
    }
  }

  // ---------- INVITÉ / ANON ----------
  Future _guestLogin() async {
    try {
      final cred = await _auth.signInAnonymously();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'isGuest'   : true,
        'createdAt' : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _postLogin(cred.user!);
    } catch (e) {
      debugPrint('Guest login error: $e');
      _showSnack('Impossible de continuer en invité'.tr());
    }
  }

  // ---------- HELPERS ----------
  Future _upsertUserDoc(User user, {String? name, String? email}) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email'     : email ?? user.email,
      'name'      : name ?? user.displayName,
      'provider'  : user.providerData.isNotEmpty ? user.providerData.first.providerId : 'password',
      'updatedAt' : FieldValue.serverTimestamp(),
      'createdAt' : FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future _postLogin(User user) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, HomePage.routeName);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Nonce utils for Apple/Firebase
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Widget _langBtn(String code, String asset) {
    return InkWell(
      onTap: () => context.setLocale(Locale(code)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Image.asset(asset, width: 24.w, height: 24.h),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Provider.of<ThemeProvider>(context).currentTheme;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/backgroundlogin.jpg', fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(color: Colors.white.withOpacity(0.1)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: theme.cardColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoWidget(),
                    SizedBox(height: 12.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _langBtn('fr','assets/images/france.png'),
                        _langBtn('en','assets/images/united-kingdom.png'),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      _loginMode ? 'Connexion'.tr() : 'Créer un compte'.tr(),
                      style: theme.textTheme.headlineMedium,
                    ),
                    SizedBox(height: 20.h),

                    if (!_loginMode)
                      TextField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          label: Text('Nom'.tr()),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        label: Text('Email'.tr()),
                        prefixIcon: const Icon(Icons.email),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscured,
                      decoration: InputDecoration(
                        label: Text('Mot de passe'.tr()),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscured = !_obscured),
                        ),
                      ),
                      onSubmitted: (_) => _loginMode ? _signIn() : _signUp(),
                    ),

                    Row(
                      children: [
                        Checkbox(
                          value: _remember,
                          activeColor: primary,
                          onChanged: (v) => setState(() => _remember = v ?? false),
                        ),
                        Text('Se souvenir de moi'.tr()),
                        const Spacer(),
                        // (optionnel) Mot de passe oublié
                      ],
                    ),

                    SizedBox(height: 8.h),
                    ElevatedButton.icon(
                      icon: Icon(_loginMode ? Icons.login : Icons.person_add),
                      label: Text(_loginMode ? 'Se connecter'.tr() : "S'inscrire".tr()),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48.h),
                        backgroundColor: primary,
                      ),
                      onPressed: _loginMode ? _signIn : _signUp,
                    ),

                    TextButton(
                      onPressed: () => setState(() => _loginMode = !_loginMode),
                      child: Text(_loginMode ? 'Créer un compte'.tr() : 'Déjà un compte ?'.tr()),
                    ),

                    Divider(color: primary, height: 32.h),

                    // Apple (iOS uniquement)
                    if (Platform.isIOS) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.apple, size: 22),
                        label: Text('Se connecter avec Apple'.tr()),
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 48.h),
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _appleLogin,
                      ),
                      SizedBox(height: 12.h),
                    ],

                    // Google
                    ElevatedButton.icon(
                      icon: SvgPicture.asset('assets/icons/Google.svg', width: 24.w, height: 24.h),
                      label: Text('Continuer avec Google'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primary,
                        minimumSize: Size(double.infinity, 48.h),
                        side: BorderSide(color: theme.dividerColor),
                      ),
                      onPressed: _googleLogin,
                    ),

                    SizedBox(height: 12.h),

                    // Invité
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_outline),
                      label: Text('Continuer en invité'.tr()),
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48.h),
                      ),
                      onPressed: _guestLogin,
                    ),

                    SizedBox(height: 16.h),
                    Text('© 2025 Prospecto', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
