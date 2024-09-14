// import 'dart:async';
// import 'dart:collection';
// import 'dart:io';
// import 'dart:isolate';
//
// import 'package:collection/collection.dart';
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:photo_gallery/photo_gallery.dart';
//
// import '../bloc/media_picker_item_range.dart';
// import 'media_picker_repository.dart';
//
// final class MediaPickerRepositoryImpl implements MediaPickerRepository {
//   MediaPickerRepositoryImpl();
//
//   late final _thumbnailStreamController =
//       StreamController<MediaPickerAlbumInfo>(
//           onListen: () => _setUpIsolateIfNeeded());
//
//   final _isolateReceivePort = ReceivePort();
//   late final SendPort _isolateSendPort;
//   bool _isIsolateSetUp = false;
//
//   @override
//   Stream<MediaPickerAlbumInfo> get masterAlbumStream =>
//       _thumbnailStreamController.stream;
//
//   @override
//   Future<void> requestThumbnails({
//     required MediaPickerItemRange range,
//     required bool handleInReverse,
//   }) async {
//     await _setUpIsolateIfNeeded();
//     _isolateSendPort.send(_IsolateThumbnailRequest(range, handleInReverse));
//   }
//
//   Future<void> _setUpIsolateIfNeeded() async {
//     if (_isIsolateSetUp) {
//       return;
//     }
//     _isIsolateSetUp = true;
//
//     RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
//     final albums = await PhotoGallery.listAlbums();
//     final masterAlbum = albums.firstWhereOrNull((album) => album.isAllAlbum);
//     if (masterAlbum == null) {
//       return;
//     }
//
//     final initialAlbumInfo = MediaPickerAlbumInfo(
//       itemCount: masterAlbum.count,
//       thumbnails: const {},
//     );
//     _thumbnailStreamController.add(initialAlbumInfo);
//
//     _isolateReceivePort.listen((message) {
//       if (message is SendPort) {
//         _isolateSendPort = message;
//       } else if (message is Map<int, String>) {
//         final albumInfo = MediaPickerAlbumInfo(
//           itemCount: masterAlbum.count,
//           thumbnails: message,
//         );
//         _thumbnailStreamController.add(albumInfo);
//       }
//     });
//
//     await Isolate.spawn(
//       _isolateMain,
//       _IsolateInput(
//         album: masterAlbum,
//         rootIsolateToken: rootIsolateToken,
//         sendPort: _isolateReceivePort.sendPort,
//       ),
//     );
//   }
//
//   static void _isolateMain(_IsolateInput input) {
//     // Register the background isolate with the root isolate.
//     BackgroundIsolateBinaryMessenger.ensureInitialized(input.rootIsolateToken);
//
//     final Map<int, String> preparedThumbnails = {};
//     final Set<int> pendingMedia = {};
//
//     final receivePort = ReceivePort();
//     receivePort.listen((message) async {
//       if (message is! _IsolateThumbnailRequest) {
//         return;
//       }
//       await _handleThumbnailsRequest(
//         message,
//         album: input.album,
//         preparedThumbnails: preparedThumbnails,
//         pendingMedia: pendingMedia,
//         sendPort: input.sendPort,
//       );
//     });
//
//     input.sendPort.send(receivePort.sendPort);
//   }
//
//   static Future<void> _handleThumbnailsRequest(
//     _IsolateThumbnailRequest request, {
//     required Album album,
//     required Map<int, String> preparedThumbnails,
//     required Set<int> pendingMedia,
//     required SendPort sendPort,
//   }) async {
//     const maxRangeLength = 25;
//     final smallRanges = _breakDownItemRange(
//       request.range,
//       reverseOrder: request.handleInReverse,
//       preparedThumbnails: preparedThumbnails,
//       pendingMedia: Set.unmodifiable(pendingMedia),
//       maxLength: maxRangeLength,
//     );
//
//     pendingMedia.addAll(smallRanges.expand((r) => r.allIndices));
//
//     final comparator = request.handleInReverse
//         ? (int a, int b) => b.compareTo(a)
//         : (int a, int b) => a.compareTo(b);
//     // Using SplayTreeMap to support definitive order of thumbnails being generated
//     final mediaItems = SplayTreeMap<int, Medium>(comparator);
//     for (final range in smallRanges) {
//       final items = await _mediaItemsFromRange(range, album: album);
//       mediaItems.addAll(items);
//     }
//
//     await _handleMediaItems(
//       mediaItems,
//       album: album,
//       preparedThumbnails: preparedThumbnails,
//       pendingMedia: pendingMedia,
//       sendPort: sendPort,
//     );
//   }
//
//   static Iterable<MediaPickerItemRange> _breakDownItemRange(
//     MediaPickerItemRange itemRange, {
//     required bool reverseOrder,
//     required Map<int, String> preparedThumbnails,
//     required Set<int> pendingMedia,
//     required int maxLength,
//   }) {
//     final List<MediaPickerItemRange> subRanges = [];
//     int? currentSmallRangeStart;
//     for (final index in itemRange.allIndices) {
//       if (preparedThumbnails[index] != null || pendingMedia.contains(index)) {
//         if (currentSmallRangeStart != null) {
//           subRanges.add(
//             MediaPickerItemRange(
//               start: currentSmallRangeStart,
//               length: index - currentSmallRangeStart,
//             ),
//           );
//           currentSmallRangeStart = null;
//         }
//         continue;
//       }
//       if (currentSmallRangeStart == null) {
//         currentSmallRangeStart = index;
//       } else {
//         final currentLength = index - currentSmallRangeStart;
//         if (currentLength == maxLength) {
//           subRanges.add(
//             MediaPickerItemRange(
//               start: currentSmallRangeStart,
//               length: maxLength,
//             ),
//           );
//           currentSmallRangeStart = index;
//         }
//       }
//     }
//     if (currentSmallRangeStart != null) {
//       subRanges.add(
//         MediaPickerItemRange(
//           start: currentSmallRangeStart,
//           length: itemRange.end - currentSmallRangeStart + 1,
//         ),
//       );
//     }
//     return reverseOrder
//         ? List.unmodifiable(subRanges.reversed)
//         : List.unmodifiable(subRanges);
//   }
//
//   static Future<Map<int, Medium>> _mediaItemsFromRange(
//       MediaPickerItemRange itemRange,
//       {required Album album}) async {
//     final Map<int, Medium> mediaItems = {};
//     final mediaPage = await album.listMedia(
//       skip: itemRange.start,
//       take: itemRange.length,
//     );
//     for (final (index, medium) in mediaPage.items.indexed) {
//       mediaItems[itemRange.start + index] = medium;
//     }
//     return mediaItems;
//   }
//
//   static Future<void> _handleMediaItems(
//     SplayTreeMap<int, Medium> mediaItems, {
//     required Album album,
//     required Map<int, String> preparedThumbnails,
//     required Set<int> pendingMedia,
//     required SendPort sendPort,
//   }) async {
//     // Lo Res Thumbnails:
//     final loResStream = _makeThumbnails(mediaItems: mediaItems, isHiRes: false);
//     await for (final entry in loResStream) {
//       preparedThumbnails[entry.key] = entry.value;
//       pendingMedia.remove(entry.key);
//       _emitState(preparedThumbnails, port: sendPort);
//     }
//
//     // Hi Res Thumbnails:
//     final hiResStream = _makeThumbnails(mediaItems: mediaItems, isHiRes: true);
//     await for (final entry in hiResStream) {
//       preparedThumbnails[entry.key] = entry.value;
//       _emitState(preparedThumbnails, port: sendPort);
//     }
//   }
//
//   static Stream<MapEntry<int, String>> _makeThumbnails({
//     required SplayTreeMap<int, Medium> mediaItems,
//     required bool isHiRes,
//   }) async* {
//     for (final entry in mediaItems.entries) {
//       final medium = entry.value;
//       final index = entry.key;
//       final filePath =
//           await _generateThumbnail(medium, index: index, isHiRes: isHiRes);
//       yield MapEntry(index, filePath);
//     }
//   }
//
//   static Future<String> _generateThumbnail(
//     Medium medium, {
//     required int index,
//     required bool isHiRes,
//   }) async {
//     final tmpDirectory = await getTemporaryDirectory();
//     final hiResSuffix = isHiRes ? "_hiRes" : "";
//     final filePath =
//         '${tmpDirectory.path}${Platform.pathSeparator}thumb_$index$hiResSuffix.jpg';
//     final file = File(filePath);
//     // TODO: Figure out image size:
//     const thumbnailSize = 276;
//     final thumbnailData = await medium.getThumbnail(
//       height: thumbnailSize,
//       highQuality: isHiRes,
//     );
//     await file.writeAsBytes(thumbnailData);
//     return filePath;
//   }
//
//   static void _emitState(Map<int, String> state, {required SendPort port}) =>
//       port.send(Map<int, String>.unmodifiable(state));
// }
//
// final class _IsolateInput {
//   final Album album;
//   final RootIsolateToken rootIsolateToken;
//   final SendPort sendPort;
//
//   const _IsolateInput({
//     required this.album,
//     required this.rootIsolateToken,
//     required this.sendPort,
//   });
// }
//
// final class _IsolateThumbnailRequest {
//   final MediaPickerItemRange range;
//   final bool handleInReverse;
//
//   const _IsolateThumbnailRequest(this.range, this.handleInReverse);
// }
