import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import 'app_header.dart';
import 'bottom_nav.dart';
import 'emily_chat_widget.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        key: const Key('search-input'),
        focusNode: app.searchFocusNode,
        onChanged: app.setBusqueda,
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
          suffixIcon: app.busqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => app.setBusqueda(''),
                )
              : null,
          filled: true,
          fillColor: AppColors.lightBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

void goHomeAndSearch(BuildContext context) {
  final app = context.read<AppProvider>();
  app.resetHomeState();
  app.requestSearchFocus();
}
