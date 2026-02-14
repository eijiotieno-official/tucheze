import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_view.dart';
import '../../model/base/compatibility_layer_model.dart';
import '../../model/enum/compatibility_layer_type.dart';
import '../../view_model/available_compatibility_layers_view_model.dart';
import '../../view_model/downloaded_compatibility_layers_view_model.dart';

class CompatibilityLayerListView extends ConsumerStatefulWidget {
  const CompatibilityLayerListView({super.key});

  @override
  ConsumerState<CompatibilityLayerListView> createState() =>
      _CompatibilityLayerListViewState();
}

class _CompatibilityLayerListViewState
    extends ConsumerState<CompatibilityLayerListView> {
  final Map<String, double> _downloadProgress = {};
  CompatibilityLayerType _selectedType = CompatibilityLayerType.dxvk;

  @override
  Widget build(BuildContext context) {
    final availableLayersAsync = ref.watch(
      availableCompatibilityLayersProvider,
    );

    return Expanded(
      child: AsyncView(
        asyncValue: availableLayersAsync,
        builder: (availableLayers) {
          if (availableLayers.isEmpty) {
            return const Center(
              child: Text('No compatibility layers available'),
            );
          }

          final layerTypes = CompatibilityLayerType.values;

          final layers = availableLayers
              .where((layer) => layer.type == _selectedType)
              .toList();

          return Column(
            spacing: 16.0,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16.0,
                children: layerTypes.map((type) {
                  final isSelected = type == _selectedType;
                  return ChoiceChip(
                    label: Text(type.displayName),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedType = type;
                      });
                    },
                  );
                }).toList(),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(availableCompatibilityLayersProvider.notifier)
                        .reload();
                  },
                  child: ListView.builder(
                    itemCount: layers.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final layer = layers[index];
                      return _buildLayerCard(layer);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLayerCard(CompatibilityLayer layer) {
    final progress = _downloadProgress[layer.name];
    final isDownloading = progress != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            layer.type == CompatibilityLayerType.dxvk
                ? Icons.layers
                : Icons.filter_vintage,
          ),
        ),
        title: Text(
          layer.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${layer.type.displayName} • ${layer.sizeFormatted}'),
            if (layer.localPath != null)
              Text(
                'Path: ${layer.localPath}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            if (isDownloading)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(value: progress),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!layer.isDownloaded && !isDownloading)
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadLayer(layer),
                tooltip: 'Download',
              ),
            if (layer.isDownloaded && !isDownloading)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(layer),
                tooltip: 'Delete',
              ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showLayerDetails(layer),
              tooltip: 'Details',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadLayer(CompatibilityLayer layer) async {
    setState(() {
      _downloadProgress[layer.name] = 0.0;
    });

    try {
      await ref
          .read(availableCompatibilityLayersProvider.notifier)
          .downloadLayer(layer, (progress) {
            setState(() {
              _downloadProgress[layer.name] = progress;
            });
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${layer.name} downloaded successfully')),
        );
      }

      // Refresh downloaded layers list
      await ref.read(downloadedCompatibilityLayersProvider.notifier).reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download: $e')));
      }
    } finally {
      setState(() {
        _downloadProgress.remove(layer.name);
      });
    }
  }

  Future<void> _confirmDelete(CompatibilityLayer layer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Compatibility Layer'),
        content: Text('Are you sure you want to delete ${layer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteLayer(layer);
    }
  }

  Future<void> _deleteLayer(CompatibilityLayer layer) async {
    try {
      await ref
          .read(downloadedCompatibilityLayersProvider.notifier)
          .deleteLayer(layer);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${layer.name} deleted successfully')),
        );
      }

      // Refresh available layers to update isDownloaded status
      await ref.read(availableCompatibilityLayersProvider.notifier).reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  void _showLayerDetails(CompatibilityLayer layer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(layer.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    layer.type == CompatibilityLayerType.dxvk
                        ? Icons.layers
                        : Icons.filter_vintage,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          layer.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          layer.type.displayName,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Version', value: layer.version),
              _DetailRow(label: 'Size', value: layer.sizeFormatted),
              _DetailRow(
                label: 'Release Date',
                value:
                    '${layer.releaseDate.year}-${layer.releaseDate.month.toString().padLeft(2, '0')}-${layer.releaseDate.day.toString().padLeft(2, '0')}',
              ),
              _DetailRow(
                label: 'Status',
                value: layer.isDownloaded ? 'Downloaded' : 'Not Downloaded',
              ),
              if (layer.localPath != null)
                _DetailRow(label: 'Path', value: layer.localPath!),
              if (layer.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Release Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  layer.description.length > 200
                      ? '${layer.description.substring(0, 200)}...'
                      : layer.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
