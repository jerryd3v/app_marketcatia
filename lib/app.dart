import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MarketcatiaApp extends StatefulWidget {
  const MarketcatiaApp({super.key});

  @override
  State<MarketcatiaApp> createState() => _MarketcatiaAppState();
}

class _MarketcatiaAppState extends State<MarketcatiaApp> {
  late final AppProvider _provider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _provider = AppProvider()..init();
    _router = createAppRouter(_provider);
  }

  @override
  void dispose() {
    _provider.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: MaterialApp.router(
        title: 'Marketcatia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
