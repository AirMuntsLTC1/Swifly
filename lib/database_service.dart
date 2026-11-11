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

  Future<void> savePost(String text, String audience, List<String> taggedHandles, String? imagePath) async {
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
}
