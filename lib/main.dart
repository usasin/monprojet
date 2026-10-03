import 'sales/solo_sales_pages.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/about_screen.dart';
import 'pages/all_prospects_finished_page.dart';
import 'pages/billing_screen.dart';
import 'pages/developer_console_screen.dart';
import 'pages/home_page.dart';
import 'pages/splash_screen.dart';
import 'pages/enterprise_access_screen.dart';
import 'pages/follow_up_center_page.dart';
import 'pages/information_screen.dart';
import 'pages/login_screen.dart';
import 'pages/map_page.dart';
import 'pages/org_create_screen.dart';
import 'pages/org_join_screen.dart';
import 'pages/org_members_screen.dart';
import 'pages/org_profile_screen.dart';
import 'pages/org_activity_screen.dart';
import 'pages/org_mode_gate.dart';
import 'pages/prospect_form_page.dart';
import 'pages/reporting_page.dart';
import 'pages/select_prospects_page.dart';
import 'pages/settings_screen.dart';
import 'pages/team_dashboard_screen.dart';
import 'providers/org_provider.dart';
import 'providers/theme_provider.dart';
import 'services/ad_service.dart';
import 'services/admin_test_mode.dart';
import 'services/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Sur Android, la configuration Firebase provient de
  // android/app/google-services.json.
  await Firebase.initializeApp();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fr'),
      useOnlyLangCode: true,
      saveLocale: true,
      child: const ProspectoProviders(),
    ),
  );

  // Démarrage non bloquant : initialise AdMob/UMP sans afficher de plein
  // écran au lancement. Les interstitiels ne sont proposés qu'à une pause
  // naturelle du parcours FREE (voir AdService).
  AdService.instance.initialize();
  ReminderService.instance.initialize();
}

class ProspectoProviders extends StatelessWidget {
  const ProspectoProviders({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => OrgProvider()),
      ],
      child: const ProspectoApp(),
    );
  }
}

final _appNavigator = GlobalKey<NavigatorState>();

class ProspectoApp extends StatefulWidget {
  const ProspectoApp({super.key});
  @override
  State<ProspectoApp> createState() => _ProspectoAppState();
}

class _ProspectoAppState extends State<ProspectoApp> {
  int _lastRevocation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = context.watch<OrgProvider>().accessRevocation;
    if (revision != _lastRevocation) {
      _lastRevocation = revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          _appNavigator.currentState?.pushNamedAndRemoveUntil(
            HomePage.routeName,
            (_) => false,
          );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    return MaterialApp(
      navigatorKey: _appNavigator,
      title: 'Prospecto',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!AdminTestMode.enabled) return content;
        return Banner(
          message: AdminTestMode.label,
          location: BannerLocation.topEnd,
          child: content,
        );
      },
      theme: theme,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      initialRoute: SplashScreen.routeName,
      routes: {
        SplashScreen.routeName: (_) => const SplashScreen(),
        EnterpriseAccessScreen.routeName: (_) => const EnterpriseAccessScreen(),
        HomePage.routeName: (_) => const HomePage(),
        OrgModeGate.routeName: (_) => const OrgModeGate(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        SelectProspectsPage.routeName: (_) => const SelectProspectsPage(),
        MapPage.routeName: (_) => const MapPage(),
        ReportingPage.routeName: (_) => const ReportingPage(),
        SoloProspectsPage.routeName: (_) => const SoloProspectsPage(),
        SoloSalesResultsPage.routeName: (_) => const SoloSalesResultsPage(),
        AllProspectsFinishedPage.routeName: (_) =>
            const AllProspectsFinishedPage(),
        ProspectFormPage.routeName: (_) => const ProspectFormPage(),
        SettingsScreen.routeName: (_) => const SettingsScreen(),
        AboutScreen.routeName: (_) => const AboutScreen(),
        InformationScreen.routeName: (_) => const InformationScreen(),
        BillingScreen.routeName: (_) => const BillingScreen(),
        DeveloperConsoleScreen.routeName: (_) => const DeveloperConsoleScreen(),
        OrgCreateScreen.routeName: (_) => const OrgCreateScreen(),
        OrgJoinScreen.routeName: (_) => const OrgJoinScreen(),
        OrgMembersScreen.routeName: (_) => const OrgMembersScreen(),
        OrgProfileScreen.routeName: (_) => const OrgProfileScreen(),
        OrgActivityScreen.routeName: (_) => const OrgActivityScreen(),
        FollowUpCenterPage.routeName: (_) => const FollowUpCenterPage(),
        TeamDashboardScreen.routeName: (_) => const TeamDashboardScreen(),
      },
    );
  }
}
