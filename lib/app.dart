import 'package:flutter/material.dart';

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
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: state.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'Clearport',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const ChatScreen(),
        ),
      ),
    );
  }
}
