import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:photo_gallery/photo_gallery.dart';
import 'package:worker_manager/worker_manager.dart';

import '../bloc/media_picker_item_range.dart';
import 'media_picker_repository.dart';

final class MediaPickerConcurrentRepositoryImpl
    implements MediaPickerRepository {
  MediaPickerConcurrentRepositoryImpl();

  late final _thumbnailStreamController =
      StreamController<MediaPickerAlbumInfo>(
          onListen: () => _setUpAlbumIfNeeded());

  bool _isAlbumSetUp = false;
  Album? _album;
  final Map<int, List<int>> _preparedThumbnails = {};
  final Set<int> _pendingMedia = {};
  final _rootIsolateToken = RootIsolateToken.instance!;

  @override
  Stream<MediaPickerAlbumInfo> get masterAlbumStream =>
      _thumbnailStreamController.stream;

  @override
  Future<void> requestThumbnails({
    required MediaPickerItemRange range,
    required bool handleInReverse,
  }) async {
    await _setUpAlbumIfNeeded();
    _handleThumbnailsRequest(range: range, handleInReverse: handleInReverse);
  }

  Future<void> _setUpAlbumIfNeeded() async {
    if (_isAlbumSetUp) {
      return;
    }
    _isAlbumSetUp = true;

    final albums = await PhotoGallery.listAlbums();
    Album? mainAlbum;
    try {
      mainAlbum = albums.firstWhere((album) => album.isAllAlbum);
    } catch (_) {
      return;
    }

    _album = mainAlbum;

    final initialAlbumInfo = MediaPickerAlbumInfo(
      itemCount: mainAlbum.count,
      thumbnails: const {},
    );
    _thumbnailStreamController.add(initialAlbumInfo);
  }

  Future<void> _handleThumbnailsRequest({
    required MediaPickerItemRange range,
    required bool handleInReverse,
  }) async {
    const maxRangeLength = 25;
    final smallRanges = _breakDownItemRange(
      range,
      reverseOrder: handleInReverse,
      maxLength: maxRangeLength,
    );

    _pendingMedia.addAll(smallRanges.expand((r) => r.allIndices));

    final comparator = handleInReverse
        ? (int a, int b) => b.compareTo(a)
        : (int a, int b) => a.compareTo(b);
    // Using SplayTreeMap to support definitive order of thumbnails being generated
    final mediaItems = SplayTreeMap<int, Medium>(comparator);
    for (final range in smallRanges) {
      final items = await _mediaItemsFromRange(range);
      mediaItems.addAll(items);
    }

    await _handleMediaItems(mediaItems);
  }

  Iterable<MediaPickerItemRange> _breakDownItemRange(
    MediaPickerItemRange itemRange, {
    required bool reverseOrder,
    required int maxLength,
  }) {
    final List<MediaPickerItemRange> subRanges = [];
    int? currentSmallRangeStart;
    for (final index in itemRange.allIndices) {
      if (_preparedThumbnails[index] != null || _pendingMedia.contains(index)) {
        if (currentSmallRangeStart != null) {
          subRanges.add(
            MediaPickerItemRange(
              start: currentSmallRangeStart,
              length: index - currentSmallRangeStart,
            ),
          );
          currentSmallRangeStart = null;
        }
        continue;
      }
      if (currentSmallRangeStart == null) {
        currentSmallRangeStart = index;
      } else {
        final currentLength = index - currentSmallRangeStart;
        if (currentLength == maxLength) {
          subRanges.add(
            MediaPickerItemRange(
              start: currentSmallRangeStart,
              length: maxLength,
            ),
          );
          currentSmallRangeStart = index;
        }
      }
    }
    if (currentSmallRangeStart != null) {
      subRanges.add(
        MediaPickerItemRange(
          start: currentSmallRangeStart,
          length: itemRange.end - currentSmallRangeStart + 1,
        ),
      );
    }
    return reverseOrder
        ? List.unmodifiable(subRanges.reversed)
        : List.unmodifiable(subRanges);
  }

  Future<Map<int, Medium>> _mediaItemsFromRange(
      MediaPickerItemRange itemRange) async {
    final album = _album;
    if (album == null) {
      return {};
    }
    final Map<int, Medium> mediaItems = {};
    final mediaPage = await album.listMedia(
      skip: itemRange.start,
      take: itemRange.length,
    );
    for (final (index, medium) in mediaPage.items.indexed) {
      mediaItems[itemRange.start + index] = medium;
    }
    return mediaItems;
  }

  Future<void> _handleMediaItems(SplayTreeMap<int, Medium> mediaItems) async {
    // Lo Res Thumbnails:
    final loResStream = _makeThumbnails(
      mediaItems: mediaItems,
      isHiRes: true,
      rootIsolateToken: _rootIsolateToken,
    );
    await for (final entry in loResStream) {
      _preparedThumbnails[entry.key] = entry.value;
      _pendingMedia.remove(entry.key);
      _emitState();
    }

    // // Hi Res Thumbnails:
    // final hiResStream = _makeThumbnails(
    //   mediaItems: mediaItems,
    //   isHiRes: true,
    //   rootIsolateToken: _rootIsolateToken,
    // );
    // await for (final entry in hiResStream) {
    //   _preparedThumbnails[entry.key] = entry.value;
    //   _emitState();
    // }
  }

  static Stream<MapEntry<int, Uint8List>> _makeThumbnails({
    required SplayTreeMap<int, Medium> mediaItems,
    required bool isHiRes,
    required RootIsolateToken rootIsolateToken,
  }) async* {
    List<Future<(int, Uint8List)>> futureThumbnails = [];
    for (final entry in mediaItems.entries) {
      final medium = entry.value;
      final index = entry.key;
      final futureThumbnail = workerManager.execute(
        () {
          BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
          return _generateThumbnail(medium, index: index, isHiRes: isHiRes);
        },
        priority: WorkPriority.immediately,
      ).future;
      futureThumbnails.add(futureThumbnail);
    }
    await for (final (index, thumbnail)
        in Stream.fromFutures(futureThumbnails)) {
      yield MapEntry(index, thumbnail);
    }
  }

  static Future<(int, Uint8List)> _generateThumbnail(
    Medium medium, {
    required int index,
    required bool isHiRes,
  }) async {
    // TODO: Figure out image size:
    const thumbnailSize = 276;
    final t = await medium.getThumbnail(
      height: thumbnailSize,
      highQuality: isHiRes,
    );
    return (index, Uint8List.fromList(t));
  }

  void _emitState() {
    final album = _album;
    if (album == null) {
      return;
    }
    final albumInfo = MediaPickerAlbumInfo(
      itemCount: album.count,
      thumbnails: Map.unmodifiable(_preparedThumbnails),
    );
    _thumbnailStreamController.add(albumInfo);
  }
}
