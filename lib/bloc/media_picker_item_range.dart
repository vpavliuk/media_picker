import 'dart:math';

import 'package:equatable/equatable.dart';

final class MediaPickerItemRange extends Equatable {
  static const empty = MediaPickerItemRange(start: 0, length: 0);

  final int start;
  final int length;

  const MediaPickerItemRange({required this.start, required this.length});

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  int get end => start + length - 1;

  MediaPickerItemRange extending(int increment, {bool backwards = false}) {
    if (backwards) {
      final adjustedIncrement = start >= increment ? increment : start;
      return MediaPickerItemRange(
        start: start - adjustedIncrement,
        length: length + adjustedIncrement,
      );
    } else {
      return MediaPickerItemRange(start: start, length: length + increment);
    }
  }

  List<int> get allIndices => List.generate(length, (i) => start + i);

  @override
  List<Object?> get props => [start, length];
}
