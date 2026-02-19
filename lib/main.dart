import 'dart:async';
import 'dart:io';

import 'package:adwaita_gtk/adwaita_gtk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/screens/home_screen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1000, 600),
    minimumSize: Size(400, 450),
    skipTaskbar: false,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
    title: 'Tucheze',
  );

  unawaited(
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (Platform.isLinux || Platform.isMacOS) {
        await windowManager.setAsFrameless();
      }
      await windowManager.show();
      await windowManager.focus();
    }),
  );

  runApp(ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final virtualWindowFrame = VirtualWindowFrameInit();

        return virtualWindowFrame(context, child);
      },
      theme: AdwaitaThemeData.light(),
      darkTheme: AdwaitaThemeData.dark(),
      themeMode: ThemeMode.system,
      home: HomeScreen(),
    );
  }
}
