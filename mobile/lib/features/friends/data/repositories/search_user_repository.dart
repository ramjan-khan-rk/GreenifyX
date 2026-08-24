import 'package:flutter/foundation.dart';
import '../../domain/models/search_user_model.dart';
import '../api/search_user_api.dart';

class SearchUserRepository {
  final SearchUserApi _api = SearchUserApi();

  Future<List<SearchUserModel>> searchUsers(
    String keyword,
  ) async {

    final response =
        await _api.searchUsers(keyword);

    debugPrint("RAW RESPONSE:");
    debugPrint(response.toString());

    final users = response
        .map<SearchUserModel>(
          (json) => SearchUserModel.fromJson(json),
        )
        .toList();

    debugPrint("PARSED USERS:");
    debugPrint(users.length.toString());

    for (final u in users) {
      debugPrint(u.name);
    }

    return users;
  }
}