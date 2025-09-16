import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../config.dart' as cfg;           // << alias cfg
import '../services/org_service.dart';
import '../providers/org_provider.dart';

class OrgMembersScreen extends StatelessWidget {
  static const routeName = '/org_members';
  const OrgMembersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final orgProv = context.watch<OrgProvider>();
    final orgId = orgProv.orgId;
    final orgName = orgProv.orgName ?? 'Mon organisation';

    if (orgId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Membres de l’organisation'),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        body: const Center(
          child: Text('Aucune organisation liée à votre compte.'),
        ),
      );
    }

    final svc = OrgService(cfg.kAppId);  // << utilise l’alias

    Future<void> createInvite() async {
      final res = await showDialog<String?>(
        context: context,
        builder: (ctx) {
          final emailCtrl = TextEditingController();
          String role = 'REP';
          return AlertDialog(
            title: const Text('Inviter un salarié'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'E-mail (optionnel)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  onChanged: (v) => role = v ?? 'REP',
                  items: const [
                    DropdownMenuItem(value: 'REP', child: Text('Commercial (REP)')),
                    DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                  ],
                  decoration: const InputDecoration(labelText: 'Rôle'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, '${emailCtrl.text}||$role'),
                child: const Text('Créer'),
              ),
            ],
          );
        },
      );
      if (res == null) return;

      final parts = res.split('||');
      final email = parts.first.trim().isEmpty ? null : parts.first.trim();
      final role = parts.length > 1 ? parts[1] : 'REP';

      final code = await svc.createInvite(orgId: orgId, email: email, role: role);
      final deepLink = 'prospecto://join?code=$code';

      // ignore: use_build_context_synchronously
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Invitation créée'),
          content: SelectableText('Code : $code\nLien : $deepLink'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation créée.')),
      );
    }

    Future<void> resend(String code) async {
      await svc.requestResend(code: code);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande de renvoi envoyée.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Membres — $orgName'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createInvite,
        icon: const Icon(Icons.key_rounded),
        label: const Text('Inviter'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Membres
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Membres', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: svc.members(orgId),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: LinearProgressIndicator(minHeight: 2),
                        );
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Aucun membre'),
                        );
                      }
                      return Column(
                        children: [
                          for (final d in docs) ...[
                            ListTile(
                              leading: const Icon(Icons.person_rounded),
                              title: Text(d['email'] ?? d['uid'] ?? ''),
                              subtitle: Text(d['role'] ?? 'REP'),
                              trailing: IconButton(
                                tooltip: 'Retirer',
                                onPressed: () => svc.removeMember(orgId, d['uid'] ?? ''),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ),
                            const Divider(height: 0),
                          ]
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Invitations actives
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Invitations', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      OutlinedButton.icon(
                        onPressed: createInvite,
                        icon: const Icon(Icons.add),
                        label: const Text('Nouvelle'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: svc.invites(orgId),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: LinearProgressIndicator(minHeight: 2),
                        );
                      }
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Aucune invitation en attente.'),
                        );
                      }
                      return Column(
                        children: [
                          for (final d in docs) ...[
                            ListTile(
                              leading: const Icon(Icons.vpn_key_rounded),
                              title: Text('Code : ${d.id} — ${d['role'] ?? 'REP'}'),
                              subtitle: Text((d['email'] ?? '(non liée)') + ' • créée'),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    tooltip: 'Copier le code',
                                    onPressed: () => Clipboard.setData(ClipboardData(text: d.id)),
                                    icon: const Icon(Icons.copy_rounded),
                                  ),
                                  IconButton(
                                    tooltip: 'Renvoyer',
                                    onPressed: () => resend(d.id),
                                    icon: const Icon(Icons.mail_outline_rounded),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 0),
                          ]
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
