import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/org_provider.dart';
import '../theme/prospecto_colors.dart';
import 'localized_text.dart';

/// Carte d'identité de session : rend toujours explicite quel compte est actif.
/// Elle distingue l'identité Firebase du rôle métier dans l'espace Entreprise.
class UserIdentityCard extends StatelessWidget {
  const UserIdentityCard({
    super.key,
    this.isDeveloper = false,
    this.onChangeAccount,
    this.compact = false,
  });

  final bool isDeveloper;
  final VoidCallback? onChangeAccount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final org = context.watch<OrgProvider>();
    final email = _email(user);
    final name = _displayName(user);
    final provider = _providerLabel(user);
    final isGuest = user?.isAnonymous == true;

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 17),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.76),
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: Colors.white.withOpacity(.9)),
        boxShadow: [
          BoxShadow(
            color: ProspectoColors.blue.withOpacity(.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _UserAvatar(user: user, size: compact ? 46 : 54),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LText(
                      'COMPTE CONNECTÉ',
                      style: TextStyle(
                        color: ProspectoColors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    LText(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ProspectoColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    LText(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ProspectoColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _IdentityChip(
                icon: isGuest ? Icons.person_outline_rounded : Icons.verified_user_rounded,
                label: provider,
                color: ProspectoColors.blue,
              ),
              _IdentityChip(
                icon: org.isTeam ? Icons.apartment_rounded : Icons.person_rounded,
                label: org.isTeam
                    ? '${org.orgName ?? 'Entreprise'} · ${org.roleLabel}'
                    : 'Espace personnel',
                color: org.isTeam ? ProspectoColors.green : ProspectoColors.blue,
              ),
              if (isDeveloper)
                const _IdentityChip(
                  icon: Icons.developer_mode_rounded,
                  label: 'Développeur Prospecto',
                  color: ProspectoColors.green,
                ),
            ],
          ),
          if (onChangeAccount != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onChangeAccount,
              icon: const Icon(Icons.switch_account_rounded, size: 19),
              label: const LText('Changer de compte'),
            ),
          ],
        ],
      ),
    );
  }

  static String _email(User? user) {
    if (user == null) return 'Aucun compte connecté';
    if (user.isAnonymous) return 'Session invitée';
    final email = user.email?.trim();
    if (email?.isNotEmpty == true) return email!;
    final phone = user.phoneNumber?.trim();
    if (phone?.isNotEmpty == true) return phone!;
    final end = user.uid.length < 8 ? user.uid.length : 8;
    return 'Compte Firebase ${user.uid.substring(0, end)}';
  }

  static String _displayName(User? user) {
    if (user == null) return 'Non connecté';
    if (user.isAnonymous) return 'Invité';
    final name = user.displayName?.trim();
    if (name?.isNotEmpty == true) return name!;
    final email = user.email?.trim();
    if (email?.isNotEmpty == true) return email!.split('@').first;
    return 'Compte Prospecto';
  }

  static String _providerLabel(User? user) {
    if (user == null) return 'Non connecté';
    if (user.isAnonymous) return 'Mode invité';
    final ids = user.providerData.map((p) => p.providerId).toSet();
    if (ids.contains('google.com')) return 'Compte Google';
    if (ids.contains('password')) return 'E-mail + mot de passe';
    if (ids.contains('apple.com')) return 'Compte Apple';
    return 'Compte Prospecto';
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, required this.size});

  final User? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoURL?.trim();
    final displayName = user?.displayName?.trim() ?? '';
    final email = user?.email?.trim() ?? '';
    final seedSource = displayName.isNotEmpty
        ? displayName
        : email.isNotEmpty
            ? email
            : 'P';
    final seed = seedSource
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [ProspectoColors.blue, ProspectoColors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: photo?.isNotEmpty == true
            ? DecorationImage(image: NetworkImage(photo!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: photo?.isNotEmpty == true
          ? null
          : Text(
              seed.isEmpty ? 'P' : seed,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * .34,
              ),
            ),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: LText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
