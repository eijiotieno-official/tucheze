import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_view.dart';
import '../../model/base/performance_tool_model.dart';
import '../../model/enum/performance_tool_type.dart';
import '../../view_model/performance_tools_view_model.dart';

class PerformanceToolsWidget extends ConsumerWidget {
  const PerformanceToolsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolsAsync = ref.watch(performanceToolsProvider);

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.speed, size: 24),
                SizedBox(width: 8),
                Text(
                  'Performance Tools',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AsyncView(
              asyncValue: toolsAsync,
              builder: (tools) {
                return Column(
                  children: tools.map((tool) {
                    return _PerformanceToolCard(tool: tool);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformanceToolCard extends ConsumerStatefulWidget {
  final PerformanceTool tool;

  const _PerformanceToolCard({required this.tool});

  @override
  ConsumerState<_PerformanceToolCard> createState() =>
      _PerformanceToolCardState();
}

class _PerformanceToolCardState extends ConsumerState<_PerformanceToolCard> {
  bool _isInstalling = false;

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;

    // Select icon based on tool type
    IconData icon;
    switch (tool.type) {
      case PerformanceToolType.mangoHud:
        icon = Icons.dashboard;
        break;
      case PerformanceToolType.gameMode:
        icon = Icons.flash_on;
        break;
      case PerformanceToolType.vkBasalt:
        icon = Icons.filter_vintage;
        break;
      case PerformanceToolType.cpuGovernor:
        icon = Icons.speed;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              icon,
              size: 32,
              color: tool.isDownloaded
                  ? (tool.isEnabled ? Colors.green : Colors.grey)
                  : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tool.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (!tool.isDownloaded)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Not installed',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (tool.isDownloaded)
              Row(
                children: [
                  Text(
                    tool.isEnabled ? 'Enabled' : 'Disabled',
                    style: TextStyle(
                      fontSize: 12,
                      color: tool.isEnabled ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: tool.isEnabled,
                    onChanged: (value) => _toggleTool(tool, value),
                  ),
                ],
              )
            else
              _isInstalling
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _installTool(tool),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Install'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTool(PerformanceTool tool, bool enabled) async {
    try {
      switch (tool.type) {
        case PerformanceToolType.mangoHud:
          await ref
              .read(performanceToolsProvider.notifier)
              .toggleMangoHud(enabled);
          break;
        case PerformanceToolType.gameMode:
          await ref
              .read(performanceToolsProvider.notifier)
              .toggleGameMode(enabled);
          break;
        case PerformanceToolType.vkBasalt:
          await ref
              .read(performanceToolsProvider.notifier)
              .toggleVkBasalt(enabled);
          break;
        case PerformanceToolType.cpuGovernor:
          await ref
              .read(performanceToolsProvider.notifier)
              .toggleCpuGovernor(enabled);
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tool.type.displayName} ${enabled ? 'enabled' : 'disabled'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle ${tool.type.displayName}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _installTool(PerformanceTool tool) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Install ${tool.type.displayName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will install ${tool.type.displayName} using your system package manager.',
            ),
            const SizedBox(height: 12),
            Text(
              tool.description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You will be prompted for your password',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Install'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isInstalling = true;
    });

    try {
      switch (tool.type) {
        case PerformanceToolType.mangoHud:
          await ref.read(performanceToolsProvider.notifier).installMangoHud();
          break;
        case PerformanceToolType.gameMode:
          await ref.read(performanceToolsProvider.notifier).installGameMode();
          break;
        case PerformanceToolType.vkBasalt:
          await ref.read(performanceToolsProvider.notifier).installVkBasalt();
          break;
        case PerformanceToolType.cpuGovernor:
          await ref
              .read(performanceToolsProvider.notifier)
              .installCpuGovernor();
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tool.type.displayName} installation initiated. Please check your package manager.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to install ${tool.type.displayName}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
      }
    }
  }
}
