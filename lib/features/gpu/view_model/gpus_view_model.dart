import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/base/gpu_model.dart';
import '../model/services/gpu_service.dart';

class GpusNotifier extends AsyncNotifier<List<GPU>> {
  final GpuService _gpuService = GpuService();
  @override
  Future<List<GPU>> build() async {
    final result = await _gpuService.getGpus();

    return result.fold((error) => throw error, (gpus) => gpus);
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final result = await _gpuService.getGpus();
      return result.fold((error) => throw error, (gpus) => gpus);
    });
  }
}

final gpusProvider = AsyncNotifierProvider<GpusNotifier, List<GPU>>(
  GpusNotifier.new,
);

