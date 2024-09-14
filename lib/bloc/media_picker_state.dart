import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class MediaPickerState extends Equatable {
  const MediaPickerState();

  @override
  List<Object?> get props => [];
}

final class MediaPickerLoadingState extends MediaPickerState {
  const MediaPickerLoadingState();
}

final class MediaPickerLoadedState extends MediaPickerState {
  const MediaPickerLoadedState({
    required this.count,
    required this.preparedThumbnails,
  });

  final int count;
  final Map<int, Uint8List> preparedThumbnails;

  @override
  List<Object?> get props => [count, preparedThumbnails];
}
