import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/search_user_repository.dart';
import '../../domain/models/search_user_model.dart';

final searchRepositoryProvider =
Provider(
  (ref)=>SearchUserRepository(),
);

final searchUsersProvider =
FutureProvider.family<
List<SearchUserModel>,
String>((ref,keyword){

  return ref
      .read(searchRepositoryProvider)
      .searchUsers(keyword);

});