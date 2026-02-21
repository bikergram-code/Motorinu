import '../../domain/models/user.dart';
import '../../domain/models/follow.dart';
import '../datasources/remote/bikergram_api_service.dart';

class UserRepository {
  UserRepository({required BikergramApiService apiService})
      : _api = apiService;

  final BikergramApiService _api;

  Future<User> getUser(int userId) async {
    final data = await _api.getUser(userId);
    return User.fromJson(data);
  }

  Future<User> updateProfile(Map<String, dynamic> updates) async {
    final data = await _api.updateProfile(updates);
    final userData = data['user'] ?? data;
    return User.fromJson(userData as Map<String, dynamic>);
  }

  Future<List<UserSummary>> searchUsers(String query) async {
    final data = await _api.searchUsers(query);
    return data
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> follow(int userId) => _api.follow(userId);

  Future<void> unfollow(int userId) => _api.unfollow(userId);

  Future<List<UserSummary>> getFollowers(int userId, {int page = 1}) async {
    final data = await _api.getFollowers(userId, page: page);
    return data
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserSummary>> getFollowing(int userId, {int page = 1}) async {
    final data = await _api.getFollowing(userId, page: page);
    return data
        .map((e) => UserSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
