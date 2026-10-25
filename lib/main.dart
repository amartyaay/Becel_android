import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const BecelApp());
}

class BecelApp extends StatefulWidget {
  const BecelApp({super.key});

  @override
  State<BecelApp> createState() => _BecelAppState();
}

class _BecelAppState extends State<BecelApp> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Becel',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      routerConfig: _router,
    );
  }
}
