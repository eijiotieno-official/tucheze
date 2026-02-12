import 'package:dartz/dartz.dart';
import 'package:logger/logger.dart';

import '../base/gpu_model.dart';
import 'gpu_native_service.dart';

/// Service class that provides a clean interface for GPU operations.
/// Uses Either from dartz to handle success and error states.
class GpuService {
  final GpuNativeService _nativeService;
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
  GpuService({GpuNativeService? nativeService})
    : _nativeService = nativeService ?? GpuNativeService();

  /// Retrieves a list of available GPUs on the system.
  ///
  /// Returns [Either<String, List<GPU>>]:
  /// - Left: Error message as String if operation fails
  /// - Right: List of GPU objects if operation succeeds
  Future<Either<String, List<GPU>>> getGpus() async {
    _logger.i('Attempting to retrieve GPU information...');

    try {
      final gpus = await _nativeService.listGpus();

      if (gpus.isEmpty) {
        _logger.w('No GPUs detected on the system');
        return left('No GPUs detected on the system');
      }

      _logger.i('Successfully retrieved ${gpus.length} GPU(s)');
      for (var i = 0; i < gpus.length; i++) {
        _logger.d('GPU $i: ${gpus[i].vendor} ${gpus[i].name}');
      }

      return right(gpus);
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to retrieve GPU information',
        error: e,
        stackTrace: stackTrace,
      );
      return left('Failed to retrieve GPU information: ${e.toString()}');
    }
  }
}
