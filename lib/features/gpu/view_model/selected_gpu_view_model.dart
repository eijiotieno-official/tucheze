import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/base/gpu_model.dart';

class SelectedGpuNotifier extends AsyncNotifier<GPU?> {
  static const String _selectedGpuKey = 'selected_gpu';

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  @override
  Future<GPU?> build() async {
    // Load saved GPU on initialization
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGpuJson = prefs.getString(_selectedGpuKey);

      if (savedGpuJson != null) {
        final savedGpu = GPU.fromJson(savedGpuJson);
        _logger.i('Loaded saved GPU from preferences : ${savedGpu.vendor} ${savedGpu.name}');
        return savedGpu;
      }
      _logger.d('No saved GPU found in preferences');
    } catch (e, stackTrace) {
      _logger.e('Failed to load saved GPU', error: e, stackTrace: stackTrace);
    }
    return null;
  }

  Future<void> onSelect(GPU gpu) async {
    state = AsyncValue.data(gpu);

    // Save selected GPU to shared preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedGpuKey, gpu.toJson());
      _logger.i('Saved GPU selection: ${gpu.vendor} ${gpu.name}');
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to save GPU selection',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> clear() async {
    state = const AsyncValue.data(null);

    // Clear saved GPU from shared preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_selectedGpuKey);
      _logger.i('Cleared GPU selection from preferences');
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to clear GPU selection',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

final selectedGpuProvider = AsyncNotifierProvider<SelectedGpuNotifier, GPU?>(
  SelectedGpuNotifier.new,
);
