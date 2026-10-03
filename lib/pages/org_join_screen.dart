import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/org_provider.dart';
import '../services/org_service.dart';
import '../services/account_session_service.dart';
import '../widgets/user_identity_card.dart';
import 'home_page.dart';

class OrgJoinScreen extends StatefulWidget {
  static const routeName = '/org_join';
  const OrgJoinScreen({super.key});
  @override
  State<OrgJoinScreen> createState() => _OrgJoinScreenState();
}

class _OrgJoinScreenState extends State<OrgJoinScreen> {
  final _code = TextEditingController();
  Map<String, dynamic>? _invitation;
  String? _error;
  bool _busy = false;
  final _service = OrgService(kAppId);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _preview() async {
    if (_busy || _code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _invitation = null;
    });
    try {
      final data = await _service.previewInvite(_code.text);
      if (mounted) setState(() => _invitation = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeAccount() async {
    await AccountSessionService.signOut(forceAccountPicker: true);
    if (!mounted) return;
    context.read<OrgProvider>().clear();
    setState(() {});
  }

  Future<void> _activate() async {
    if (_busy || _invitation == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        user = await showModalBottomSheet<User>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) =>
              _InvitationAuth(email: _invitation!['email'].toString()),
        );
      }
      if (user == null || !mounted) return;
      final expected = _invitation!['email'].toString().toLowerCase();
      if (user.email?.trim().toLowerCase() != expected) {
        throw 'Cette invitation est réservée à $expected';
      }
      await user.reload();
      user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Reconnectez-vous pour continuer.';
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        throw 'Un e-mail de vérification vous a été envoyé. Cliquez sur son lien, puis appuyez de nouveau sur « Activer mon accès ».';
      }
      await user.getIdToken(true);
      await _service.acceptInvite(code: _code.text.trim().toUpperCase());
      if (!mounted) return;
      await context.read<OrgProvider>().loadFromUser(
        user.uid,
        preferTeam: true,
      );
      if (mounted)
        Navigator.pushNamedAndRemoveUntil(
          context,
          HomePage.routeName,
          (_) => false,
        );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final invitation = _invitation;
    return Scaffold(
      appBar: AppBar(title: const Text('J’ai un code d’invitation')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ce code sert uniquement à activer votre premier accès. Ensuite, votre compte suffit.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Code d’invitation',
                      prefixIcon: Icon(Icons.key),
                    ),
                    onChanged: (_) => setState(() {
                      _invitation = null;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _busy ? null : _preview,
                    child: const Text('Vérifier le code'),
                  ),
                  if (invitation != null) ...[
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${invitation['orgName']}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Invitation pour : ${invitation['firstName']} ${invitation['lastName']}',
                            ),
                            Text('${invitation['email']}'),
                            Text(
                              invitation['role'] == 'MANAGER'
                                  ? 'Responsable commercial'
                                  : 'Commercial',
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (user != null && !user.isAnonymous)
                      UserIdentityCard(
                        compact: true,
                        onChangeAccount: _busy ? null : _changeAccount,
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _activate,
                      child: const Text('Activer mon accès'),
                    ),
                  ],
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InvitationAuth extends StatefulWidget {
  const _InvitationAuth({required this.email});
  final String email;
  @override
  State<_InvitationAuth> createState() => _InvitationAuthState();
}

class _InvitationAuthState extends State<_InvitationAuth> {
  final _password = TextEditingController();
  bool _create = false;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({bool google = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      UserCredential result;
      if (google) {
        if (kIsWeb) {
          result = await auth.signInWithPopup(
            GoogleAuthProvider()
              ..setCustomParameters({'prompt': 'select_account'}),
          );
        } else {
          final signIn = GoogleSignIn();
          await signIn.signOut();
          final account = await signIn.signIn();
          if (account == null) return;
          final tokens = await account.authentication;
          result = await auth.signInWithCredential(
            GoogleAuthProvider.credential(
              accessToken: tokens.accessToken,
              idToken: tokens.idToken,
            ),
          );
        }
      } else if (_create) {
        result = await auth.createUserWithEmailAndPassword(
          email: widget.email,
          password: _password.text,
        );
      } else {
        result = await auth.signInWithEmailAndPassword(
          email: widget.email,
          password: _password.text,
        );
      }
      if (mounted) Navigator.pop(context, result.user);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _create ? 'Créer mon compte' : 'Connexion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(widget.email),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_create ? 'Créer mon compte' : 'Se connecter'),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _submit(google: true),
              child: const Text('Continuer avec Google'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _create = !_create),
              child: Text(
                _create
                    ? 'J’ai déjà un compte'
                    : 'Créer un compte avec cette adresse',
              ),
            ),
            if (_busy) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    ),
  );
}
