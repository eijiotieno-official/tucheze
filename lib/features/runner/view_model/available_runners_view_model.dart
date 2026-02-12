import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/base/runner_model.dart';
import '../model/services/runner_service.dart';

class AvailableRunnersNotifier extends AsyncNotifier<List<Runner>> {
  final RunnerService _runnerService = RunnerService();

  @override
  Future<List<Runner>> build() async {
    // Fetch Proton-GE, Wine-GE, and Lutris Wine runners
    final protonResult = await _runnerService.getAvailableProtonRunners();
    final wineResult = await _runnerService.getAvailableWineRunners();
    final lutrisResult = await _runnerService.getAvailableLutrisRunners();

    final allRunners = <Runner>[];

    protonResult.fold(
      (error) => throw 'Failed to fetch Proton runners: $error',
      (runners) => allRunners.addAll(runners),
    );

    wineResult.fold(
      (error) => throw 'Failed to fetch Wine runners: $error',
      (runners) => allRunners.addAll(runners),
    );

    lutrisResult.fold(
      (error) => throw 'Failed to fetch Lutris runners: $error',
      (runners) => allRunners.addAll(runners),
    );

    // Sort by release date (most recent first)
    allRunners.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));

    return allRunners;
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final protonResult = await _runnerService.getAvailableProtonRunners();
      final wineResult = await _runnerService.getAvailableWineRunners();
      final lutrisResult = await _runnerService.getAvailableLutrisRunners();

      final allRunners = <Runner>[];

      protonResult.fold(
        (error) => throw 'Failed to fetch Proton runners: $error',
        (runners) => allRunners.addAll(runners),
      );

      wineResult.fold(
        (error) => throw 'Failed to fetch Wine runners: $error',
        (runners) => allRunners.addAll(runners),
      );

      lutrisResult.fold(
        (error) => throw 'Failed to fetch Lutris runners: $error',
        (runners) => allRunners.addAll(runners),
      );

      allRunners.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));

      return allRunners;
    });
  }

  Future<void> downloadRunner(
    Runner runner,
    Function(double)? onProgress,
  ) async {
    final result = await _runnerService.downloadRunner(runner, onProgress);

    result.fold((error) => throw error, (downloadedRunner) {
      // Update the runner in the list
      state = state.whenData((runners) {
        return runners.map((r) {
          if (r.name == downloadedRunner.name) {
            return downloadedRunner;
          }
          return r;
        }).toList();
      });
    });
  }
}

final availableRunnersProvider =
    AsyncNotifierProvider<AvailableRunnersNotifier, List<Runner>>(
      AvailableRunnersNotifier.new,
    );
