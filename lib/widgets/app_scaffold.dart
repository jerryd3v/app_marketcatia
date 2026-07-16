import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import 'app_header.dart';
import 'bottom_nav.dart';
import 'emily_chat_widget.dart';
import 'market_search_bar.dart';
import 'mode_notification.dart';
import 'payment_modality_prompt.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.location = '/',
  });

  final Widget child;
  final String location;

  bool get _showSearch =>
      location == '/' || location.startsWith('/campana');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: Stack(
        children: [
          Column(
            children: [
              const AppHeader(),
              if (_showSearch)
                Consumer<AppProvider>(
                  builder: (context, app, _) => _SearchField(app: app),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 0),
                  child: child,
                ),
              ),
            ],
          ),
          const ModeNotification(),
          const PaymentModalityPrompt(),
          const EmilyChatWidget(),
        ],
      ),
      bottomNavigationBar: const BottomNav(),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.app});
  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: MarketSearchBar(
        focusNode: app.searchFocusNode,
        onChanged: app.setBusqueda,
        value: app.busqueda,
        fillColor: AppColors.cardBg,
        onClear: app.busqueda.isNotEmpty ? () => app.setBusqueda('') : null,
      ),
    );
  }
}

void goHomeAndSearch(BuildContext context) {
  final app = context.read<AppProvider>();
  app.resetHomeState();
  app.requestSearchFocus();
}
