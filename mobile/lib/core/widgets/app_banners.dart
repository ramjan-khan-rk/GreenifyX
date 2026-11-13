import 'dart:io';

import 'package:flutter/material.dart';

import '../i18n/app_locale.dart';
import '../services/offline_cache.dart';
import '../services/upload_queue.dart';
import '../theme/app_colors.dart';

/// Floating status pills drawn above every screen: upload progress and offline mode.
class AppBanners extends StatelessWidget {
  final Widget child;
  const AppBanners({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(children: [
      child,
      PositionedDirectional(
        top: top + 6,
        start: 12,
        end: 12,
        child: ValueListenableBuilder<List<UploadJob>>(
          valueListenable: UploadQueue.instance.jobs,
          builder: (context, jobs, _) => Column(mainAxisSize: MainAxisSize.min, children: [for (final j in jobs) _UploadPill(job: j)]),
        ),
      ),
      PositionedDirectional(
        bottom: MediaQuery.paddingOf(context).bottom + 92,
        start: 0,
        end: 0,
        child: ValueListenableBuilder<bool>(
          valueListenable: OfflineCache.offline,
          builder: (context, off, _) => IgnorePointer(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              offset: off ? Offset.zero : const Offset(0, 2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                opacity: off ? 1 : 0,
                child: Center(
                  child: Material(
                    color: AppColors.inkFixed,
                    borderRadius: BorderRadius.circular(30),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(tr("Offline · showing saved content"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _UploadPill extends StatelessWidget {
  final UploadJob job;
  const _UploadPill({required this.job});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.surface,
        elevation: 8,
        shadowColor: const Color(0x33000000),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: ValueListenableBuilder<UploadState>(
          valueListenable: job.state,
          builder: (context, st, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: job.thumbPath != null && !job.isVideo
                        ? Image.file(File(job.thumbPath!), fit: BoxFit.cover, cacheWidth: 120, errorBuilder: (_, _, _) => _thumbIcon())
                        : _thumbIcon(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      switch (st) {
                        UploadState.uploading => tr("Posting…"),
                        UploadState.failed => tr("Couldn't post"),
                        UploadState.done => tr("Posted"),
                      },
                      style: TextStyle(fontWeight: FontWeight.w800, color: st == UploadState.failed ? AppColors.error : AppColors.ink),
                    ),
                    Text(
                      st == UploadState.failed ? tr(job.error) : tr(job.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.subtitle),
                    ),
                  ]),
                ),
                if (st == UploadState.uploading)
                  ValueListenableBuilder<double>(
                    valueListenable: job.progress,
                    builder: (context, p, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text("${(p * 100).round()}%", style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                    ),
                  ),
                if (st == UploadState.done) const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.check_circle_rounded, color: AppColors.eco)),
                if (st == UploadState.failed) ...[
                  TextButton(onPressed: () => UploadQueue.instance.retry(job), child: Text(tr("Retry"))),
                  IconButton(onPressed: () => UploadQueue.instance.dismiss(job), icon: const Icon(Icons.close_rounded, size: 18)),
                ],
              ]),
            ),
            if (st == UploadState.uploading)
              ValueListenableBuilder<double>(
                valueListenable: job.progress,
                builder: (context, p, _) => LinearProgressIndicator(
                  value: p <= 0 ? null : p,
                  minHeight: 3,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _thumbIcon() => Container(
        color: AppColors.primary.withValues(alpha: 0.12),
        child: Icon(job.isVideo ? Icons.videocam_rounded : Icons.image_rounded, color: AppColors.primary, size: 20),
      );
}
