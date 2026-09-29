import 'package:easy_localization/easy_localization.dart';
import 'localized_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/enterprise_access_screen.dart';
import '../pages/home_page.dart';
import '../pages/preparing_space_screen.dart';
import '../providers/org_provider.dart';
import '../theme/prospecto_colors.dart';
import 'company_avatar.dart';

class WorkspaceBadge extends StatelessWidget {
  const WorkspaceBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    final color = org.isTeam ? ProspectoColors.green : ProspectoColors.blue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showWorkspacePicker(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: BoxConstraints(maxWidth: compact ? 245 : 280),
          padding: EdgeInsets.fromLTRB(
            compact ? 8 : 10,
            compact ? 6 : 7,
            compact ? 9 : 12,
            compact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(.11),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withOpacity(.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (org.isTeam)
                CompanyAvatar(
                  initials: org.initials,
                  logoUrl: org.logoUrl,
                  size: compact ? 25 : 30,
                )
              else
                Container(
                  width: compact ? 25 : 30,
                  height: compact ? 25 : 30,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    size: compact ? 15 : 18,
                    color: color,
                  ),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      org.workspaceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (org.isTeam)
                      LText(
                        '${org.orgName ?? 'Entreprise'} • ${org.roleLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 9.5 : 10.5,
                          color: ProspectoColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.expand_more_rounded, size: 17, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWorkspacePicker(BuildContext context) async {
    final org = context.read<OrgProvider>();
    await showModalBottomSheet<void>(
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
                'Changer d’espace',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const LText(
                'Les données personnelles et celles de l’entreprise restent séparées.',
                style: TextStyle(color: ProspectoColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _WorkspaceOption(
                selected: !org.isTeam,
                color: ProspectoColors.blue,
                icon: Icons.person_rounded,
                title: 'Personnel',
                subtitle: 'Mes prospects et mes tournées privées',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null || !context.mounted) return;
                  await PreparingSpaceScreen.open(
                    context,
                    action: () => context
                        .read<OrgProvider>()
                        .switchToPersonal(user.uid),
                    successRoute: HomePage.routeName,
                  );
                },
              ),
              const SizedBox(height: 10),
              _WorkspaceOption(
                selected: org.isTeam,
                color: ProspectoColors.green,
                icon: Icons.apartment_rounded,
                title: org.teamAvailable
                    ? (org.teamOrgName ?? 'Entreprise')
                    : 'Entreprise',
                subtitle: org.teamAvailable
                    ? 'Accéder à mon espace partagé'
                    : 'Créer ou rejoindre une entreprise',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final user = FirebaseAuth.instance.currentUser;
                  if (org.teamAvailable && user != null && context.mounted) {
                    await PreparingSpaceScreen.open(
                      context,
                      action: () =>
                          context.read<OrgProvider>().switchToTeam(user.uid),
                      successRoute: HomePage.routeName,
                    );
                  } else if (context.mounted) {
                    await Navigator.of(context)
                        .pushNamed(EnterpriseAccessScreen.routeName);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceOption extends StatelessWidget {
  const _WorkspaceOption({
    required this.selected,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: color.withOpacity(selected ? .14 : .07),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(.17),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: LText(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: LText(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: color)
          : const Icon(Icons.arrow_forward_ios_rounded, size: 15),
    );
  }
}
