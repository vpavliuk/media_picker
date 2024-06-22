import 'media_picker_item_range.dart';

class MediaPickerEvent {
  const MediaPickerEvent();
}

final class OnViewLoaded extends MediaPickerEvent {
  const OnViewLoaded();
}

final class MediaPickerVisibleItemsRangeDidChange extends MediaPickerEvent {
  final MediaPickerItemRange visibleRange;

  const MediaPickerVisibleItemsRangeDidChange(this.visibleRange);
}
