import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/widgets/app_status.dart';
import '../../../profile/application/providers/my_profile_provider.dart';
import '../../application/campaign_providers.dart';
import '../../domain/campaign_model.dart';
import 'package:greenifyx/core/i18n/app_locale.dart';

class PointsHistoryScreen extends ConsumerWidget {
  const PointsHistoryScreen({super.key});

  static final _fmt = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(myPointsProvider);
    final balance = ref.watch(myProfileProvider).maybeWhen(data: (p) => p.ecoPoints, orElse: () => null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(tr("Eco Points"), style: AppTextStyles.title)),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(myPointsProvider);
          ref.invalidate(myProfileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [AppColors.eco, Color(0xFF16664F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr("Balance"), style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                    const SizedBox(height: 4),
                    Text(balance == null ? "—" : NumberFormat.decimalPattern().format(balance),
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(tr("Credited only for verified actions"),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
                  ]),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.stars_rounded, color: AppColors.sun, size: 32),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Text(tr("History"), style: AppTextStyles.title.copyWith(fontSize: 17)),
            const SizedBox(height: 10),
            history.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: AppLoading()),
              error: (e, _) => AppErrorState(
                message: friendlyError(e, fallback: "Could not load your history."),
                onRetry: () => ref.invalidate(myPointsProvider),
              ),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: AppEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: tr("No points yet"),
                        message: tr("Join a campaign or get a post verified by a friend to earn your first Eco Points."),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(children: [
                        for (var i = 0; i < items.length; i++) ...[
                          _EntryTile(e: items[i], date: _fmt.format(items[i].createdAt)),
                          if (i < items.length - 1) const Divider(height: 1, indent: 64),
                        ],
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final PointsEntry e;
  final String date;
  const _EntryTile({required this.e, required this.date});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (e.type) {
      "campaign_verified" => (Icons.forest_rounded, AppColors.eco),
      "post_verified" => (Icons.verified_rounded, const Color(0xFF4A78B5)),
      "challenge_won" => (Icons.emoji_events_rounded, const Color(0xFF8A5A00)),
      "report_resolved" => (Icons.report_gmailerrorred_rounded, AppColors.primary),
      "reversal" => (Icons.undo_rounded, AppColors.error),
      _ => (Icons.tune_rounded, AppColors.subtitle),
    };
    final positive = e.amount > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        e.reason.isNotEmpty ? e.reason : e.campaignTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 14),
      ),
      subtitle: Text(e.status == "reversed" ? "$date · reversed" : date, style: const TextStyle(fontSize: 12.5)),
      trailing: Text(
        "${positive ? '+' : ''}${e.amount}",
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 16,
          color: positive ? AppColors.eco : AppColors.error,
          decoration: e.status == "reversed" ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
