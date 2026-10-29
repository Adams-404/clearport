import 'package:flutter/material.dart';

import 'app.dart';
import 'services/store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await Store.open();
  final state = AppState(store: store);
  await state.load();
  state.start();
  runApp(ClearportApp(state: state));
}
