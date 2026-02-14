import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tucheze/features/runner/view/widgets/runner_list_view.dart';

import '../../features/gpu/view/widgets/gpu_picker_view.dart';
import '../../features/gpu/view_model/gpus_view_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    ref.watch(gpusProvider);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16.0,
          children: [GpuPickerView(), RunnerListView()],
        ),
      ),
    );
  }
}
