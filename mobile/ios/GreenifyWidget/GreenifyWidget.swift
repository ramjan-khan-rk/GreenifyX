// GreenifyX home-screen widget for iPhone (WidgetKit).
// Add it in Xcode as a Widget Extension target named "GreenifyWidget" (see docs/IOS_BUILD.md),
// with the App Group "group.com.ramjankhan.greenifyx" on both the app and the widget.
import SwiftUI
import WidgetKit

private let appGroup = "group.com.ramjankhan.greenifyx"

struct GreenifyEntry: TimelineEntry {
  let date: Date
  let streak: Int
  let points: Int
  let habit: Int
  let streakLabel: String
  let pointsLabel: String
}

struct GreenifyProvider: TimelineProvider {
  private func read() -> GreenifyEntry {
    let d = UserDefaults(suiteName: appGroup)
    return GreenifyEntry(
      date: Date(),
      streak: d?.integer(forKey: "gx_streak") ?? 0,
      points: d?.integer(forKey: "gx_points") ?? 0,
      habit: d?.integer(forKey: "gx_habit") ?? 0,
      streakLabel: d?.string(forKey: "gx_label_streak") ?? "day streak",
      pointsLabel: d?.string(forKey: "gx_label_points") ?? "Eco Points"
    )
  }

  func placeholder(in context: Context) -> GreenifyEntry {
    GreenifyEntry(date: Date(), streak: 7, points: 420, habit: 3, streakLabel: "day streak", pointsLabel: "Eco Points")
  }

  func getSnapshot(in context: Context, completion: @escaping (GreenifyEntry) -> Void) {
    completion(read())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GreenifyEntry>) -> Void) {
    // The app refreshes the widget whenever the numbers change; hourly as a fallback.
    completion(Timeline(entries: [read()], policy: .after(Date().addingTimeInterval(3600))))
  }
}

struct GreenifyWidgetView: View {
  let entry: GreenifyEntry

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 2) {
        Text("🔥 \(entry.streak)").font(.title2).bold()
        Text(entry.streakLabel).font(.caption).opacity(0.8)
      }
      Spacer()
      VStack(alignment: .leading, spacing: 2) {
        Text("\(entry.points)").font(.title2).bold()
        Text(entry.pointsLabel).font(.caption).opacity(0.8)
      }
      Spacer()
      Text("✅ \(entry.habit)").font(.headline)
    }
    .foregroundColor(.white)
    .padding()
    .containerBackground(for: .widget) {
      LinearGradient(colors: [Color(red: 0.12, green: 0.54, blue: 0.44), Color(red: 0.07, green: 0.6, blue: 0.56)], startPoint: .leading, endPoint: .trailing)
    }
  }
}

@main
struct GreenifyWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "GreenifyWidget", provider: GreenifyProvider()) { entry in
      GreenifyWidgetView(entry: entry)
    }
    .configurationDisplayName("GreenifyX")
    .description("Your streak, Eco Points and daily habits.")
    .supportedFamilies([.systemMedium])
  }
}
