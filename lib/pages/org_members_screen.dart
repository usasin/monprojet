import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../providers/org_provider.dart';
import '../services/org_service.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';
import '../widgets/company_avatar.dart';
import 'home_page.dart';
import 'org_activity_screen.dart';
import 'org_profile_screen.dart';
import 'preparing_space_screen.dart';

class OrgMembersScreen extends StatefulWidget {
  static const routeName = '/org_members';
  const OrgMembersScreen({super.key});

  @override
  State<OrgMembersScreen> createState() => _OrgMembersScreenState();
}

class _OrgMembersScreenState extends State<OrgMembersScreen> {
  bool _busy = false;
  OrgService get _service => OrgService(kAppId);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LText(message.replaceFirst('Bad state: ', '')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createInvite(String orgId, String orgName) async {
    final org = context.read<OrgProvider>();
    if (!org.canManageTeam || _busy) return;
    final emailCtrl = TextEditingController();
    var role = 'REP';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const LText('Inviter un membre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail (facultatif)'.tr(),
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  helperText: 'Renseignez-le pour réserver le code à cette personne.'.tr(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: InputDecoration(
                  labelText: 'Rôle'.tr(),
                  prefixIcon: const Icon(Icons.badge_rounded),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'REP',
                    child: LText('Commercial'),
                  ),
                  if (org.isOwner)
                    const DropdownMenuItem(
                      value: 'MANAGER',
                      child: LText('Responsable commercial'),
                    ),
                ],
                onChanged: (value) =>
                    setDialogState(() => role = value ?? 'REP'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const LText('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'email': emailCtrl.text.trim(),
                'role': role,
              }),
              child: const LText('Créer le code'),
            ),
          ],
        ),
      ),
    );
    emailCtrl.dispose();
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final code = await _service.createInvite(
        orgId: orgId,
        role: result['role'] ?? 'REP',
        email: result['email'],
      );
      if (!mounted) return;
      await _showInviteResult(
        code: code,
        orgName: orgName,
        role: result['role'] ?? 'REP',
      );
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showInviteResult({
    required String code,
    required String orgName,
    required String role,
  }) async {
    final message = _inviteMessage(code, orgName, role);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const LText('Code d’invitation créé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LText(
              'Transmettez ce code au salarié. Il restera valide pendant 7 jours.',
            ),
            const SizedBox(height: 14),
            SelectableText(
              code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: ProspectoColors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _snack('Code copié.');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const LText('Copier'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Share.share(message, subject: 'Invitation Prospecto');
            },
            icon: const Icon(Icons.share_rounded),
            label: const LText('Partager'),
          ),
        ],
      ),
    );
  }

  String _inviteMessage(String code, String orgName, String role) {
    return 'Vous êtes invité(e) à rejoindre $orgName sur Prospecto en tant que '
        '${_roleLabel(role)}.\n\nCode d’invitation : $code\n\n'
        'Dans Prospecto, choisissez Entreprise puis Rejoindre une entreprise.';
  }

  Future<void> _changeRole({
    required String orgId,
    required String memberUid,
    required String currentRole,
  }) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LText(
                'Modifier le rôle',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              RadioListTile<String>(
                value: 'REP',
                groupValue: currentRole.toUpperCase(),
                title: const LText('Commercial'),
                subtitle: const LText('Prospects partagés et tournées personnelles'),
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
              RadioListTile<String>(
                value: 'MANAGER',
                groupValue: currentRole.toUpperCase(),
                title: const LText('Responsable commercial'),
                subtitle: const LText('Pilote les commerciaux, tournées, calendriers et résultats'),
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
            ],
          ),
        ),
      ),
    );
    if (role == null || role == currentRole.toUpperCase()) return;
    try {
      await _service.updateMemberRole(
        orgId: orgId,
        memberUid: memberUid,
        role: role,
      );
      _snack('Rôle mis à jour.');
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _removeMember({
    required String orgId,
    required String uid,
    required String email,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('Retirer ce membre ?'),
        content: LText(
          '$email ne pourra plus accéder aux données de l’entreprise. Les prospects créés resteront dans l’entreprise.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LText('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const LText('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.removeMember(orgId, uid);
      _snack('Membre retiré de l’entreprise.');
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _transferOwnership({
    required String orgId,
    required String uid,
    required String email,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('Transférer la propriété ?'),
        content: LText(
          '$email deviendra administrateur principal. Vous deviendrez administrateur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LText('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const LText('Transférer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.transferOwnership(orgId: orgId, memberUid: uid);
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null && mounted) {
        await context.read<OrgProvider>().refresh(currentUid);
      }
      _snack('Propriété transférée.');
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _revokeInvite(String orgId, String code) async {
    try {
      await _service.revokeInvite(orgId, code);
      _snack('Invitation révoquée.');
    } catch (error) {
      _snack(error.toString());
    }
  }

  Future<void> _leave(String orgId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LText('Quitter l’entreprise ?'),
        content: const LText(
          'Vous perdrez l’accès à l’espace partagé. Vos données personnelles resteront disponibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const LText('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const LText('Quitter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await PreparingSpaceScreen.open(
      context,
      action: () async {
        await _service.leaveOrganization(orgId);
        await context.read<OrgProvider>().loadFromUser(user.uid);
      },
      successRoute: HomePage.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    final orgId = org.orgId;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (orgId == null || !org.isTeam) {
      return BrandBackground(
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: const Center(child: LText('Aucun espace entreprise actif.')),
        ),
      );
    }

    return BrandBackground(
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.white.withOpacity(isDark ? .05 : .26)),
            ),
          ),
          title: const LText(
            'Mon entreprise',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        floatingActionButton: org.canManageTeam
            ? FloatingActionButton.extended(
                onPressed: _busy
                    ? null
                    : () => _createInvite(orgId, org.orgName ?? 'Entreprise'),
                backgroundColor: ProspectoColors.green,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add_rounded),
                label: const LText('Inviter'),
              )
            : null,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _CompanyHeader(org: org),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        OrgProfileScreen.routeName,
                      ),
                      icon: const Icon(Icons.business_rounded),
                      label: const LText('Identité'),
                    ),
                  ),
                  if (org.canManageTeam) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          OrgActivityScreen.routeName,
                        ),
                        icon: const Icon(Icons.history_rounded),
                        label: const LText('Activité'),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              const _SectionTitle('Membres de l’équipe'),
              const SizedBox(height: 8),
              _SurfaceCard(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _service.members(orgId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: LText('Chargement impossible : ${snapshot.error}'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    return Column(
                      children: [
                        for (var index = 0; index < docs.length; index++) ...[
                          _MemberTile(
                            data: docs[index].data(),
                            uid: docs[index].id,
                            currentUid: currentUid,
                            currentUserIsOwner: org.isOwner,
                            canManage: org.canManageTeam,
                            onChangeRole: () => _changeRole(
                              orgId: orgId,
                              memberUid: docs[index].id,
                              currentRole:
                                  (docs[index].data()['role'] ?? 'REP').toString(),
                            ),
                            onRemove: () => _removeMember(
                              orgId: orgId,
                              uid: docs[index].id,
                              email: (docs[index].data()['email'] ?? 'Ce membre')
                                  .toString(),
                            ),
                            onTransfer: () => _transferOwnership(
                              orgId: orgId,
                              uid: docs[index].id,
                              email: (docs[index].data()['email'] ?? 'Ce membre')
                                  .toString(),
                            ),
                          ),
                          if (index != docs.length - 1) const Divider(height: 1),
                        ],
                      ],
                    );
                  },
                ),
              ),
              if (org.canManageTeam) ...[
                const SizedBox(height: 18),
                const _SectionTitle('Invitations en attente'),
                const SizedBox(height: 8),
                _SurfaceCard(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _service.invites(orgId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: LText('Chargement impossible : ${snapshot.error}'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(18),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(14),
                          child: LText('Aucune invitation en attente.'),
                        );
                      }
                      return Column(
                        children: [
                          for (var index = 0; index < docs.length; index++) ...[
                            _InviteTile(
                              code: docs[index].id,
                              data: docs[index].data(),
                              onCopy: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: docs[index].id),
                                );
                                _snack('Code copié.');
                              },
                              onShare: () => Share.share(
                                _inviteMessage(
                                  docs[index].id,
                                  org.orgName ?? 'Entreprise',
                                  (docs[index].data()['role'] ?? 'REP').toString(),
                                ),
                                subject: 'Invitation Prospecto',
                              ),
                              onRevoke: () => _revokeInvite(orgId, docs[index].id),
                            ),
                            if (index != docs.length - 1) const Divider(height: 1),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
              if (!org.isOwner) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _leave(orgId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const LText('Quitter cette entreprise'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Administrateur principal';
      case 'MANAGER':
        return 'Responsable commercial';
      default:
        return 'Commercial';
    }
  }
}

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({required this.org});
  final OrgProvider org;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        children: [
          CompanyAvatar(
            initials: org.initials,
            logoUrl: org.logoUrl,
            size: 68,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: ProspectoColors.green.withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const LText(
                    'ENTREPRISE',
                    style: TextStyle(
                      color: ProspectoColors.green,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                LText(
                  org.orgName ?? 'Entreprise',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                if (org.slogan?.trim().isNotEmpty == true)
                  LText(
                    org.slogan!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ProspectoColors.textSecondary),
                  ),
                const SizedBox(height: 4),
                LText(
                  org.roleLabel,
                  style: const TextStyle(
                    color: ProspectoColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (org.plan?.trim().isNotEmpty == true || org.maxSeats != null)
                  LText(
                    [
                      if (org.plan?.trim().isNotEmpty == true)
                        'Forfait ${org.plan!.toUpperCase()}',
                      if (org.maxSeats != null) '${org.maxSeats} places maximum',
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ProspectoColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.data,
    required this.uid,
    required this.currentUid,
    required this.currentUserIsOwner,
    required this.canManage,
    required this.onChangeRole,
    required this.onRemove,
    required this.onTransfer,
  });

  final Map<String, dynamic> data;
  final String uid;
  final String? currentUid;
  final bool currentUserIsOwner;
  final bool canManage;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final role = (data['role'] ?? 'REP').toString().toUpperCase();
    final email = (data['email'] ?? 'Membre').toString();
    final self = uid == currentUid;
    final isOwner = role == 'OWNER';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: CircleAvatar(
        backgroundColor: ProspectoColors.green.withOpacity(.14),
        foregroundColor: ProspectoColors.green,
        child: Icon(isOwner ? Icons.workspace_premium_rounded : Icons.person_rounded),
      ),
      title: LText(
        self ? '$email (vous)' : email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: LText(_label(role)),
      trailing: canManage && !self && !isOwner
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'role') onChangeRole();
                if (value == 'remove') onRemove();
                if (value == 'transfer') onTransfer();
              },
              itemBuilder: (_) => [
                if (currentUserIsOwner)
                  const PopupMenuItem(
                    value: 'role',
                    child: LText('Modifier le rôle'),
                  ),
                if (currentUserIsOwner)
                  const PopupMenuItem(
                    value: 'transfer',
                    child: LText('Nommer administrateur principal'),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: LText('Retirer de l’entreprise'),
                ),
              ],
            )
          : null,
    );
  }

  static String _label(String role) {
    switch (role) {
      case 'OWNER':
        return 'Administrateur principal';
      case 'MANAGER':
        return 'Responsable commercial';
      default:
        return 'Commercial';
    }
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.code,
    required this.data,
    required this.onCopy,
    required this.onShare,
    required this.onRevoke,
  });

  final String code;
  final Map<String, dynamic> data;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final expires = data['expiresAt'];
    final expiry = expires is Timestamp ? expires.toDate().toLocal() : null;
    final roleLabel = _MemberTile._label(
      (data['role'] ?? 'REP').toString().toUpperCase(),
    );
    final email = data['email']?.toString().trim() ?? '';
    final details = <String>[
      roleLabel,
      if (email.isNotEmpty) email,
      if (expiry != null)
        'expire le ${expiry.day.toString().padLeft(2, '0')}/'
            '${expiry.month.toString().padLeft(2, '0')}',
    ].join(' • ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: CircleAvatar(
        backgroundColor: ProspectoColors.peach.withOpacity(.17),
        foregroundColor: ProspectoColors.peach,
        child: const Icon(Icons.vpn_key_rounded),
      ),
      title: LText(
        code,
        style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
      subtitle: LText(
        details,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'copy') onCopy();
          if (value == 'share') onShare();
          if (value == 'revoke') onRevoke();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'copy', child: LText('Copier le code')),
          PopupMenuItem(value: 'share', child: LText('Partager')),
          PopupMenuItem(value: 'revoke', child: LText('Révoquer')),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.78),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: Colors.white.withOpacity(.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return LText(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: ProspectoColors.textPrimary,
      ),
    );
  }
}
