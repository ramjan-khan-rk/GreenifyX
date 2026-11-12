import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../campaign/presentation/screens/campaign_detail_screen.dart';
import '../campaign/presentation/widgets/campaign_visuals.dart';
import '../issues/presentation/issue_widgets.dart';
import '../issues/presentation/issues_hub_screen.dart';

Color hexColor(String? hex, [Color fallback = AppColors.eco]) {
  final h = (hex ?? '').replaceAll('#', '');
  if (h.length != 6) return fallback;
  return Color(int.parse('FF$h', radix: 16));
}

Future<void> openDirections(num lat, num lng) =>
    launchUrl(Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng"), mode: LaunchMode.externalApplication);

/// Renders one structured result returned by the assistant.
class AssistantCard extends StatelessWidget {
  final Map<String, dynamic> card;
  const AssistantCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    switch (card["type"]) {
      case "campaign":
        final style = categoryStyle(card["category"]?.toString() ?? "");
        return _Shell(
          icon: style.icon,
          color: style.from,
          title: card["title"]?.toString() ?? "",
          subtitle: "${card["subtitle"]} · +${card["points"]} pts",
          trailing: card["joined"] == true ? "Joined" : "${card["spotsLeft"]} spots",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaignId: card["id"].toString())),
          ),
        );
      case "place":
        return _Shell(
          icon: Icons.recycling_rounded,
          color: const Color(0xFF4A78B5),
          title: card["title"]?.toString() ?? "",
          subtitle: [
            card["subtitle"]?.toString() ?? "",
            if (card["distanceKm"] != null) "${card["distanceKm"]} km",
          ].where((s) => s.isNotEmpty).join(" · "),
          trailing: card["official"] == true ? "Official" : null,
          action: "Directions",
          onTap: () => openDirections(card["lat"] as num, card["lng"] as num),
        );
      case "report":
        return _Shell(
          icon: issueIcon(card["title"]?.toString() ?? ""),
          color: issueStatusColor(card["status"]?.toString() ?? ""),
          title: card["title"]?.toString() ?? "",
          subtitle: card["subtitle"]?.toString() ?? "",
          trailing: card["statusLabel"]?.toString(),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IssuesHubScreen())),
        );
      case "points":
        final recent = (card["recent"] as List? ?? const []).whereType<Map>().toList();
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.eco, Color(0xFF16664F)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${card["balance"]} Eco Points",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
            for (final t in recent.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("${(t["amount"] as num) > 0 ? '+' : ''}${t["amount"]}  ${t["reason"]}",
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ),
          ]),
        );
      case "guide":
        return GuideCard(data: card);
      default:
        return const SizedBox.shrink();
    }
  }
}

class GuideCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const GuideCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final color = hexColor(data["binColor"]?.toString());
    final prep = (data["prep"] as List? ?? const []).map((e) => e.toString()).toList();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: color,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.delete_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(data["bin"]?.toString() ?? "",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, height: 1.3)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data["title"]?.toString() ?? data["item"]?.toString() ?? "",
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
            if ((data["material"]?.toString() ?? "").isNotEmpty)
              Text(data["material"].toString(), style: const TextStyle(color: AppColors.subtitle, fontSize: 13)),
            if (prep.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var i = 0; i < prep.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Text("${i + 1}", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(prep[i], style: const TextStyle(height: 1.35))),
                  ]),
                ),
            ],
            if ((data["tip"]?.toString() ?? "").isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.sun),
                const SizedBox(width: 6),
                Expanded(child: Text(data["tip"].toString(), style: const TextStyle(color: AppColors.subtitle, fontSize: 13, height: 1.35))),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Shell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailing;
  final String? action;
  final VoidCallback onTap;

  const _Shell({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.subtitle)),
                ]),
              ),
              const SizedBox(width: 8),
              if (action != null)
                Text(action!, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12.5))
              else if (trailing != null)
                Text(trailing!, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5))
              else
                const Icon(Icons.chevron_right_rounded, color: AppColors.subtitle),
            ]),
          ),
        ),
      ),
    );
  }
}
