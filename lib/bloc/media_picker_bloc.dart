import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_picker/bloc/media_picker_item_range.dart';
import 'package:stream_transform/stream_transform.dart';

import '../repository/media_picker_repository.dart';
import 'media_picker_event.dart';
import 'media_picker_state.dart';

const _scrollDebounceDuration = Duration(milliseconds: 200);

final class MediaPickerBloc extends Bloc<MediaPickerEvent, MediaPickerState> {
  MediaPickerBloc({required MediaPickerRepository repository})
      : _repository = repository,
        super(const MediaPickerLoadingState()) {
    on<OnViewLoaded>(_onViewLoaded);
    on<MediaPickerVisibleItemsRangeDidChange>(_onVisibleItemsRangeChanged,
        transformer: _debounce);
  }

  final MediaPickerRepository _repository;
  int _previousVisibleRangeStart = 0;

  Future<void> _onViewLoaded(
    MediaPickerEvent _,
    Emitter<MediaPickerState> emitter,
  ) =>
      emitter.forEach(
        _repository.masterAlbumStream,
        onData: (album) => MediaPickerLoadedState(
          count: album.itemCount,
          preparedThumbnails: album.thumbnails,
        ),
      );

  Future<void> _onVisibleItemsRangeChanged(
    MediaPickerVisibleItemsRangeDidChange event,
    Emitter<MediaPickerState> _,
  ) async {
    final MediaPickerItemRange onScreenRange = event.visibleRange;
    final isScrollingToTop = onScreenRange.start < _previousVisibleRangeStart;
    _previousVisibleRangeStart = onScreenRange.start;

    // Double the onscreen range
    final rangeToRequest = onScreenRange.extending(
      onScreenRange.length,
      backwards: isScrollingToTop,
    );
    await _repository.requestThumbnails(
      range: rangeToRequest,
      handleInReverse: isScrollingToTop,
    );
  }

  Stream<MediaPickerVisibleItemsRangeDidChange> _debounce(
          Stream<MediaPickerVisibleItemsRangeDidChange> events,
          EventMapper<MediaPickerVisibleItemsRangeDidChange> mapper) =>
      events.debounce(_scrollDebounceDuration).switchMap(mapper);
}
