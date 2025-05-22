import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'pages/about_screen.dart';
import 'pages/all_prospects_finished_page.dart';
import 'pages/information_screen.dart';
import 'providers/theme_provider.dart';
import 'pages/login_screen.dart';
import 'pages/home_page.dart';
import 'pages/select_prospects_page.dart';
import 'pages/reporting_page.dart';

import 'pages/map_page.dart';


// Ajouts :
import 'pages/prospect_form_page.dart';
import 'pages/prospects_finished_page.dart';
import 'pages/settings_screen.dart';

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
        builder: (_, __) => ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
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
    final theme = Provider.of<ThemeProvider>(context).currentTheme;

    return MaterialApp(
      title: 'AI Prospect GPS',
      theme: theme,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      initialRoute: LoginScreen.routeName,
      routes: {
        LoginScreen.routeName            : (_) => const LoginScreen(),
        HomePage.routeName               : (_) => const HomePage(),
        SelectProspectsPage.routeName    : (_) => const SelectProspectsPage(),
        ReportingPage.routeName       : (_) => const ReportingPage(),

        MapPage.routeName                : (_) => const MapPage(),
        AboutScreen.routeName   : (_) => const AboutScreen(), // ← nouveau
        InformationScreen.routeName   : (_) => const InformationScreen(), // ← nouveau
        AllProspectsFinishedPage.routeName: (_) => const AllProspectsFinishedPage(),
        // Nouvelles pages
        ProspectFormPage.routeName       : (_) => const ProspectFormPage(),
        ProspectsFinishedPage.routeName  : (ctx) {
          final date = ModalRoute.of(ctx)!.settings.arguments as DateTime;
          return ProspectsFinishedPage(date: date);
        },
        SettingsScreen.routeName         : (_) => const SettingsScreen(),
      },
      onUnknownRoute: (_) => MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }
}
