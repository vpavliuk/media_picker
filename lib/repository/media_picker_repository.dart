import 'dart:typed_data';

import 'package:media_picker/bloc/media_picker_item_range.dart';

final class MediaPickerAlbumInfo {
  final int itemCount;
  final Map<int, Uint8List> thumbnails;

  const MediaPickerAlbumInfo({
    required this.itemCount,
    required this.thumbnails,
  });
}

abstract class MediaPickerRepository {
  Stream<MediaPickerAlbumInfo> get masterAlbumStream;

  Future<void> requestThumbnails({
    required MediaPickerItemRange range,
    required bool handleInReverse,
  });
}
