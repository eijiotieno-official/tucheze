import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/base/runner_model.dart';
import '../model/services/runner_service.dart';

class DownloadedRunnersNotifier extends AsyncNotifier<List<Runner>> {
  final RunnerService _runnerService = RunnerService();

  @override
  Future<List<Runner>> build() async {
    final result = await _runnerService.getDownloadedRunners();

    return result.fold((error) => throw error, (runners) {
      // Sort by name
      runners.sort((a, b) => a.name.compareTo(b.name));
      return runners;
    });
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final result = await _runnerService.getDownloadedRunners();
      return result.fold((error) => throw error, (runners) {
        runners.sort((a, b) => a.name.compareTo(b.name));
        return runners;
      });
    });
  }

  Future<void> deleteRunner(Runner runner) async {
    final result = await _runnerService.deleteRunner(runner);

    result.fold((error) => throw error, (_) {
      // Remove from list
      state = state.whenData((runners) {
        return runners.where((r) => r.name != runner.name).toList();
      });
    });
  }
}

final downloadedRunnersProvider =
    AsyncNotifierProvider<DownloadedRunnersNotifier, List<Runner>>(
      DownloadedRunnersNotifier.new,
    );
