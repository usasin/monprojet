// lib/pages/login_screen.dart

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:easy_localization/easy_localization.dart';

import '../logo_widget.dart';
import '../providers/theme_provider.dart';
import 'home_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  static const routeName = '/login';
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();

  bool _obscured   = true;
  bool _remember   = false;
  bool _loginMode  = true;

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
      _remember   = p.getBool('rememberMe') ?? false;
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

  Future _signIn() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showSnack('Veuillez remplir tous les champs.'.tr());
      return;
    }
    try {
      if (_remember) await _savePrefs();
      final cred = await _auth.signInWithEmailAndPassword(
          email: _emailCtrl.text, password: _passCtrl.text
      );
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
          email: _emailCtrl.text, password: _passCtrl.text
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
        'email'     : cred.user!.email,
        'name'      : _nameCtrl.text,
        'createdAt' : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSnack('Inscription réussie, connectez-vous'.tr());
      setState(() => _loginMode = true);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message?.tr() ?? e.code);
    }
  }

  Future _postLogin(User user) async {
    // enreg. token FCM, metadata user...
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
    Navigator.pushReplacementNamed(context, HomePage.routeName);
  }

  // GOOGLE LOGIN MULTIPLATEFORME
  Future _googleLogin() async {
    try {
      if (kIsWeb) {
        // --- WEB ---
        GoogleAuthProvider authProvider = GoogleAuthProvider();

        final userCredential = await FirebaseAuth.instance.signInWithPopup(authProvider);
        final user = userCredential.user;
        if (user == null) throw 'Erreur Google Web Sign-In (no user)';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'email' : user.email,
          'name'  : user.displayName,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _postLogin(user);

      } else {
        // --- ANDROID / IOS ---
        final gUser = await _google.signIn();
        if (gUser == null) return;
        final gAuth = await gUser.authentication;
        final cred = GoogleAuthProvider.credential(
            idToken: gAuth.idToken, accessToken: gAuth.accessToken
        );
        final result = await _auth.signInWithCredential(cred);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(result.user!.uid)
            .set({
          'email' : result.user!.email,
          'name'  : result.user!.displayName,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _postLogin(result.user!);
      }
    } catch (e) {
      print(e);
      _showSnack('Erreur Google Sign-In'.tr());
    }
  }


  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
    final theme    = Provider.of<ThemeProvider>(context).currentTheme;
    final primary  = theme.colorScheme.primary;
    return Scaffold(
      // plus d’AppBar
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
              'assets/images/backgroundlogin.jpg',
              fit: BoxFit.cover
          ),
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
                    LogoWidget(),
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
                      _loginMode
                          ? 'Connexion'.tr()
                          : 'Créer un compte'.tr(),
                      style: theme.textTheme.headlineMedium,
                    ),
                    SizedBox(height: 20.h),
                    if (!_loginMode)
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          label: Text('Nom'.tr()),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    TextField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        label: Text('Email'.tr()),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscured,
                      decoration: InputDecoration(
                        label: Text('Mot de passe'.tr()),
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscured
                                  ? Icons.visibility
                                  : Icons.visibility_off
                          ),
                          onPressed: () => setState(() => _obscured = !_obscured),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _remember,
                          activeColor: primary,
                          onChanged: (v) => setState(() => _remember = v!),
                        ),
                        Text('Se souvenir de moi'.tr())
                      ],
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton.icon(
                      icon: Icon(_loginMode
                          ? Icons.login
                          : Icons.person_add),
                      label: Text(_loginMode
                          ? 'Se connecter'.tr()
                          : "S'inscrire".tr()
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48.h),
                        backgroundColor: primary,
                      ),
                      onPressed: _loginMode ? _signIn : _signUp,
                    ),
                    TextButton(
                      onPressed: () => setState(() => _loginMode = !_loginMode),
                      child: Text(
                          _loginMode
                              ? 'Créer un compte'.tr()
                              : 'Déjà un compte ?'.tr()
                      ),
                    ),
                    Divider(color: primary, height: 32.h),
                    ElevatedButton.icon(
                      icon: SvgPicture.asset(
                          'assets/icons/Google.svg',
                          width: 24.w, height: 24.h
                      ),
                      label: Text('Google'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primary,
                        minimumSize: Size(double.infinity, 48.h),
                      ),
                      onPressed: _googleLogin, // <-- ta nouvelle fonction !
                    ),

                    SizedBox(height: 12.h),
                    Text(
                      '© 2025 Prospecto',
                      style: theme.textTheme.bodySmall,
                    ),
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
