import 'package:easy_localization/easy_localization.dart';
import 'localized_text.dart';
import 'package:flutter/material.dart';

import '../theme/prospecto_colors.dart';

class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({
    super.key,
    required this.initials,
    this.logoUrl,
    this.size = 52,
  });

  final String initials;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ProspectoColors.green, ProspectoColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * .30),
      ),
      child: LText(
        initials.isEmpty ? 'EN' : initials,
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .31,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .30),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Stack(
            alignment: Alignment.center,
            children: [
              fallback,
              SizedBox(
                width: size * .35,
                height: size * .35,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
