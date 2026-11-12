import 'package:flutter/foundation.dart';

/// This is the ONLY file you need to edit when connecting to Firebase, Supabase, or a REST API.
/// Currently, it simulates network delays so the UI works exactly as it does now.
class DatabaseService {
  static final DatabaseService instance = DatabaseService._();
  DatabaseService._();

  // TODO: Replace these with real API calls
  Future<void> fetchPosts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Example: final response = await http.get(Uri.parse('https://api.swifly.com/posts'));
  }

  Future<void> savePost(String text, String audience, List<String> taggedHandles, List<String> mediaPaths) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> toggleLike(String postId, bool isLiked) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> toggleSave(String postId, bool isSaved) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> addComment(String postId, String text) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> toggleFollow(String handle, bool isFollowing) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  /// Saves one profile field and who can see it.
  Future<void> saveProfileField(String key, String value, String audience) async {
    await Future.delayed(const Duration(milliseconds: 150));
    // Example: await supabase.from('profiles').update({key: value, '${key}_audience': audience}).eq('handle', kMeHandle);
  }

  /// Uploads a new profile picture from a local file path.
  Future<void> uploadAvatar(String localPath) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Example: upload the file to storage, then save its URL on the profile.
  }
}
