import 'package:flutter/material.dart';
import 'package:fitflow/config/routes.dart';
import 'package:fitflow/config/theme.dart';
import 'package:fitflow/features/onboarding/screens/splash_screen.dart';

class FitFlowApp extends StatelessWidget {
  const FitFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const SplashScreen(),
    );
  }
}
