import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_translations.dart';
import 'routes/app_pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const NearWordApp());
}

class NearWordApp extends StatelessWidget {
  const NearWordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      translations: AppTranslations(),
      locale: AppTranslations.fallback,
      fallbackLocale: AppTranslations.fallback,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppTranslations.supported,
      initialRoute: AppPages.initial,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
    );
  }
}
