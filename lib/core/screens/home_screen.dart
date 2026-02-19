import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libadwaita/libadwaita.dart';
import 'package:libadwaita_window_manager/libadwaita_window_manager.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          AdwHeaderBar(
            title: Text("Tucheze"),
            start: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add),
              ),
            ],
            actions: AdwActions().windowManager,
          ),
        ],
      ),
    );
  }
}
