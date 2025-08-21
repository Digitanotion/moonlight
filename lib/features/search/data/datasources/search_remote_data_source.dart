import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/features/search/data/models/search_models.dart';

abstract class SearchRemoteDataSource {
  Future<List<dynamic>> search(String query);
  Future<List<TagModel>> getTrendingTags();
  Future<List<UserModel>> getSuggestedUsers();
  Future<List<ClubModel>> getPopularClubs();
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  @override
  Future<List<dynamic>> search(String query) async {
    // Simulate API call
    await Future.delayed(const Duration(milliseconds: 500));

    if (query.isEmpty) {
      return [];
    }

    // This would come from your API
    return [];
  }

  @override
  Future<List<TagModel>> getTrendingTags() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      TagModel(id: '1', name: '#AfrobeatLive', usageCount: 12500),
      TagModel(id: '2', name: '#CampusClubs', usageCount: 8900),
      TagModel(id: '3', name: '#Artwork', usageCount: 6700),
    ];
  }

  // Update the getSuggestedUsers method to match screenshot exactly
  @override
  Future<List<UserModel>> getSuggestedUsers() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      UserModel(
        id: '1',
        name: 'Desire John',
        username: 'desirejohn',
        avatarUrl: null,
        followersCount: 2400,
        isFollowing: false,
      ),
      UserModel(
        id: '2',
        name: 'Jane Doe',
        username: 'janedoe',
        avatarUrl: null,
        followersCount: 1800,
        isFollowing: false,
      ),
      UserModel(
        id: '3',
        name: 'Monday',
        username: 'petmo', // Changed to match screenshot exactly
        avatarUrl: null,
        followersCount: 3200,
        isFollowing: false,
      ),
    ];
  }

  // Update the getPopularClubs method to match screenshot exactly
  @override
  Future<List<ClubModel>> getPopularClubs() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      ClubModel(
        id: '1',
        name: 'Beat Makers',
        description: 'Music production community',
        membersCount: 2400, // 2.4k members as in screenshot
        coverImageUrl: null,
        isMember: false,
      ),
      ClubModel(
        id: '2',
        name: 'Digital Artis', // Note: This matches the screenshot spelling
        description: 'Digital art community',
        membersCount: 1800, // 1.8k members as in screenshot
        coverImageUrl: null,
        isMember: false,
      ),
    ];
  }
}
