import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'router/app_router.dart';
import 'services/background_music_controller.dart';
import 'theme/app_theme.dart';

class MarketcatiaApp extends StatefulWidget {
  const MarketcatiaApp({super.key});

  @override
  State<MarketcatiaApp> createState() => _MarketcatiaAppState();
}

class _MarketcatiaAppState extends State<MarketcatiaApp> {
  late final AppProvider _provider;
  late final BackgroundMusicController _music;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _provider = AppProvider()..init();
    _music = BackgroundMusicController()..init();
    _router = createAppRouter(_provider);
  }

  @override
  void dispose() {
    _music.dispose();
    _provider.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _provider),
        ChangeNotifierProvider.value(value: _music),
      ],
      child: MaterialApp.router(
        title: 'Marketcatia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
