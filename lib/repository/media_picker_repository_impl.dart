import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_gallery/photo_gallery.dart';

import '../bloc/media_picker_item_range.dart';
import 'media_picker_repository.dart';

final class MediaPickerRepositoryImpl implements MediaPickerRepository {
  MediaPickerRepositoryImpl();

  StreamController<MediaPickerAlbumInfo>? _thumbnailStreamController;

  final _isolateReceivePort = ReceivePort();
  late SendPort _isolateSendPort;
  bool _isIsolateSetUp = false;

  @override
  Stream<MediaPickerAlbumInfo> get masterAlbumStream {
    StreamController<MediaPickerAlbumInfo>? controller =
        _thumbnailStreamController;
    if (controller == null) {
      controller = StreamController<MediaPickerAlbumInfo>(
        onListen: () async {
          await _setUpIsolateIfNeeded();
        },
      );
      _thumbnailStreamController = controller;
    }
    return controller.stream;
  }

  @override
  Future<void> requestThumbnails({required MediaPickerItemRange range}) async {
    await _setUpIsolateIfNeeded();
    _isolateSendPort.send(range);
  }

  Future<void> _setUpIsolateIfNeeded() async {
    if (_isIsolateSetUp) {
      return;
    }
    _isIsolateSetUp = true;

    RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
    final albums = await PhotoGallery.listAlbums();
    final masterAlbum = albums.firstWhereOrNull((album) => album.isAllAlbum);
    final controller = _thumbnailStreamController;
    if (controller == null || masterAlbum == null) {
      return;
    }

    final initialAlbumInfo = MediaPickerAlbumInfo(
      itemCount: masterAlbum.count,
      thumbnails: const {},
    );
    controller.add(initialAlbumInfo);

    _isolateReceivePort.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
      } else if (message is Map<int, String>) {
        final controller = _thumbnailStreamController;
        if (controller == null) {
          return;
        }
        final albumInfo = MediaPickerAlbumInfo(
          itemCount: masterAlbum.count,
          thumbnails: message,
        );
        controller.add(albumInfo);
      }
    });

    await Isolate.spawn(
      _isolateMain,
      _IsolateInput(
        album: masterAlbum,
        rootIsolateToken: rootIsolateToken,
        sendPort: _isolateReceivePort.sendPort,
      ),
    );
  }

  static void _isolateMain(_IsolateInput input) {
    // Register the background isolate with the root isolate.
    BackgroundIsolateBinaryMessenger.ensureInitialized(input.rootIsolateToken);

    final Map<int, String> preparedThumbnails = {};
    final List<int> pendingThumbnails = [];

    final receivePort = ReceivePort();
    receivePort.listen((message) async {
      if (message is! MediaPickerItemRange) {
        return;
      }
      final mediaPage = await input.album
          .listMedia(skip: message.start, take: message.length);
      for (final (index, medium) in mediaPage.items.indexed) {
        final absoluteIndex = mediaPage.start + index;
        if (preparedThumbnails[absoluteIndex] != null ||
            pendingThumbnails.contains(absoluteIndex)) {
          continue;
        }
        pendingThumbnails.add(absoluteIndex);
        final tmpDirectory = await getTemporaryDirectory();
        final filePath =
            '${tmpDirectory.path}${Platform.pathSeparator}thumb_$absoluteIndex.jpg';
        final file = File(filePath);
        final thumbnailData =
            await medium.getThumbnail(height: 180, highQuality: true);
        await file.writeAsBytes(thumbnailData);
        pendingThumbnails.remove(absoluteIndex);
        preparedThumbnails[mediaPage.start + index] = filePath;
        input.sendPort.send(preparedThumbnails);
      }
    });
    input.sendPort.send(receivePort.sendPort);
  }
}

final class _IsolateInput {
  final Album album;
  final RootIsolateToken rootIsolateToken;
  final SendPort sendPort;

  const _IsolateInput({
    required this.album,
    required this.rootIsolateToken,
    required this.sendPort,
  });
}
