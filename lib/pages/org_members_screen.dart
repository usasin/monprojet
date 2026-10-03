import '../sales/enterprise_actions.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../sales/sales_insights.dart' show memberDisplay;
import '../widgets/invite_member_dialog.dart';

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
import 'preparing_space_screen.dart';

class OrgMembersScreen extends StatefulWidget {
  static const routeName = '/org_members';
  const OrgMembersScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<OrgMembersScreen> createState() => _OrgMembersScreenState();
}

class _OrgMembersScreenState extends State<OrgMembersScreen> {
  bool _busy = false;
  String _memberQuery = '', _memberFilter = 'all';
  int _visibleMembers = 50;
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

  Widget _memberDirectory(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    OrgProvider org,
    String orgId,
    String? currentUid,
  ) {
    Widget tile(QueryDocumentSnapshot<Map<String, dynamic>> d) => _MemberTile(
      data: d.data(),
      uid: d.id,
      currentUid: currentUid,
      currentUserIsOwner: org.isOwner,
      canManage: org.isOwner && !_busy,
      onChangeRole: () => _changeRole(
        orgId: orgId,
        memberUid: d.id,
        currentRole: '${d.data()['role'] ?? 'REP'}',
      ),
      onRemove: () => _removeMember(
        orgId: orgId,
        uid: d.id,
        email: '${d.data()['email'] ?? 'Membre'}',
      ),
      onManageTeam: () => _manageTeam(orgId, d.id),
      onAssignManager: () => _assignManager(orgId, d.id),
      onTransfer: () => _transferOwnership(
        orgId: orgId,
        uid: d.id,
        email: '${d.data()['email'] ?? 'Membre'}',
      ),
    );
    final search = docs
        .where(
          (d) => '${memberDisplay(d.data())} ${d.data()['email'] ?? ''}'
              .toLowerCase()
              .contains(_memberQuery),
        )
        .toList();
    final filtered = search
        .where(
          (d) => _memberFilter == 'all' || d.data()['role'] == _memberFilter,
        )
        .toList();
    final shown = filtered.take(_visibleMembers).toList();
    final managers = docs.where((d) => d.data()['role'] == 'MANAGER').toList();
    final managerIds = managers.map((d) => d.id).toSet();
    final children = <Widget>[
      TextField(
        decoration: const InputDecoration(
          labelText: 'Nom, e-mail',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() {
          _memberQuery = v.trim().toLowerCase();
          _visibleMembers = 50;
        }),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              {
                    'all': 'Tous',
                    'OWNER': 'Administration',
                    'MANAGER': 'Responsables',
                    'REP': 'Commerciaux',
                  }.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          '${e.value} (${e.key == 'all' ? docs.length : docs.where((d) => d.data()['role'] == e.key).length})',
                        ),
                        selected: _memberFilter == e.key,
                        onSelected: (_) => setState(() {
                          _memberFilter = e.key;
                          _visibleMembers = 50;
                        }),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ),
      if (shown.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: LText('Aucun membre correspondant.'),
        ),
    ];
    if (_memberFilter != 'all' || _memberQuery.isNotEmpty) {
      children.addAll(shown.map(tile));
    } else {
      children.addAll(
        shown.where((d) => d.data()['role'] == 'OWNER').map(tile),
      );
      for (final manager in managers) {
        final team = shown
            .where(
              (d) =>
                  d.data()['role'] == 'REP' &&
                  d.data()['managerUid'] == manager.id,
            )
            .toList();
        if (!shown.any((d) => d.id == manager.id) && team.isEmpty) continue;
        final total = docs
            .where(
              (d) =>
                  d.data()['role'] == 'REP' &&
                  d.data()['managerUid'] == manager.id,
            )
            .length;
        children.add(
          ExpansionTile(
            key: PageStorageKey('team:${manager.id}'),
            title: Text(
              '${memberDisplay(manager.data())} · $total commerciaux',
            ),
            children: [tile(manager), ...team.map(tile)],
          ),
        );
      }
      final unassigned = shown
          .where(
            (d) =>
                d.data()['role'] == 'REP' &&
                !managerIds.contains(d.data()['managerUid']),
          )
          .toList();
      if (unassigned.isNotEmpty)
        children.add(
          ExpansionTile(
            title: Text(
              'Sans responsable · ${docs.where((d) => d.data()['role'] == 'REP' && !managerIds.contains(d.data()['managerUid'])).length}',
            ),
            children: unassigned.map(tile).toList(),
          ),
        );
    }
    if (filtered.length > shown.length)
      children.add(
        TextButton(
          onPressed: () => setState(() => _visibleMembers += 50),
          child: Text(
            'Voir 50 membres supplémentaires (${shown.length}/${filtered.length})',
          ),
        ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Future<void> _createInvite(String orgId, String orgName) async {
    final org = context.read<OrgProvider>();
    if (!org.isOwner || _busy) return;
    Map<String, String> managers;
    try {
      final snap = await _service.orgRef(orgId).collection('members').get();
      managers = {
        for (final doc in snap.docs)
          if (doc.data()['role'] == 'MANAGER' &&
              doc.data()['status'] == 'active')
            doc.id:
                (doc.data()['displayName'] ??
                        doc.data()['email'] ??
                        'Responsable')
                    .toString(),
      };
    } catch (error) {
      _snack(error.toString());
      return;
    }
    if (!mounted) return;
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => InviteMemberDialog(managers: managers),
    );
    if (result == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final code = await _service.createInvite(
        orgId: orgId,
        role: result['role'] ?? 'REP',
        email: result['email']!,
        firstName: result['firstName']!,
        lastName: result['lastName']!,
        managerUid: result['managerUid'],
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
        scrollable: true,
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
                fontSize: 18,
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

  Future<void> _manageTeam(String orgId, String managerUid) async {
    try {
      final snap = await _service.orgRef(orgId).collection('members').get();
      if (!mounted) return;
      final reps = snap.docs
          .where(
            (d) => d.data()['role'] == 'REP' && d.data()['status'] == 'active',
          )
          .toList();
      final selected = reps
          .where((d) => d.data()['managerUid'] == managerUid)
          .map((d) => d.id)
          .toSet();
      var query = '';
      final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: const LText('Gérer son équipe'),
            content: SizedBox(
              width: 440,
              height: MediaQuery.sizeOf(ctx).height * .5,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Rechercher un commercial',
                    ),
                    onChanged: (v) => update(() => query = v.toLowerCase()),
                  ),
                  Text('${selected.length} sélectionnés · 100 maximum'),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final filtered = reps
                            .where(
                              (d) =>
                                  '${memberDisplay(d.data())} ${d.data()['email'] ?? ''}'
                                      .toLowerCase()
                                      .contains(query),
                            )
                            .toList();
                        if (filtered.isEmpty)
                          return const Center(
                            child: LText('Aucun commercial correspondant.'),
                          );
                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final d = filtered[index];
                            return CheckboxListTile(
                              title: LText(memberDisplay(d.data())),
                              subtitle: LText(
                                d.data()['managerUid'] != null &&
                                        d.data()['managerUid'] != '' &&
                                        d.data()['managerUid'] != managerUid
                                    ? 'Rattaché à un autre responsable ; cocher pour le transférer.'
                                    : (d.data()['email'] ?? '').toString(),
                              ),
                              value: selected.contains(d.id),
                              onChanged: (value) => update(() {
                                if (value == true && selected.length < 100)
                                  selected.add(d.id);
                                else if (value != true)
                                  selected.remove(d.id);
                              }),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const LText('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const LText('Enregistrer'),
              ),
            ],
          ),
        ),
      );
      if (saved != true) return;
      setState(() => _busy = true);
      await FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('assignManagerTeam').call({
        'appId': kAppId,
        'orgId': orgId,
        'managerUid': managerUid,
        'memberUids': selected.toList(),
      });
      _snack('Équipe mise à jour.');
    } catch (error) {
      _snack('Équipe non modifiée : $error. Actualisez avant de réessayer.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignManager(String orgId, String memberUid) async {
    try {
      final snap = await _service.orgRef(orgId).collection('members').get();
      if (!mounted) return;
      final managers = snap.docs.where(
        (d) => d.data()['role'] == 'MANAGER' && d.data()['status'] == 'active',
      );
      final managerUid = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const LText('Responsable du commercial'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const LText('Suivi par l’administrateur'),
            ),
            ...managers.map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, d.id),
                child: LText(
                  (d.data()['displayName'] ??
                          d.data()['email'] ??
                          'Responsable')
                      .toString(),
                ),
              ),
            ),
          ],
        ),
      );
      if (managerUid == null) return;
      await _service.assignMemberManager(
        orgId: orgId,
        memberUid: memberUid,
        managerUid: managerUid,
      );
      _snack('Responsable mis à jour.');
    } catch (error) {
      _snack(error.toString());
    }
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
                subtitle: const LText(
                  'Prospects partagés et tournées personnelles',
                ),
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
              RadioListTile<String>(
                value: 'MANAGER',
                groupValue: currentRole.toUpperCase(),
                title: const LText('Responsable commercial'),
                subtitle: const LText(
                  'Pilote les commerciaux, tournées, calendriers et résultats',
                ),
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
    if (await EnterpriseActions.remove(context, orgId, 'invite', code))
      _snack('Invitation supprimée.');
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

    if (orgId == null || !org.isOwner) {
      return BrandBackground(
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: widget.embedded
              ? null
              : AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: const Center(
            child: LText('Accès réservé à l’administrateur principal.'),
          ),
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
              child: Container(
                color: Colors.white.withOpacity(isDark ? .05 : .26),
              ),
            ),
          ),
          title: const LText(
            'Équipe & accès',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _CompanyHeader(org: org),
              const SizedBox(height: 12),
              if (org.isOwner)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _createInvite(orgId, org.orgName ?? 'Entreprise'),
                  icon: const Icon(Icons.person_add_rounded),
                  label: const LText('Inviter un membre'),
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
                        child: LText(
                          'Chargement impossible : ${snapshot.error}',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(18),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _memberDirectory(
                      snapshot.data!.docs,
                      org,
                      orgId,
                      currentUid,
                    );
                  },
                ),
              ),
              if (org.isOwner) ...[
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
                          child: LText(
                            'Chargement impossible : ${snapshot.error}',
                          ),
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
                                  (docs[index].data()['role'] ?? 'REP')
                                      .toString(),
                                ),
                                subject: 'Invitation Prospecto',
                              ),
                              onRevoke: () =>
                                  _revokeInvite(orgId, docs[index].id),
                            ),
                            if (index != docs.length - 1)
                              const Divider(height: 1),
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
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CompanyAvatar(
      initials: org.initials,
      logoUrl: org.logoUrl,
      size: 40,
    ),
    title: LText(
      org.orgName ?? 'Entreprise',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    subtitle: LText(
      '${org.plan ?? 'Business'} · ${org.maxSeats ?? '—'} places',
      style: const TextStyle(fontSize: 12),
    ),
  );
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
    required this.onAssignManager,
    required this.onManageTeam,
  });

  final Map<String, dynamic> data;
  final String uid;
  final String? currentUid;
  final bool currentUserIsOwner;
  final bool canManage;
  final VoidCallback onChangeRole;
  final VoidCallback onRemove;
  final VoidCallback onTransfer;
  final VoidCallback onAssignManager;
  final VoidCallback onManageTeam;

  @override
  Widget build(BuildContext context) {
    final role = (data['role'] ?? 'REP').toString().toUpperCase();
    final email = (data['email'] ?? 'Membre').toString();
    final fullName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
        .trim();
    final name = fullName.isNotEmpty
        ? fullName
        : (data['displayName'] ?? email).toString();
    final self = uid == currentUid;
    final isOwner = role == 'OWNER';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: CircleAvatar(
        backgroundColor: ProspectoColors.green.withOpacity(.14),
        foregroundColor: ProspectoColors.green,
        child: Icon(
          isOwner ? Icons.workspace_premium_rounded : Icons.person_rounded,
        ),
      ),
      title: LText(
        self ? '$name (vous)' : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: LText(
        name.toLowerCase() == email.toLowerCase()
            ? _label(role)
            : '${_label(role)}\n$email',
      ),
      isThreeLine: name.toLowerCase() != email.toLowerCase(),
      trailing: canManage && !self && !isOwner
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'team') onManageTeam();
                if (value == 'manager') onAssignManager();
                if (value == 'role') onChangeRole();
                if (value == 'remove') onRemove();
                if (value == 'transfer') onTransfer();
              },
              itemBuilder: (_) => [
                if (role == 'MANAGER')
                  const PopupMenuItem(
                    value: 'team',
                    child: LText('Gérer son équipe'),
                  ),
                if (role == 'REP')
                  const PopupMenuItem(
                    value: 'manager',
                    child: LText('Rattacher à un responsable'),
                  ),
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
      subtitle: LText(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'copy') onCopy();
          if (value == 'share') onShare();
          if (value == 'revoke') onRevoke();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'copy', child: LText('Copier le code')),
          PopupMenuItem(value: 'share', child: LText('Partager')),
          PopupMenuItem(
            value: 'revoke',
            child: LText('Supprimer l’invitation'),
          ),
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
