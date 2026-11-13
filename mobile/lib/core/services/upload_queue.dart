import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';

enum UploadState { uploading, failed, done }

/// One post (or story) being sent in the background.
class UploadJob {
  final String path;
  final String label;
  final String? thumbPath;
  final bool isVideo;

  /// Built fresh for every attempt because a FormData can only be sent once.
  final Future<FormData> Function() build;

  final progress = ValueNotifier<double>(0);
  final state = ValueNotifier<UploadState>(UploadState.uploading);
  String error = "";

  UploadJob({required this.path, required this.label, required this.build, this.thumbPath, this.isVideo = false});
}

/// Posts upload behind the scenes while people keep scrolling, with a live
/// progress bar, automatic retries on a flaky network and a one-tap Retry.
class UploadQueue {
  UploadQueue._();
  static final instance = UploadQueue._();

  final jobs = ValueNotifier<List<UploadJob>>(const []);

  /// Bumps after every successful upload, so the feed can refresh itself.
  final completed = ValueNotifier<int>(0);

  void enqueue(UploadJob job) {
    jobs.value = [...jobs.value, job];
    _run(job);
  }

  void retry(UploadJob job) {
    job.progress.value = 0;
    job.state.value = UploadState.uploading;
    _run(job);
  }

  void dismiss(UploadJob job) => jobs.value = jobs.value.where((j) => j != job).toList();

  Future<void> _run(UploadJob job) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final form = await job.build();
        await ApiService.dio.post(
          job.path,
          data: form,
          options: Options(sendTimeout: const Duration(minutes: 5), receiveTimeout: const Duration(minutes: 2)),
          onSendProgress: (sent, total) {
            if (total > 0) job.progress.value = (sent / total).clamp(0, 0.98);
          },
        );
        job.progress.value = 1;
        job.state.value = UploadState.done;
        completed.value++;
        Future.delayed(const Duration(seconds: 3), () => dismiss(job));
        return;
      } on DioException catch (e) {
        final transient = e.response == null || (e.response!.statusCode ?? 0) >= 500;
        job.error = _message(e);
        if (!transient || attempt == 2) break;
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      } catch (e) {
        job.error = e is FileSystemException ? "The photo or video is no longer on the phone." : "Couldn't post. Tap retry.";
        break;
      }
    }
    job.state.value = UploadState.failed;
  }

  static String _message(DioException e) {
    final d = e.response?.data;
    if (d is Map && d["message"] is String) return d["message"] as String;
    return e.response == null ? "No connection. Tap retry when you're back online." : "Couldn't post. Tap retry.";
  }
}
