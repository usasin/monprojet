import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// Providers
import 'pages/billing_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/org_provider.dart';

// Pages
import 'pages/login_screen.dart';
import 'pages/home_page.dart';
import 'pages/select_prospects_page.dart';
import 'pages/reporting_page.dart';
import 'pages/map_page.dart';
import 'pages/about_screen.dart';
import 'pages/information_screen.dart';
import 'pages/all_prospects_finished_page.dart';
import 'pages/prospect_form_page.dart';
import 'pages/prospects_finished_page.dart';
import 'pages/settings_screen.dart';

// Entreprise (toujours dispo mais plus au démarrage)
import 'pages/org_mode_gate.dart';
import 'pages/org_create_screen.dart';
import 'pages/org_join_screen.dart';
import 'pages/org_members_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        builder: (_, __) => MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => OrgProvider()),
          ],
          child: const MyApp(),
        ),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Prospecto',
      theme: theme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // 👉 On démarre maintenant DIRECTEMENT sur la page de login
      initialRoute: LoginScreen.routeName,

      routes: {
        // Auth + Home
        LoginScreen.routeName             : (_) => const LoginScreen(),
        HomePage.routeName                : (_) => const HomePage(),

        // Prospection
        SelectProspectsPage.routeName     : (_) => const SelectProspectsPage(),
        ReportingPage.routeName           : (_) => const ReportingPage(),
        MapPage.routeName                 : (_) => const MapPage(),

        // Infos
        AboutScreen.routeName             : (_) => const AboutScreen(),
        InformationScreen.routeName       : (_) => const InformationScreen(),

        // Historique / détails
        AllProspectsFinishedPage.routeName: (_) => const AllProspectsFinishedPage(),
        ProspectFormPage.routeName        : (_) => const ProspectFormPage(),
        ProspectsFinishedPage.routeName   : (ctx) {
          final date = ModalRoute.of(ctx)!.settings.arguments as DateTime;
          return ProspectsFinishedPage(date: date);
        },

        // Réglages
        SettingsScreen.routeName          : (_) => const SettingsScreen(),
        BillingScreen.routeName           : (_) => const BillingScreen(),

        // Entreprise (toujours présents mais plus utilisés au démarrage)
        OrgModeGate.routeName             : (_) => const OrgModeGate(),
        OrgCreateScreen.routeName         : (_) => const OrgCreateScreen(),
        OrgJoinScreen.routeName           : (_) => const OrgJoinScreen(),
        OrgMembersScreen.routeName        : (_) => const OrgMembersScreen(),
      },

      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }
}
