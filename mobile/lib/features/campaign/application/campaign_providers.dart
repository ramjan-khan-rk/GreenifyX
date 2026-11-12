import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/campaign_api.dart';
import '../domain/campaign_model.dart';

final campaignApiProvider = Provider((ref) => CampaignApi());

/// filter: open | mine | past
final campaignsProvider = FutureProvider.family<List<CampaignModel>, String>((ref, filter) {
  return ref.read(campaignApiProvider).list(filter: filter);
});

final campaignDetailProvider = FutureProvider.family<CampaignModel, String>((ref, id) {
  return ref.read(campaignApiProvider).get(id);
});

final myPointsProvider = FutureProvider<List<PointsEntry>>((ref) {
  return ref.read(campaignApiProvider).myPoints();
});

final verifierCampaignsProvider = FutureProvider<List<CampaignModel>>((ref) {
  return ref.read(campaignApiProvider).verifierCampaigns();
});

final verifierReportsProvider = FutureProvider<List<MyReport>>((ref) {
  return ref.read(campaignApiProvider).verifierReports();
});
