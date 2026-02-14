import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/base/compatibility_layer_model.dart';
import '../model/services/compatibility_layer_service.dart';

class DownloadedCompatibilityLayersNotifier
    extends AsyncNotifier<List<CompatibilityLayer>> {
  final CompatibilityLayerService _service = CompatibilityLayerService();

  @override
  Future<List<CompatibilityLayer>> build() async {
    final result = await _service.getDownloadedLayers();

    return result.fold((error) => throw error, (layers) {
      // Sort by name
      layers.sort((a, b) => a.name.compareTo(b.name));
      return layers;
    });
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final result = await _service.getDownloadedLayers();
      return result.fold((error) => throw error, (layers) {
        layers.sort((a, b) => a.name.compareTo(b.name));
        return layers;
      });
    });
  }

  Future<void> deleteLayer(CompatibilityLayer layer) async {
    final result = await _service.deleteLayer(layer);

    result.fold((error) => throw error, (_) {
      // Remove from list
      state = state.whenData((layers) {
        return layers.where((l) => l.name != layer.name).toList();
      });
    });
  }
}

final downloadedCompatibilityLayersProvider =
    AsyncNotifierProvider<
      DownloadedCompatibilityLayersNotifier,
      List<CompatibilityLayer>
    >(DownloadedCompatibilityLayersNotifier.new);
