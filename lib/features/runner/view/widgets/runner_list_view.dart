import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_view.dart';
import '../../model/base/runner_model.dart';
import '../../model/enum/runner_type.dart';
import '../../view_model/available_runners_view_model.dart';
import '../../view_model/downloaded_runners_view_model.dart';
import '../../view_model/selected_runner_type_view_model.dart';

class RunnerListView extends ConsumerStatefulWidget {
  const RunnerListView({super.key});

  @override
  ConsumerState<RunnerListView> createState() => _RunnerListViewState();
}

class _RunnerListViewState extends ConsumerState<RunnerListView> {
  final Map<String, double> _downloadProgress = {};

  @override
  Widget build(BuildContext context) {
    final availableRunnersAsync = ref.watch(availableRunnersProvider);

    return Expanded(
      child: AsyncView(
        asyncValue: availableRunnersAsync,
        builder: (availableRunners) {
          if (availableRunners.isEmpty) {
            return const Center(child: Text('No runners available'));
          }

          final runnerTypes = RunnerType.values;
          final selectedRunnerType = ref.watch(selectedRunnerTypeProvider);

          final runners = availableRunners
              .where((runner) => runner.type == selectedRunnerType)
              .toList();

          return Column(
            spacing: 16.0,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16.0,
                children: runnerTypes.map((type) {
                  final isSelected = type == selectedRunnerType;
                  return ChoiceChip(
                    label: Text(type.displayName),
                    selected: isSelected,
                    onSelected: (_) {
                      ref
                          .read(selectedRunnerTypeProvider.notifier)
                          .setRunnerType(type);
                    },
                  );
                }).toList(),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(availableRunnersProvider.notifier).reload();
                  },
                  child: ListView.builder(
                    itemCount: runners.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final runner = runners[index];
                      return _buildRunnerCard(runner);
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

  Widget _buildRunnerCard(Runner runner) {
    final progress = _downloadProgress[runner.name];
    final isDownloading = progress != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            runner.type == RunnerType.protonGE
                ? Icons.games
                : runner.type == RunnerType.lutrisWine
                ? Icons.sports_esports
                : Icons.wine_bar,
          ),
        ),
        title: Text(
          runner.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${runner.type.displayName} • ${runner.sizeFormatted}'),
            if (runner.localPath != null)
              Text(
                'Path: ${runner.localPath}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            if (isDownloading)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(value: progress),
              ),
          ],
        ),
        trailing: runner.isDownloaded
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(runner),
              )
            : isDownloading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.download, color: Colors.blue),
                onPressed: () => _downloadRunner(runner),
              ),
        onTap: () => _showRunnerDetails(runner),
      ),
    );
  }

  Future<void> _downloadRunner(Runner runner) async {
    setState(() {
      _downloadProgress[runner.name] = 0.0;
    });

    try {
      await ref.read(availableRunnersProvider.notifier).downloadRunner(runner, (
        progress,
      ) {
        setState(() {
          _downloadProgress[runner.name] = progress;
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${runner.name} downloaded successfully')),
        );
      }

      // Refresh downloaded runners list
      await ref.read(downloadedRunnersProvider.notifier).reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download: $e')));
      }
    } finally {
      setState(() {
        _downloadProgress.remove(runner.name);
      });
    }
  }

  Future<void> _confirmDelete(Runner runner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Runner'),
        content: Text('Are you sure you want to delete ${runner.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(downloadedRunnersProvider.notifier).deleteRunner(runner);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${runner.name} deleted')));
        }

        // Refresh available runners to update downloaded status
        await ref.read(availableRunnersProvider.notifier).reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  void _showRunnerDetails(Runner runner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    runner.type == RunnerType.protonGE
                        ? Icons.games
                        : runner.type == RunnerType.lutrisWine
                        ? Icons.sports_esports
                        : Icons.wine_bar,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          runner.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          runner.type.displayName,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildDetailRow('Version', runner.version),
              _buildDetailRow('Size', runner.sizeFormatted),
              _buildDetailRow(
                'Released',
                '${runner.releaseDate.year}-${runner.releaseDate.month.toString().padLeft(2, '0')}-${runner.releaseDate.day.toString().padLeft(2, '0')}',
              ),
              if (runner.localPath != null)
                _buildDetailRow('Path', runner.localPath!),
              _buildDetailRow(
                'Status',
                runner.isDownloaded ? 'Downloaded' : 'Not Downloaded',
              ),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                runner.description.isNotEmpty
                    ? runner.description
                    : 'No description available',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
