import '../../domain/models/friend_model.dart';
import '../api/friend_api.dart';

class FriendRepository {

  final FriendApi api = FriendApi();

  Future<void> sendRequest(String userId) {
    return api.sendRequest(userId);
  }

  Future<void> acceptRequest(String userId) {
    return api.acceptRequest(userId);
  }

  Future<List<FriendModel>> getFriends() async {

    final data = await api.getFriends();

    return data
        .map((e) => FriendModel.fromJson(e))
        .toList();

  }

  Future<List<FriendModel>> getRequests() async {

    final data = await api.getRequests();

    return data
        .map((e) => FriendModel.fromJson(e))
        .toList();

  }

}