import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/prospecto_colors.dart';

/// Avatar du compte Firebase actif.
/// Utilise la photo du profil si elle existe, sinon affiche les initiales.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.user,
    this.size = 30,
  });

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
    final initials = seedSource
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [ProspectoColors.blue, ProspectoColors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initials.isEmpty ? 'P' : initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    if (photo == null || photo.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
