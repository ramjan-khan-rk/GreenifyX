import 'package:flutter/material.dart';

import '../api/admin_api.dart';
import '../core/format.dart';
import '../core/theme.dart';

/// Page header with title, subtitle and optional actions on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12,
        spacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: t.bodyMedium?.copyWith(color: Brand.muted)),
              ],
            ],
          ),
          if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// White card with an optional title row.
class Panel extends StatelessWidget {
  const Panel({super.key, this.title, this.trailing, required this.child, this.padding = const EdgeInsets.all(20)});
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(title!,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = Brand.coral,
    this.caption,
    this.delta,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;

  /// Percentage change vs previous period; null hides the badge.
  final int? delta;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const Spacer(),
                if (delta != null) _DeltaBadge(delta!),
              ],
            ),
            const SizedBox(height: 14),
            Text(value, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 4),
            Text(label, style: t.bodyMedium?.copyWith(color: Brand.muted, fontWeight: FontWeight.w600)),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(caption!, style: t.bodySmall?.copyWith(color: Brand.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge(this.delta);
  final int delta;

  @override
  Widget build(BuildContext context) {
    final up = delta >= 0;
    final color = up ? Brand.eco : Brand.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text('${up ? '+' : ''}$delta%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color = Brand.muted});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url, required this.name, this.size = 36});
  final String? url;
  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Brand.blush, shape: BoxShape.circle),
      child: Text(_initials,
          style: TextStyle(color: Brand.coral, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});
  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Brand.muted.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: t.bodyMedium?.copyWith(color: Brand.muted), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Brand.danger),
          const SizedBox(height: 12),
          Text(error is ApiError ? error.toString() : 'Something went wrong.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
        ],
      ),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
}

/// Prev / next pager with a "1–20 of 134" label.
class Pager extends StatelessWidget {
  const Pager({super.key, required this.page, required this.pages, required this.total, required this.limit, required this.onPage});
  final int page;
  final int pages;
  final int total;
  final int limit;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : (page - 1) * limit + 1;
    final to = (page * limit).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text('${Fmt.number(from)}–${Fmt.number(to)} of ${Fmt.number(total)}',
              style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => onPage(page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text('$page / $pages', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < pages ? () => onPage(page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// Lays children in a responsive grid: as many columns as fit [minWidth].
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.minWidth = 220, this.gap = 16, this.maxColumns = 4});
  final List<Widget> children;
  final double minWidth;
  final double gap;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = (c.maxWidth / minWidth).floor().clamp(1, maxColumns);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    });
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'ongoing':
      return Brand.sky;
    case 'completed':
      return Brand.eco;
    case 'pending':
      return Brand.sun;
    case 'rejected':
    case 'expired':
      return Brand.muted;
    default:
      return Brand.muted;
  }
}
