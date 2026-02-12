import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/enum/runner_type.dart';

class SelectedRunnerTypeNotifier extends Notifier<RunnerType> {
  @override
  build() {
    return RunnerType.protonGE; // Default to Proton-GE
  }

  void setRunnerType(RunnerType type) {
    state = type;
  }
}

final selectedRunnerTypeProvider =
    NotifierProvider<SelectedRunnerTypeNotifier, RunnerType>(
      SelectedRunnerTypeNotifier.new,
    );
