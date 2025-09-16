import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';           // kAppId
import '../services/org_service.dart';
import 'home_page.dart';

class OrgJoinScreen extends StatefulWidget {
  static const routeName = '/org_join';
  const OrgJoinScreen({Key? key}) : super(key: key);

  @override
  State<OrgJoinScreen> createState() => _OrgJoinScreenState();
}

class _OrgJoinScreenState extends State<OrgJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) _emailCtrl.text = user!.email!;
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final code = _codeCtrl.text.trim().toUpperCase();
      final email = _emailCtrl.text.trim();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Vous devez être connecté.';

      final res = await OrgService(kAppId).acceptInvite(
        code: code,
        uid: user.uid,
        email: email,
      );

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'orgId': res['orgId'],
        'orgName': res['orgName'],
        'role': res['role'],
        'currentOrgId': res['orgId'],
        'currentOrgName': res['orgName'],
        'currentRole': res['role'],
        'orgIds': FieldValue.arrayUnion([res['orgId']]),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(HomePage.routeName, (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenue dans ${res['orgName']} !')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rejoindre une entreprise'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Entrez le code reçu par votre entreprise :',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Code d’activation',
                      hintText: 'ex : 7Q2M6C',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().length < 6)
                        ? 'Saisissez un code valide'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Votre e-mail',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) =>
                    (v == null || !v.contains('@')) ? 'E-mail invalide' : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _join,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Rejoindre'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                      showModalBottomSheet(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (_) => const _ResendHelpSheet(),
                      );
                    },
                    icon: const Icon(Icons.help_outline_rounded),
                    label: const Text('Je n’ai pas reçu de code'),
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

class _ResendHelpSheet extends StatefulWidget {
  const _ResendHelpSheet({Key? key}) : super(key: key);

  @override
  State<_ResendHelpSheet> createState() => _ResendHelpSheetState();
}

class _ResendHelpSheetState extends State<_ResendHelpSheet> {
  final _codeCtrl = TextEditingController();
  bool _sending = false;

  Future<void> _resend() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _sending = true);
    try {
      final u = FirebaseAuth.instance.currentUser;
      await OrgService(kAppId).requestResend(
        code: code,
        requesterUid: u?.uid,
        requesterEmail: u?.email, // ✅ maintenant reconnu par OrgService
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande envoyée. Vérifiez vos spams.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
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
          Text('Pas reçu le code ?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('1) Regardez dans “Courrier indésirable”. 2) Entrez le code pour demander un renvoi.'),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Code d’activation'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _resend,
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Demander un renvoi'),
          ),
        ],
      ),
    );
  }
}
