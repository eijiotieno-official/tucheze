import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A reusable widget for handling asynchronous states (`AsyncValue`) like data, loading, and error.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.asyncValue,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
    this.backgroundColor,
  });

  /// Function to build the UI for error states.
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  /// The current asynchronous value representing the state.
  final AsyncValue<T> asyncValue;

  /// Function to build the UI when data is available.
  final Widget Function(T data) builder;

  /// Optional custom widget to display during loading.
  final Widget? loadingWidget;

  /// Optional background color for the widget.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: backgroundColor ?? theme.scaffoldBackgroundColor,
      child: asyncValue.when(
        // Render the builder for the data state.
        data: (data) => builder(data)
            .animate()
            .fadeIn(duration: 300.ms),

        // Display the custom loading widget or a default progress indicator.
        loading: () =>
            loadingWidget ??
            Center(child: CircularProgressIndicator(strokeCap: StrokeCap.round))
                .animate()
                .fadeIn(duration: 700.ms)
                .scale(delay: 100.ms, duration: 300.ms),

        // Render the custom error builder or a default error message.
        error: (error, stackTrace) =>
            errorBuilder?.call(error, stackTrace) ??
            Center(
                  child: SelectableText(
                    error.toString(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                )
                .animate()
                .fadeIn(duration: 300.ms),
      ),
    );
  }
}
