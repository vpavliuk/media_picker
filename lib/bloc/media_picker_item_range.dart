import 'package:equatable/equatable.dart';

final class MediaPickerItemRange extends Equatable {
  static const empty = MediaPickerItemRange(start: 0, length: 0);

  final int start;
  final int length;

  const MediaPickerItemRange({required this.start, required this.length});

  bool get isEmpty => length == 0;
  bool get isNotEmpty => !isEmpty;

  @override
  List<Object?> get props => [start, length];
}
