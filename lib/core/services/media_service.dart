import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  Future<String> getMediaStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${directory.path}/media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir.path;
  }

  Future<MediaFile?> capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: AppConstants.imageQuality,
      );

      if (photo == null) return null;

      return await _processMediaFile(photo, MediaTypes.image);
    } catch (e) {
      throw Exception('Failed to capture photo: ${e.toString()}');
    }
  }

  Future<MediaFile?> captureVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: Duration(seconds: AppConstants.maxVideoDurationSeconds),
      );

      if (video == null) return null;

      return await _processMediaFile(video, MediaTypes.video);
    } catch (e) {
      throw Exception('Failed to capture video: ${e.toString()}');
    }
  }

  Future<MediaFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: AppConstants.imageQuality,
      );

      if (image == null) return null;

      return await _processMediaFile(image, MediaTypes.image);
    } catch (e) {
      throw Exception('Failed to pick image: ${e.toString()}');
    }
  }

  Future<MediaFile?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) return null;

      return await _processMediaFile(video, MediaTypes.video);
    } catch (e) {
      throw Exception('Failed to pick video: ${e.toString()}');
    }
  }

  Future<MediaFile> _processMediaFile(XFile file, String mediaType) async {
    final fileSize = await File(file.path).length();

    // Validate file size
    if (mediaType == MediaTypes.image) {
      if (fileSize > AppConstants.maxImageSizeMB * 1024 * 1024) {
        throw Exception(ErrorMessages.fileTooLarge);
      }
    } else {
      if (fileSize > AppConstants.maxVideoSizeMB * 1024 * 1024) {
        throw Exception(ErrorMessages.fileTooLarge);
      }
    }

    // Generate unique filename
    final extension = file.path.split('.').last;
    final filename = '${_uuid.v4()}.$extension';
    
    // Get storage path
    final storagePath = await getMediaStoragePath();
    final newPath = '$storagePath/$filename';

    // Copy file to app storage
    await File(file.path).copy(newPath);

    return MediaFile(
      path: newPath,
      type: mediaType,
      size: fileSize,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> deleteMediaFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log error but don't throw
      print('Failed to delete file: ${e.toString()}');
    }
  }

  Future<int> getDirectorySize() async {
    final storagePath = await getMediaStoragePath();
    final dir = Directory(storagePath);
    
    int totalSize = 0;
    if (await dir.exists()) {
      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    
    return totalSize;
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> clearOldMedia(int daysOld) async {
    final storagePath = await getMediaStoragePath();
    final dir = Directory(storagePath);
    
    if (await dir.exists()) {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      await for (var entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
          }
        }
      }
    }
  }
}

class MediaFile {
  final String path;
  final String type;
  final int size;
  final int timestamp;

  MediaFile({
    required this.path,
    required this.type,
    required this.size,
    required this.timestamp,
  });
}
