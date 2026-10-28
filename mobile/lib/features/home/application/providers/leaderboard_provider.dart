import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/api/profile_api.dart';
import '../../domain/models/leaderboard_entry.dart';

final leaderboardProvider =
    FutureProvider<List<LeaderboardEntry>>((ref) async {
  final rows = await ProfileApi().getLeaderboard();
  return rows.map(LeaderboardEntry.fromJson).toList();
});
