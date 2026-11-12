import 'package:flutter/foundation.dart';

class UploadManager extends ChangeNotifier {
  UploadManager._();
  static final UploadManager instance = UploadManager._();

  bool _isUploading = false;
  bool _isSuccess = false;
  String? _thumbnailPath;

  bool get isUploading => _isUploading;
  bool get isSuccess => _isSuccess;
  String? get thumbnailPath => _thumbnailPath;

  void start(String? thumbnail) {
    _isUploading = true;
    _isSuccess = false;
    _thumbnailPath = thumbnail;
    notifyListeners();
  }

  void success() {
    _isUploading = false;
    _isSuccess = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
      _isSuccess = false;
      _thumbnailPath = null;
      notifyListeners();
    });
  }
}
