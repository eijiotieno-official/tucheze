import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/base/compatibility_layer_model.dart';
import '../model/services/compatibility_layer_service.dart';

class AvailableCompatibilityLayersNotifier
    extends AsyncNotifier<List<CompatibilityLayer>> {
  final CompatibilityLayerService _service = CompatibilityLayerService();

  @override
  Future<List<CompatibilityLayer>> build() async {
    // Fetch DXVK and VKD3D-Proton layers
    final dxvkResult = await _service.getAvailableDXVKLayers();
    final vkd3dResult = await _service.getAvailableVKD3DProtonLayers();

    final allLayers = <CompatibilityLayer>[];

    dxvkResult.fold(
      (error) => throw 'Failed to fetch DXVK: $error',
      (layers) => allLayers.addAll(layers),
    );

    vkd3dResult.fold(
      (error) => throw 'Failed to fetch VKD3D-Proton: $error',
      (layers) => allLayers.addAll(layers),
    );

    // Sort by release date (most recent first)
    allLayers.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));

    return allLayers;
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final dxvkResult = await _service.getAvailableDXVKLayers();
      final vkd3dResult = await _service.getAvailableVKD3DProtonLayers();

      final allLayers = <CompatibilityLayer>[];

      dxvkResult.fold(
        (error) => throw 'Failed to fetch DXVK: $error',
        (layers) => allLayers.addAll(layers),
      );

      vkd3dResult.fold(
        (error) => throw 'Failed to fetch VKD3D-Proton: $error',
        (layers) => allLayers.addAll(layers),
      );

      allLayers.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));

      return allLayers;
    });
  }

  Future<void> downloadLayer(
    CompatibilityLayer layer,
    Function(double)? onProgress,
  ) async {
    final result = await _service.downloadLayer(layer, onProgress);

    result.fold((error) => throw error, (downloadedLayer) {
      // Update the layer in the list
      state = state.whenData((layers) {
        return layers.map((l) {
          if (l.name == downloadedLayer.name) {
            return downloadedLayer;
          }
          return l;
        }).toList();
      });
    });
  }
}

final availableCompatibilityLayersProvider =
    AsyncNotifierProvider<
      AvailableCompatibilityLayersNotifier,
      List<CompatibilityLayer>
    >(AvailableCompatibilityLayersNotifier.new);
