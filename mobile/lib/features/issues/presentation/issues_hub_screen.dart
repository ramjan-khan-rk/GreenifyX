import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/widgets/app_status.dart';
import '../data/issue_api.dart';
import 'issue_widgets.dart';
import 'report_issue_screen.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class IssuesHubScreen extends ConsumerWidget {
  const IssuesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr("Report & Restore"), style: AppTextStyles.title),
            Text(tr("Spot it. Report it. Track it."), style: AppTextStyles.tagline),
          ]),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.subtitle,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [Tab(text: "My reports"), Tab(text: "In my area")],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportIssueScreen())),
          icon: const Icon(Icons.add_a_photo_rounded),
          label: Text(tr("Report a problem")),
        ),
        body: const TabBarView(children: [_Mine(), _Nearby()]),
      ),
    );
  }
}

class _Mine extends ConsumerWidget {
  const _Mine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myIssuesProvider).when(
          loading: () => const AppLoading(),
          error: (e, _) => AppErrorState(
            message: friendlyError(e, fallback: "Could not load your reports."),
            onRetry: () => ref.invalidate(myIssuesProvider),
          ),
          data: (items) => items.isEmpty
              ? AppEmptyState(
                  icon: Icons.report_gmailerrorred_rounded,
                  title: tr("Nothing reported yet"),
                  message: tr("Seen illegal dumping, an overflowing bin or pollution? Snap a photo and we'll track it to resolution."),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.invalidate(myIssuesProvider),
                  child: ListView(
                    padding: const EdgeInsets.only(top: 16, bottom: 100),
                    children: [for (final r in items) IssueCard(report: r)],
                  ),
                ),
        );
  }
}

class _Nearby extends ConsumerStatefulWidget {
  const _Nearby();

  @override
  ConsumerState<_Nearby> createState() => _NearbyState();
}

class _NearbyState extends ConsumerState<_Nearby> {
  final Set<String> _busy = {};

  Future<void> _confirm(String id) async {
    setState(() => _busy.add(id));
    try {
      await ref.read(issueApiProvider).confirm(id);
      ref.invalidate(nearbyIssuesProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(nearbyIssuesProvider).when(
          loading: () => const AppLoading(),
          error: (e, _) => AppErrorState(
            message: friendlyError(e, fallback: "Could not load reports."),
            onRetry: () => ref.invalidate(nearbyIssuesProvider),
          ),
          data: (items) {
            final others = items.where((r) => !r.isMine).toList();
            if (others.isEmpty) {
              return AppEmptyState(
                icon: Icons.check_circle_rounded,
                title: tr("All clear around you"),
                message: tr("No open reports from other residents right now."),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(nearbyIssuesProvider),
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 100),
                children: [
                  for (final r in others)
                    IssueCard(report: r, busy: _busy.contains(r.id), onConfirm: () => _confirm(r.id)),
                ],
              ),
            );
          },
        );
  }
}
