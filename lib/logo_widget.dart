import 'package:easy_localization/easy_localization.dart';
import 'widgets/localized_text.dart';
import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  const LogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset('assets/images/logo.png', height: 120, width: 120),
    );
  }
}
