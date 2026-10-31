import 'package:flutter/material.dart';

import 'models/app_theme_choice.dart';
import 'screens/chat_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'widgets/app_scope.dart';

class ClearportApp extends StatelessWidget {
  const ClearportApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ValueListenableBuilder<AppThemeChoice>(
        valueListenable: state.theme,
        builder: (context, choice, _) {
          final isSystem = choice == AppThemeChoice.system;
          return MaterialApp(
            title: 'Clearport',
            debugShowCheckedModeBanner: false,
            // Non-system choices ignore the platform brightness, so both slots
            // resolve to the same palette and a system dark/light switch cannot
            // override what the user picked.
            theme: AppTheme.forChoice(
              choice,
              platformBrightness: Brightness.light,
            ),
            darkTheme: AppTheme.forChoice(
              choice,
              platformBrightness: Brightness.dark,
            ),
            themeMode: isSystem
                ? ThemeMode.system
                : (choice.isDark ? ThemeMode.dark : ThemeMode.light),
            home: const ChatScreen(),
          );
        },
      ),
    );
  }
}
