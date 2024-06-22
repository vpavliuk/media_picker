import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/media_picker_repository.dart';
import 'media_picker_event.dart';
import 'media_picker_state.dart';

final class MediaPickerBloc extends Bloc<MediaPickerEvent, MediaPickerState> {
  MediaPickerBloc({required MediaPickerRepository repository})
      : _repository = repository,
        super(const MediaPickerLoadingState()) {
    on<OnViewLoaded>(_onViewLoaded);
    on<MediaPickerVisibleItemsRangeDidChange>(_onVisibleItemsRangeChanged);
  }

  final MediaPickerRepository _repository;

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
    Emitter<MediaPickerState> emit,
  ) =>
      _repository.requestThumbnails(range: event.visibleRange);
}
