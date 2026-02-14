import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/base/performance_tool_model.dart';
import '../model/services/performance_tool_service.dart';

class PerformanceToolsNotifier extends AsyncNotifier<List<PerformanceTool>> {
  final PerformanceToolService _service = PerformanceToolService();

  @override
  Future<List<PerformanceTool>> build() async {
    // Check all performance tools
    final mangoHudResult = await _service.checkMangoHud();
    final gameModeResult = await _service.checkGameMode();
    final vkBasaltResult = await _service.checkVkBasalt();
    final cpuGovernorResult = await _service.checkCpuGovernor();

    final tools = <PerformanceTool>[];

    mangoHudResult.fold(
      (error) => throw 'Failed to check MangoHud: $error',
      (tool) => tools.add(tool),
    );

    gameModeResult.fold(
      (error) => throw 'Failed to check GameMode: $error',
      (tool) => tools.add(tool),
    );

    vkBasaltResult.fold(
      (error) => throw 'Failed to check vkBasalt: $error',
      (tool) => tools.add(tool),
    );

    cpuGovernorResult.fold(
      (error) => throw 'Failed to check CPU Governor: $error',
      (tool) => tools.add(tool),
    );

    return tools;
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final mangoHudResult = await _service.checkMangoHud();
      final gameModeResult = await _service.checkGameMode();
      final vkBasaltResult = await _service.checkVkBasalt();
      final cpuGovernorResult = await _service.checkCpuGovernor();

      final tools = <PerformanceTool>[];

      mangoHudResult.fold(
        (error) => throw 'Failed to check MangoHud: $error',
        (tool) => tools.add(tool),
      );

      gameModeResult.fold(
        (error) => throw 'Failed to check GameMode: $error',
        (tool) => tools.add(tool),
      );

      vkBasaltResult.fold(
        (error) => throw 'Failed to check vkBasalt: $error',
        (tool) => tools.add(tool),
      );

      cpuGovernorResult.fold(
        (error) => throw 'Failed to check CPU Governor: $error',
        (tool) => tools.add(tool),
      );

      return tools;
    });
  }

  Future<void> installMangoHud() async {
    final result = await _service.installMangoHud();

    result.fold((error) => throw error, (_) async {
      // Reload to check if installation succeeded
      await Future.delayed(const Duration(seconds: 2));
      await reload();
    });
  }

  Future<void> installGameMode() async {
    final result = await _service.installGameMode();

    result.fold((error) => throw error, (_) async {
      // Reload to check if installation succeeded
      await Future.delayed(const Duration(seconds: 2));
      await reload();
    });
  }

  Future<void> installVkBasalt() async {
    final result = await _service.installVkBasalt();

    result.fold((error) => throw error, (_) async {
      // Reload to check if installation succeeded
      await Future.delayed(const Duration(seconds: 2));
      await reload();
    });
  }

  Future<void> installCpuGovernor() async {
    final result = await _service.installCpuGovernor();

    result.fold((error) => throw error, (_) async {
      // Reload to check if installation succeeded
      await Future.delayed(const Duration(seconds: 2));
      await reload();
    });
  }

  Future<void> toggleMangoHud(bool enabled) async {
    final result = await _service.toggleMangoHud(enabled);

    result.fold((error) => throw error, (newState) {
      // Update the tool in the list
      state = state.whenData((tools) {
        return tools.map((tool) {
          if (tool.type.id == 'mangohud') {
            return tool.copyWith(isEnabled: newState);
          }
          return tool;
        }).toList();
      });
    });
  }

  Future<void> toggleGameMode(bool enabled) async {
    final result = await _service.toggleGameMode(enabled);

    result.fold((error) => throw error, (newState) {
      // Update the tool in the list
      state = state.whenData((tools) {
        return tools.map((tool) {
          if (tool.type.id == 'gamemode') {
            return tool.copyWith(isEnabled: newState);
          }
          return tool;
        }).toList();
      });
    });
  }

  Future<void> toggleVkBasalt(bool enabled) async {
    final result = await _service.toggleVkBasalt(enabled);

    result.fold((error) => throw error, (newState) {
      // Update the tool in the list
      state = state.whenData((tools) {
        return tools.map((tool) {
          if (tool.type.id == 'vkbasalt') {
            return tool.copyWith(isEnabled: newState);
          }
          return tool;
        }).toList();
      });
    });
  }

  Future<void> toggleCpuGovernor(bool enabled) async {
    final result = await _service.toggleCpuGovernor(enabled);

    result.fold((error) => throw error, (newState) {
      // Update the tool in the list
      state = state.whenData((tools) {
        return tools.map((tool) {
          if (tool.type.id == 'cpugovernor') {
            return tool.copyWith(isEnabled: newState);
          }
          return tool;
        }).toList();
      });
    });
  }
}

final performanceToolsProvider =
    AsyncNotifierProvider<PerformanceToolsNotifier, List<PerformanceTool>>(
      PerformanceToolsNotifier.new,
    );
