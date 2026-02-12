import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_view.dart';
import '../../view_model/gpus_view_model.dart';
import '../../view_model/selected_gpu_view_model.dart';

class GpuPickerView extends ConsumerWidget {
  const GpuPickerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gpusAsyncValue = ref.watch(gpusProvider);

    return AsyncView(
      asyncValue: gpusAsyncValue,
      loadingWidget: SizedBox.shrink(),
      builder: (gpus) {
        final selectedGpuAsync = ref.watch(selectedGpuProvider);

        return AsyncView(
          asyncValue: selectedGpuAsync,
          loadingWidget: SizedBox.shrink(),
          builder: (selectedGpu) {
            // Only auto-select if no GPU is saved
            if (selectedGpu == null && gpus.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(selectedGpuProvider.notifier).onSelect(gpus.first);
              });
            }

            final items = gpus
                .map(
                  (gpu) => DropdownMenuItem(
                    value: gpu,
                    child: Text('${gpu.vendor} ${gpu.name}'),
                  ),
                )
                .toList();

            return DropdownButton(
              value: selectedGpu,
              items: items,
              onChanged: (gpu) {
                if (gpu != null) {
                  ref.read(selectedGpuProvider.notifier).onSelect(gpu);
                }
              },
            );
          },
          errorBuilder: (error, stack) {
            // On error, continue with null selection
            final items = gpus
                .map(
                  (gpu) => DropdownMenuItem(
                    value: gpu,
                    child: Text('${gpu.vendor} ${gpu.name}'),
                  ),
                )
                .toList();

            return DropdownButton(
              value: gpus.isNotEmpty ? gpus.first : null,
              items: items,
              onChanged: (gpu) {
                if (gpu != null) {
                  ref.read(selectedGpuProvider.notifier).onSelect(gpu);
                }
              },
            );
          },
        );
      },
    );
  }
}
