import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/profile_model.dart';
import '../../data/repository/profile_repository.dart';
import 'profile_provider.dart';

final myProfileProvider =
FutureProvider<ProfileModel>((ref) {

  return ref
      .read(profileRepositoryProvider)
      .getProfile();

});