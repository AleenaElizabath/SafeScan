import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'scan.dart';
import 'profile.dart';
import 'res1.dart';
import 'res2.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('hi', 'IN'),
        Locale('ml', 'IN'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: const SafeScan(),
    ),
  );
}

class SafeScan extends StatelessWidget {
  const SafeScan({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var farmer;
    return MaterialApp(
      title: 'app_title'.tr(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // 🌿 Global Theme with improved design
      theme: ThemeData(
        primaryColor: const Color(0xFF00D084),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D084),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D084),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 4,
          ),
        ),
      ),

      // 🚀 First Screen
      home: const ScanScreen(),

      // 🔁 Named Routes (optional but professional)
      routes: {
        '/scan': (context) => const ScanScreen(),
        '/profile': (context) => FarmProfileSetupScreen(farmer: farmer),
        '/pesticide-result': (context) => PestAnalysisScreen(farmer: farmer),
        '/plant-result': (context) => DiagnosisResultScreen(farmer: farmer),
      },
    );
  }
}
